// Regression: AAOB-4 / CSE-8 / TX-10. The search screens share the app-wide
// blocs; leaving a search screen must not leave the main list filtered, and
// transaction search must find transactions outside the visible month.
// Real ObjectBox, real repositories, real blocs and the real router.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/core/storage/storage_keys.dart';
import 'package:ikuyo_finance/features/asset/bloc/asset_bloc.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/asset/screens/asset_screen.dart';
import 'package:ikuyo_finance/features/budget/bloc/budget_bloc.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/budget/screens/budget_screen.dart';
import 'package:ikuyo_finance/features/category/bloc/category_bloc.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/category/screens/category_screen.dart';
import 'package:ikuyo_finance/features/transaction/bloc/transaction_bloc.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/features/transaction/screens/transaction_screen.dart';
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

  Future<void> start(WidgetTester tester, String location) async {
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    app.router.go(location);
    await tester.pumpAndSettle();
  }

  Future<void> searchThenLeave(
    WidgetTester tester,
    String searchLocation,
    String query,
  ) async {
    app.router.push(searchLocation);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, query);
    // * Lewati debounce 300 ms
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    app.router.pop();
    await tester.pumpAndSettle();
    // * Reset query memakai event pencarian yang sama (debounce 300 ms)
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  testWidgets('AAOB-4 leaving asset search restores the full asset list',
      (tester) async {
    app.storage.box<Asset>().putMany([
      Asset(name: 'Wallet', type: 0, balance: 1),
      Asset(name: 'Bank', type: 1, balance: 2),
    ]);
    await start(tester, '/asset');
    await searchThenLeave(tester, '/asset/search', 'Wal');

    final s = tester.element(find.byType(AssetScreen)).read<AssetBloc>().state;
    expect(s.currentSearchQuery, isNull);
    expect(s.assets.map((a) => a.name), containsAll(['Wallet', 'Bank']));
  });

  testWidgets('CSE-8 leaving category search restores the full category list',
      (tester) async {
    app.storage.box<Category>().putMany([
      Category(name: 'Food', type: CategoryType.expense.index),
      Category(name: 'Salary', type: CategoryType.income.index),
    ]);
    await start(tester, '/categories');
    await searchThenLeave(tester, '/categories/search', 'Foo');

    final s =
        tester.element(find.byType(CategoryScreen)).read<CategoryBloc>().state;
    expect(s.currentSearchQuery, isNull);
    expect(s.categories.map((c) => c.name), containsAll(['Food', 'Salary']));
  });

  testWidgets('AAOB-4 leaving budget search restores the full budget list',
      (tester) async {
    final food = Category(name: 'Food', type: CategoryType.expense.index);
    final fun = Category(name: 'Fun', type: CategoryType.expense.index);
    app.storage.box<Category>().putMany([food, fun]);
    app.storage.box<Budget>().putMany([
      Budget(amountLimit: 10)..category.target = food,
      Budget(amountLimit: 20)..category.target = fun,
    ]);
    await start(tester, '/budget');
    await searchThenLeave(tester, '/budget/search', 'Foo');

    final s = tester.element(find.byType(BudgetScreen)).read<BudgetBloc>().state;
    expect(s.currentSearchQuery, isNull);
    expect(s.budgets, hasLength(2));
  });

  testWidgets('TX-10 transaction search finds past months and leaving it '
      'restores the unfiltered month list', (tester) async {
    final now = DateTime.now();
    final asset = Asset(name: 'Cash', type: 0, balance: 0);
    app.storage.box<Asset>().put(asset);
    app.storage.box<Transaction>().putMany([
      Transaction(
        amount: 1,
        description: 'coffee now',
        transactionDate: DateTime(now.year, now.month, 1, 10),
        type: CategoryType.expense.index,
      )..asset.target = asset,
      Transaction(
        amount: 1,
        description: 'lunch now',
        transactionDate: DateTime(now.year, now.month, 1, 12),
        type: CategoryType.expense.index,
      )..asset.target = asset,
      Transaction(
        amount: 1,
        description: 'coffee old',
        transactionDate: DateTime(now.year - 1, now.month, 1, 10),
        type: CategoryType.expense.index,
      )..asset.target = asset,
    ]);
    await start(tester, '/');

    app.router.push('/transaction/search');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'coffee');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('coffee old'), findsOneWidget);

    app.router.pop();
    await tester.pumpAndSettle();
    // * Reset query memakai event pencarian yang sama (debounce 300 ms)
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    final s = tester
        .element(find.byType(TransactionScreen))
        .read<TransactionBloc>()
        .state;
    expect(s.currentSearchQuery, isNull);
    expect(
      s.transactions.map((t) => t.description),
      unorderedEquals(['coffee now', 'lunch now']),
    );
  });
}
