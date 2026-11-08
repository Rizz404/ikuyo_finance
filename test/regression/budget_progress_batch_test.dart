// Regression: F7 (budget list progress repeated a full period transaction
// scan, a Category getAll + ancestor walk and a currency read for EVERY
// budget). One list fetch must share that work: at most one transaction
// query per distinct period range, one category load and one currency read,
// while staying exact (minor units, descendants, cycles, owner rules) and
// recomputed from the store on every refresh (no stale cache).
// Real ObjectBox + real BudgetRepositoryImpl + real BudgetBloc; the storage
// wrapper only counts box accesses per entity type.
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/core/currency/models/currency_marker.dart';
import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/core/storage/query_extensions.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/budget/bloc/budget_bloc.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/budget/models/budget_progress.dart';
import 'package:ikuyo_finance/features/budget/repositories/budget_repository_impl.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:objectbox/objectbox.dart';

import '../support/objectbox_test_store.dart';
import '../support/test_logger.dart';

class _CountingStorage extends ObjectBoxStorage {
  _CountingStorage(super.store) : super.forTesting();

  final Map<Type, int> boxAccess = {};

  int of<T>() => boxAccess[T] ?? 0;

  @override
  Box<T> box<T>() {
    boxAccess[T] = (boxAccess[T] ?? 0) + 1;
    return super.box<T>();
  }
}

