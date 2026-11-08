// Regression: SHARED-1, AAOB-1, TX-1, A08, A16 — membuka layar edit lalu
// menyimpan tanpa mengubah nominal tidak boleh mengubah nilai tersimpan.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/core/storage/storage_keys.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/asset/models/create_asset_params.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/budget/models/create_budget_params.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/category/models/create_category_params.dart';
import 'package:ikuyo_finance/features/transaction/models/create_transaction_params.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/shared/widgets/app_text_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;

  Future<void> bootWith(String currency) async {
    // * Cache rate valid agar ExchangeRateService tidak memanggil jaringan
    SharedPreferences.setMockInitialValues({
      StorageKeys.currency: currency,
      'cached_exchange_rates': '{"usd":1.0,"idr":16800.0,"eur":0.85}',
      'exchange_rates_timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    // ! Bundle easy_localization di-cache per file; bersihkan per test
    rootBundle.clear();
    app = await TestApp.boot();
  }

  tearDown(() => app.close());

  Future<Asset> seedAsset(double balance) async =>
      (await app.assetRepository
              .createAsset(
                CreateAssetParams(
                  name: 'Wallet',
                  type: AssetType.cash,
                  balance: balance,
                ),
              )
              .run())
          .getOrElse((f) => throw Exception(f.message))
          .data!;

  Future<void> start(WidgetTester tester) async {
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
  }

  Future<void> saveChanges(WidgetTester tester) async {
    // * Teks tombol sama untuk transaksi, aset, dan budget (en-US)
    final button = find.text('Save Changes');
    await tester.ensureVisible(button.first);
    await tester.pumpAndSettle();
    await tester.tap(button.first);
    await tester.pumpAndSettle();
  }

  String fieldText(WidgetTester tester, String name) {
    final field = find.descendant(
      of: find.byWidgetPredicate((w) => w is AppTextField && w.name == name),
      matching: find.byType(TextField),
    );
    return tester.widget<TextField>(field).controller!.text;
  }

  Future<void> editTransactionRoundTrip(
    WidgetTester tester, {
    required String currency,
    required double amount,
    required String shown,
  }) async {
    await bootWith(currency);
    final asset = await seedAsset(1000);
    final trx =
        (await app.transactionRepository
                .createTransaction(
                  CreateTransactionParams(
                    assetUlid: asset.ulid,
                    type: CategoryType.expense,
                    amount: amount,
                  ),
                )
                .run())
            .getOrElse((f) => throw Exception(f.message))
            .data!;

    await start(tester);
    app.router.push('/transaction/edit', extra: trx);
    await tester.pumpAndSettle();

    expect(fieldText(tester, 'amount'), shown);
    await saveChanges(tester);

    final stored = app.storage.box<Transaction>().get(trx.id)!;
    expect(stored.amount, amount, reason: 'amount must survive edit+save');
    final storedAsset = app.storage.box<Asset>().get(asset.id)!;
    expect(storedAsset.balance, 1000 - amount, reason: 'balance unchanged');
  }

  testWidgets('USD 9.99 transaction edit+save keeps 9.99', (tester) async {
    await editTransactionRoundTrip(
      tester,
      currency: 'usd',
      amount: 9.99,
      shown: '9.99',
    );
  });

  testWidgets('USD 12.50 transaction edit+save keeps 12.50', (tester) async {
    await editTransactionRoundTrip(
      tester,
      currency: 'usd',
      amount: 12.5,
      shown: '12.50',
    );
  });

  testWidgets('EUR 12.50 transaction edit+save keeps 12.50', (tester) async {
    await editTransactionRoundTrip(
      tester,
      currency: 'eur',
      amount: 12.5,
      shown: '12,50',
    );
  });

  testWidgets('IDR 1,000,000 transaction edit+save keeps 1000000', (
    tester,
  ) async {
    await editTransactionRoundTrip(
      tester,
      currency: 'idr',
      amount: 1000000,
      shown: '1.000.000',
    );
  });

  testWidgets('USD asset balance 1234.56 survives edit+save (AAOB-1)', (
    tester,
  ) async {
    await bootWith('usd');
    final asset = await seedAsset(1234.56);
    await start(tester);
    app.router.push('/asset/edit', extra: asset);
    await tester.pumpAndSettle();
    expect(fieldText(tester, 'balance'), '1,234.56');
    await saveChanges(tester);
    expect(app.storage.box<Asset>().get(asset.id)!.balance, 1234.56);
  });

  testWidgets('IDR asset balance 2,500,000 survives edit+save (AAOB-2)', (
    tester,
  ) async {
    await bootWith('idr');
    final asset = await seedAsset(2500000);
    await start(tester);
    app.router.push('/asset/edit', extra: asset);
    await tester.pumpAndSettle();
    expect(fieldText(tester, 'balance'), '2.500.000');
    await saveChanges(tester);
    expect(app.storage.box<Asset>().get(asset.id)!.balance, 2500000);
  });

  testWidgets('USD budget limit 12.50 survives edit+save (A16)', (
    tester,
  ) async {
    await bootWith('usd');
    final category =
        (await app.categoryRepository
                .createCategory(
                  const CreateCategoryParams(
                    name: 'Food',
                    type: CategoryType.expense,
                  ),
                )
                .run())
            .getOrElse((f) => throw Exception(f.message))
            .data!;
    final budget =
        (await app.budgetRepository
                .createBudget(
                  CreateBudgetParams(
                    categoryUlid: category.ulid,
                    amountLimit: 12.5,
                    period: BudgetPeriod.monthly,
                  ),
                )
                .run())
            .getOrElse((f) => throw Exception(f.message))
            .data!;
    await start(tester);
    app.router.push('/budget/edit', extra: budget);
    await tester.pumpAndSettle();
    expect(fieldText(tester, 'amountLimit'), '12.50');
    await saveChanges(tester);
    expect(app.storage.box<Budget>().get(budget.id)!.amountLimit, 12.5);
  });
}
