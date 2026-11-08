// Regression: AUTO-4 / A12 (Edit Item). Inverts audit harness
// V2-AUTO4 which asserted that saving the Edit Item screen duplicated items.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/core/storage/storage_keys.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/asset/models/create_asset_params.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_schedule_frequency.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_group.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_item.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/create_auto_group_params.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/create_auto_item_params.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/update_auto_item_params.dart';
import 'package:ikuyo_finance/features/transaction/models/create_transaction_params.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/shared/widgets/app_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;

  setUp(() async {
    // * Cache rate valid agar ExchangeRateService tidak memanggil jaringan
    SharedPreferences.setMockInitialValues({
      StorageKeys.currency: 'idr',
      'cached_exchange_rates': '{"usd":1.0,"idr":16800.0,"eur":0.85}',
      'exchange_rates_timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    rootBundle.clear();
    app = await TestApp.boot();
  });
  tearDown(() => app.close());

  Future<Transaction> seedTx(Asset a, String desc) async =>
      (await app.transactionRepository
              .createTransaction(
                CreateTransactionParams(
                  assetUlid: a.ulid,
                  amount: 1000,
                  transactionDate: DateTime.now(),
                  description: desc,
                ),
              )
              .run())
          .getOrElse((f) => throw Exception(f.message))
          .data!;

  Future<(AutoTransactionGroup, AutoTransactionItem, Transaction, Transaction)>
  seed() async {
    final a = (await app.assetRepository
            .createAsset(
              const CreateAssetParams(
                name: 'Wallet',
                type: AssetType.cash,
                balance: 100000,
              ),
            )
            .run())
        .getOrElse((f) => throw Exception(f.message))
        .data!;
    final t1 = await seedTx(a, 'Lunch');
    final t2 = await seedTx(a, 'Dinner');
    final g = (await app.autoTransactionRepository
            .createGroup(
              CreateAutoGroupParams(
                name: 'G',
                frequency: AutoScheduleFrequency.daily,
                scheduleHour: 8,
                scheduleMinute: 0,
                startDate: DateTime.now(),
              ),
            )
            .run())
        .getOrElse((f) => throw Exception(f.message))
        .data!;
    final item = (await app.autoTransactionRepository
            .createItem(
              CreateAutoItemParams(
                groupUlid: g.ulid,
                transactionUlid: t1.ulid,
                sortOrder: 0,
              ),
            )
            .run())
        .getOrElse((f) => throw Exception(f.message))
        .data!;
    return (g, item, t1, t2);
  }

  testWidgets('AUTO-4 saving Edit Item without changes keeps one item', (
    tester,
  ) async {
    final (g, item, t1, _) = await seed();
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    app.router.push(
      '/auto-transaction/items/edit',
      extra: {'group': g, 'item': item},
    );
    await tester.pumpAndSettle();
    final save = find.widgetWithText(AppButton, 'Save');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    final items = app.storage.box<AutoTransactionItem>().getAll();
    expect(items, hasLength(1));
    expect(items.single.ulid, item.ulid);
    expect(items.single.transaction.target?.ulid, t1.ulid);
  });

  test('AUTO-4 updateItem can replace the template transaction', () async {
    final (_, item, _, t2) = await seed();
    final r = await app.autoTransactionRepository
        .updateItem(
          UpdateAutoItemParams(ulid: item.ulid, transactionUlid: t2.ulid),
        )
        .run();
    expect(r.isRight(), isTrue);
    final stored = app.storage.box<AutoTransactionItem>().getAll();
    expect(stored, hasLength(1));
    expect(stored.single.transaction.target?.ulid, t2.ulid);
  });
}