void main() {
  setUpAll(bootstrapTestLogger);

  late ObjectBoxTestStore store;
  late _CountingStorage counting;
  late BudgetRepositoryImpl repo;
  late Asset cash;
  late List<Category> roots;
  late List<Category> leaves;

  setUp(() async {
    store = await ObjectBoxTestStore.open();
    counting = _CountingStorage(store.storage.store);
    repo = BudgetRepositoryImpl(counting);
    cash = Asset(name: 'Cash', type: 0, balance: 0);
    store.storage.box<Asset>().put(cash);
    store.storage.box<CurrencyMarker>().put(CurrencyMarker(currency: 'usd'));

    // * 6 roots, each with 2 children, each child with 1 grandchild
    roots = [
      for (var i = 0; i < 6; i++)
        Category(name: 'R$i', type: CategoryType.expense.index),
    ];
    store.storage.box<Category>().putMany(roots);
    final children = <Category>[];
    for (final r in roots) {
      for (var j = 0; j < 2; j++) {
        children.add(
          Category(name: '${r.name}.$j', type: CategoryType.expense.index)
            ..parent.target = r,
        );
      }
    }
    store.storage.box<Category>().putMany(children);
    leaves = [
      for (final c in children)
        Category(name: '${c.name}.x', type: CategoryType.expense.index)
          ..parent.target = c,
    ];
    store.storage.box<Category>().putMany(leaves);
  });
  tearDown(() => store.close());

  final now = DateTime.now();
  DateTime inMonth(int i) => DateTime(now.year, now.month, 1 + i % 25, 10);

  void seedTransactions() {
    final all = [...roots, ...leaves];
    store.storage.box<Transaction>().putMany([
      for (var i = 0; i < 240; i++)
        Transaction(
            amount: 0.01 * (i % 7 + 1),
            type:
                (i % 5 == 0 ? CategoryType.income : CategoryType.expense).index,
            // * every 4th one is undated and falls back to createdAt (F6)
            transactionDate: i % 4 == 0 ? null : inMonth(i),
            createdAt: inMonth(i),
          )
          ..asset.target = cash
          ..category.target = all[i % all.length],
    ]);
  }

  List<Budget> seedBudgets() {
    final budgets = <Budget>[
      for (var i = 0; i < 18; i++)
        Budget(
          amountLimit: 1,
          period: [
            BudgetPeriod.monthly,
            BudgetPeriod.weekly,
            BudgetPeriod.yearly,
          ][i % 3].index,
          createdAt: DateTime(2025, 1, 1).add(Duration(minutes: i)),
        )..category.target = i % 9 == 8 ? null : [...roots, ...leaves][i % 18],
    ];
    store.storage.box<Budget>().putMany(budgets);
    return budgets;
  }

  Future<BudgetState> fetch(BudgetBloc bloc) async {
    bloc.add(const BudgetRefreshed());
    return bloc.stream
        .firstWhere((s) => s.status == BudgetStatus.success)
        .timeout(const Duration(seconds: 10));
  }

  /// Independent reference: brute-force sum straight from the box.
  int expectedMinor(Budget b) {
    final range = BudgetPeriodRange.of(b, now: now);
    final rootId = b.category.targetId;
    final cats = store.storage.box<Category>().getAll();
    bool under(int? id) {
      if (rootId == 0) return true;
      final seen = <int>{};
      var cur = id;
      while (cur != null && cur != 0 && seen.add(cur)) {
        if (cur == rootId) return true;
        cur = cats.firstWhere((c) => c.id == cur).parent.targetId;
      }
      return false;
    }

    var sum = 0;
    for (final t in store.storage.box<Transaction>().getAll()) {
      if (!t.isExpense) continue;
      if (!range.contains(t.transactionDate ?? t.createdAt)) continue;
      if (!under(t.category.targetId)) continue;
      sum += BudgetProgress.toMinor(t.amount, 2);
    }
    return sum;
  }

  test('one list fetch shares period, category and currency work', () async {
    seedTransactions();
    final budgets = seedBudgets();
    final bloc = BudgetBloc(repo);
    addTearDown(bloc.close);

    counting.boxAccess.clear();
    QueryStats.reset();
    final s = await fetch(bloc);

    expect(s.budgets, hasLength(18));
    expect(s.progress, hasLength(18));
    // * 3 distinct period ranges (monthly, weekly, yearly)
    expect(
      counting.of<Transaction>(),
      lessThanOrEqualTo(3),
      reason: 'transaction scans must be shared per period range',
    );
    expect(QueryStats.queriesOf<Transaction>(), lessThanOrEqualTo(3));
    expect(
      counting.of<Category>(),
      lessThanOrEqualTo(1),
      reason: 'category tree must be loaded once per fetch',
    );
    expect(counting.of<CurrencyMarker>(), lessThanOrEqualTo(1));
    expect(
      counting.of<Budget>(),
      lessThanOrEqualTo(1),
      reason: 'no per-budget re-lookup by ulid',
    );

    for (final b in budgets) {
      expect(
        s.progress[b.ulid]!.spentMinor,
        expectedMinor(b),
        reason: 'budget ${b.ulid} (${b.budgetPeriod})',
      );
      expect(s.progress[b.ulid]!.decimalDigits, 2);
    }
  });

  test(
    'refresh recomputes after transaction, category and currency changes',
    () async {
      seedTransactions();
      final budgets = seedBudgets();
      final bloc = BudgetBloc(repo);
      addTearDown(bloc.close);
      final monthlyR0 = budgets.first; // monthly, category R0
      expect(monthlyR0.category.targetId, roots[0].id);

      var s = await fetch(bloc);
      final before = s.progress[monthlyR0.ulid]!.spentMinor;
      expect(before, expectedMinor(monthlyR0));

      // * new expense in a grandchild of R0
      store.storage.box<Transaction>().put(
        Transaction(
            amount: 1.25,
            type: CategoryType.expense.index,
            transactionDate: inMonth(3),
          )
          ..asset.target = cash
          ..category.target = leaves[0],
      );
      s = await fetch(bloc);
      expect(s.progress[monthlyR0.ulid]!.spentMinor, before + 125);

      // * move R1's subtree under R0 -> R0 now also owns R1 spending
      roots[1].parent.target = roots[0];
      store.storage.box<Category>().put(roots[1]);
      s = await fetch(bloc);
      expect(s.progress[monthlyR0.ulid]!.spentMinor, expectedMinor(monthlyR0));
      expect(s.progress[monthlyR0.ulid]!.spentMinor, greaterThan(before + 125));

      // * a cycle (R0 <-> R1) neither loops nor double counts
      roots[0].parent.target = roots[1];
      store.storage.box<Category>().put(roots[0]);
      s = await fetch(bloc);
      expect(s.progress[monthlyR0.ulid]!.spentMinor, expectedMinor(monthlyR0));

      // * currency marker switch to a 0-digit currency changes minor units
      final marker = store.storage.box<CurrencyMarker>().getAll().single;
      store.storage.box<CurrencyMarker>().put(marker..currency = 'idr');
      s = await fetch(bloc);
      expect(s.progress[monthlyR0.ulid]!.decimalDigits, 0);
    },
  );
}
