// Synthetic benchmark for F7: many budgets x many transactions on real
// ObjectBox. Compares N single-budget calls (the pre-F7 per-budget shape:
// own currency read, own category load, own period scan) with one batch
// call. Prints measured wall time and query/row counts; asserts only exact
// result equality and shared-work counts, never a timing target.
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/core/currency/models/currency_marker.dart';
import 'package:ikuyo_finance/core/storage/query_extensions.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/budget/models/budget_progress.dart';
import 'package:ikuyo_finance/features/budget/repositories/budget_repository_impl.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';

import '../support/objectbox_test_store.dart';
import '../support/test_logger.dart';

const _budgets = 120;
const _transactions = 12000;
const _categories = 60;

void main() {
  setUpAll(bootstrapTestLogger);

  test('F7 benchmark: per-budget vs batch progress', () async {
    final store = await ObjectBoxTestStore.open();
    addTearDown(store.close);
    final repo = BudgetRepositoryImpl(store.storage);
    final now = DateTime(2026, 6, 15, 12);

    store.storage.box<CurrencyMarker>().put(CurrencyMarker(currency: 'usd'));
    final cash = Asset(name: 'Cash', type: 0, balance: 0);
    store.storage.box<Asset>().put(cash);
    final cats = [
      for (var i = 0; i < _categories; i++)
        Category(name: 'C$i', type: CategoryType.expense.index),
    ];
    store.storage.box<Category>().putMany(cats);
    for (var i = 1; i < _categories; i++) {
      cats[i].parent.target = cats[(i - 1) ~/ 3];
    }
    store.storage.box<Category>().putMany(cats);

    store.storage.box<Transaction>().putMany([
      for (var i = 0; i < _transactions; i++)
        Transaction(
            amount: (i % 997 + 1) / 100,
            type:
                (i % 6 == 0 ? CategoryType.income : CategoryType.expense).index,
            transactionDate: i % 5 == 0
                ? null
                : DateTime(2026, 1 + i % 12, 1 + i % 28, i % 24),
            createdAt: DateTime(2026, 1 + i % 12, 1 + (i * 7) % 28),
          )
          ..asset.target = cash
          ..category.target = cats[i % _categories],
    ]);
    final budgets = [
      for (var i = 0; i < _budgets; i++)
        Budget(amountLimit: 100, period: BudgetPeriod.values[i % 3].index)
          ..category.target = i % 10 == 0 ? null : cats[i % _categories],
    ];
    store.storage.box<Budget>().putMany(budgets);

    // * warm-up both paths once
    await repo.getBudgetsProgress(budgets: budgets, now: now).run();
    await repo.getBudgetProgress(ulid: budgets.first.ulid, now: now).run();

    QueryStats.reset();
    final perBudgetWatch = Stopwatch()..start();
    final perBudget = <String, BudgetProgress>{};
    for (final b in budgets) {
      final r = await repo.getBudgetProgress(ulid: b.ulid, now: now).run();
      perBudget[b.ulid] = r.getOrElse((f) => throw f).data!;
    }
    perBudgetWatch.stop();
    final perBudgetQueries = QueryStats.queriesOf<Transaction>();
    final perBudgetRows = QueryStats.rowsOf<Transaction>();

    QueryStats.reset();
    final batchWatch = Stopwatch()..start();
    final batch =
        (await repo.getBudgetsProgress(budgets: budgets, now: now).run())
            .getOrElse((f) => throw f)
            .data!;
    batchWatch.stop();
    final batchQueries = QueryStats.queriesOf<Transaction>();
    final batchRows = QueryStats.rowsOf<Transaction>();

    // ignore: avoid_print
    print(
      'F7_BENCH budgets=$_budgets transactions=$_transactions '
      'categories=$_categories '
      'per_budget_ms=${perBudgetWatch.elapsedMilliseconds} '
      'per_budget_tx_queries=$perBudgetQueries '
      'per_budget_tx_rows=$perBudgetRows '
      'batch_ms=${batchWatch.elapsedMilliseconds} '
      'batch_tx_queries=$batchQueries batch_tx_rows=$batchRows',
    );

    expect(batch, perBudget);
    expect(perBudgetQueries, _budgets);
    expect(batchQueries, 3);
    expect(batchRows, lessThan(perBudgetRows));
  });
}
