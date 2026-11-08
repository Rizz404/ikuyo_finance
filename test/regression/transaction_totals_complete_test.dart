// Regression: TX-7 / TX-8 (totals computed from a partial page). Real
// ObjectBox + real repository + real TransactionBloc.
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/core/storage/storage_keys.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/transaction/bloc/transaction_bloc.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/features/transaction/repositories/transaction_repository_impl.dart';
import 'package:ikuyo_finance/features/transaction/widgets/calendar_transaction_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/objectbox_test_store.dart';
import '../support/test_app.dart';
import '../support/test_logger.dart';

void main() {
  setUpAll(bootstrapTestLogger);

  late ObjectBoxTestStore store;
  setUp(() async => store = await ObjectBoxTestStore.open());
  tearDown(() => store.close());

  void seed(int count, DateTime Function(int i) dateOf) {
    final asset = Asset(name: 'Cash', type: 0, balance: 0);
    store.storage.box<Asset>().put(asset);
    final cat = Category(name: 'Food', type: CategoryType.expense.index);
    store.storage.box<Category>().put(cat);
    store.storage.box<Transaction>().putMany([
      for (var i = 0; i < count; i++)
        Transaction(
          amount: 1,
          transactionDate: dateOf(i),
          type: CategoryType.expense.index,
        )
          ..asset.target = asset
          ..category.target = cat,
    ]);
  }

  Future<TransactionState> settle(TransactionBloc bloc) => bloc.stream
      .firstWhere((s) => s.status == TransactionStatus.success)
      .timeout(const Duration(seconds: 10));

  test('TX-8 the year view loads every transaction of the year (> 500)',
      () async {
    seed(620, (i) => DateTime(2025, 1 + i % 12, 1 + i % 28, 10));
    final bloc = TransactionBloc(TransactionRepositoryImpl(store.storage));
    addTearDown(bloc.close);
    bloc.add(const TransactionYearChanged(year: 2025));
    final s = await settle(bloc);
    expect(s.transactions, hasLength(620));
  });

  testWidgets('TX-7 opening the Calendar tab loads the full month so day '
      'totals are complete', (tester) async {
    final app = await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.currency: 'idr',
        'cached_exchange_rates': '{"usd":1.0,"idr":16800.0,"eur":0.85}',
        'exchange_rates_timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      rootBundle.clear();
      return TestApp.boot();
    });
    addTearDown(app!.close);
    final now = DateTime.now();
    final asset = Asset(name: 'Cash', type: 0, balance: 0);
    app.storage.box<Asset>().put(asset);
    app.storage.box<Transaction>().putMany([
      for (var i = 0; i < 45; i++)
        Transaction(
          amount: 1,
          transactionDate: DateTime(now.year, now.month, 1 + i % 28, 10),
          type: CategoryType.expense.index,
        )..asset.target = asset,
    ]);

    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    final ctx = tester.element(find.byType(CalendarTransactionView));
    final s = ctx.read<TransactionBloc>().state;
    expect(s.hasReachedMax, isTrue);
    expect(s.transactions, hasLength(45));
  });
}
