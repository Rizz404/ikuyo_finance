// Regression: AAOB-5 (budgets never computed spending/progress).
// spent = expense-direction transactions in the budget's own period
// ([start, end) in local time), over the budget category and all of its
// descendants (cycle-safe); a budget without category counts every expense.
// Amounts are summed in integer minor units of the stored currency.
// Real ObjectBox + real BudgetRepositoryImpl + real BudgetBloc.
// DST: run additionally with TZ=America/New_York (see logs/green_AAOB5_ny.log).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/core/currency/models/currency_marker.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/storage/storage_keys.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/budget/bloc/budget_bloc.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/budget/models/budget_progress.dart';
import 'package:ikuyo_finance/features/budget/models/create_budget_params.dart';
import 'package:ikuyo_finance/features/budget/models/update_budget_params.dart';
import 'package:ikuyo_finance/features/budget/repositories/budget_repository_impl.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/objectbox_test_store.dart';
import '../support/test_app.dart';
import '../support/test_logger.dart';

void main() {
  setUpAll(bootstrapTestLogger);

  group('BudgetPeriodRange (local calendar, [start, end))', () {
    Budget of(BudgetPeriod p, {DateTime? start, DateTime? end}) =>
        Budget(amountLimit: 1, period: p.index, startDate: start, endDate: end);

    test('monthly covers the first instant and excludes the next month', () {
      final r = BudgetPeriodRange.of(
        of(BudgetPeriod.monthly),
        now: DateTime(2026, 1, 15, 13),
      );
      expect(r.start, DateTime(2026, 1, 1));
      expect(r.end, DateTime(2026, 2, 1));
      expect(r.contains(DateTime(2026, 1, 1)), isTrue);
      expect(r.contains(DateTime(2026, 1, 31, 23, 59, 59, 999)), isTrue);
      expect(r.contains(DateTime(2026, 2, 1)), isFalse);
      expect(r.contains(DateTime(2025, 12, 31, 23, 59, 59, 999)), isFalse);
    });

    test(
      'weekly starts Monday 00:00 and ends next Monday 00:00 across DST',
      () {
        // * 2026-03-08 is a DST change day in America/*; 2026-10-25 in Europe/*
        for (final ref in [
          DateTime(2026, 3, 8, 12),
          DateTime(2026, 10, 25, 12),
        ]) {
          final r = BudgetPeriodRange.of(of(BudgetPeriod.weekly), now: ref);
          expect(r.start.weekday, DateTime.monday);
          expect([r.start.hour, r.start.minute], [0, 0]);
          expect([r.end.hour, r.end.minute], [0, 0], reason: 'DST-safe end');
          expect(r.end.weekday, DateTime.monday);
          expect(r.end, DateTime(r.start.year, r.start.month, r.start.day + 7));
          expect(r.contains(ref), isTrue);
        }
        final r = BudgetPeriodRange.of(
          of(BudgetPeriod.weekly),
          now: DateTime(2026, 3, 8, 12),
        );
        expect(r.start, DateTime(2026, 3, 2));
        expect(r.end, DateTime(2026, 3, 9));
      },
    );

    test('yearly is [Jan 1, next Jan 1)', () {
      final r = BudgetPeriodRange.of(
        of(BudgetPeriod.yearly),
        now: DateTime(2026, 7, 4),
      );
      expect(r.start, DateTime(2026, 1, 1));
      expect(r.end, DateTime(2027, 1, 1));
      expect(r.contains(DateTime(2026, 12, 31, 23, 59, 59, 999)), isTrue);
      expect(r.contains(DateTime(2027, 1, 1)), isFalse);
    });

    test('custom covers whole start..end calendar days, end exclusive at the '
        'next midnight', () {
      final r = BudgetPeriodRange.of(
        of(
          BudgetPeriod.custom,
          start: DateTime(2026, 1, 10, 9),
          end: DateTime(2026, 1, 20, 9),
        ),
        now: DateTime(2026, 5, 1),
      );
      expect(r.start, DateTime(2026, 1, 10));
      expect(r.end, DateTime(2026, 1, 21));
    });

    test('custom without dates falls back to the current calendar month', () {
      final r = BudgetPeriodRange.of(
        of(BudgetPeriod.custom),
        now: DateTime(2026, 4, 18),
      );
      expect(r.start, DateTime(2026, 4, 1));
      expect(r.end, DateTime(2026, 5, 1));
    });
  });

  group('BudgetRepository.getBudgetProgress', () {
    late ObjectBoxTestStore store;
    late BudgetRepositoryImpl repo;
    late Asset cash;
    late Category food;
    late Category groceries;
    late Category fruit;
    late Category transport;
    late Category salary;
    final now = DateTime(2026, 1, 15, 12);

    setUp(() async {
      store = await ObjectBoxTestStore.open();
      repo = BudgetRepositoryImpl(store.storage);
      cash = Asset(name: 'Cash', type: 0, balance: 0);
      store.storage.box<Asset>().put(cash);
      food = Category(name: 'Food', type: CategoryType.expense.index);
      groceries = Category(name: 'Groceries', type: CategoryType.expense.index);
      fruit = Category(name: 'Fruit', type: CategoryType.expense.index);
      transport = Category(name: 'Transport', type: CategoryType.expense.index);
      salary = Category(name: 'Salary', type: CategoryType.income.index);
      store.storage.box<Category>().putMany([food, transport, salary]);
      groceries.parent.target = food;
      store.storage.box<Category>().put(groceries);
      fruit.parent.target = groceries;
      store.storage.box<Category>().put(fruit);
    });
    tearDown(() => store.close());

    void tx(
      double amount,
      DateTime date, {
      Category? category,
      CategoryType type = CategoryType.expense,
    }) {
      final t = Transaction(
        amount: amount,
        transactionDate: date,
        type: type.index,
      )..asset.target = cash;
      if (category != null) t.category.target = category;
      store.storage.box<Transaction>().put(t);
    }

    Budget budget(
      double limit, {
      Category? category,
      BudgetPeriod period = BudgetPeriod.monthly,
      DateTime? start,
      DateTime? end,
    }) {
      final b = Budget(
        amountLimit: limit,
        period: period.index,
        startDate: start,
        endDate: end,
      );
      if (category != null) b.category.target = category;
      store.storage.box<Budget>().put(b);
      return b;
    }

    Future<BudgetProgress> progressOf(Budget b) async =>
        (await repo.getBudgetProgress(ulid: b.ulid, now: now).run())
            .getOrElse((f) => throw Exception(f.message))
            .data!;

    test(
      'includes the category and all descendant sub-categories only',
      () async {
        tx(10, DateTime(2026, 1, 2), category: food);
        tx(20, DateTime(2026, 1, 3), category: groceries);
        tx(30, DateTime(2026, 1, 4), category: fruit);
        tx(40, DateTime(2026, 1, 5), category: transport);
        tx(50, DateTime(2026, 1, 6));

        expect((await progressOf(budget(1000, category: food))).spent, 60);
        expect((await progressOf(budget(1000, category: groceries))).spent, 50);
        expect((await progressOf(budget(1000, category: fruit))).spent, 30);
        expect((await progressOf(budget(1000, category: transport))).spent, 40);
      },
    );

    test(
      'a category cycle does not loop and counts each category once',
      () async {
        final a = Category(name: 'A', type: CategoryType.expense.index);
        final b = Category(name: 'B', type: CategoryType.expense.index);
        store.storage.box<Category>().putMany([a, b]);
        a.parent.target = b;
        b.parent.target = a;
        store.storage.box<Category>().putMany([a, b]);
        tx(5, DateTime(2026, 1, 2), category: a);
        tx(7, DateTime(2026, 1, 2), category: b);

        final p = await progressOf(budget(100, category: a));
        expect(p.spent, 12);
      },
    );

    test(
      'excludes income-direction transactions, even inside the category',
      () async {
        tx(25, DateTime(2026, 1, 2), category: food);
        tx(
          999,
          DateTime(2026, 1, 2),
          category: food,
          type: CategoryType.income,
        );
        tx(
          500,
          DateTime(2026, 1, 2),
          category: salary,
          type: CategoryType.income,
        );

        expect((await progressOf(budget(100, category: food))).spent, 25);
        expect((await progressOf(budget(100))).spent, 25);
      },
    );

    test(
      'a budget without category counts every expense, uncategorized too',
      () async {
        tx(10, DateTime(2026, 1, 2), category: food);
        tx(20, DateTime(2026, 1, 2), category: transport);
        tx(30, DateTime(2026, 1, 2));
        tx(
          70,
          DateTime(2026, 1, 2),
          category: salary,
          type: CategoryType.income,
        );

        expect((await progressOf(budget(100))).spent, 60);
      },
    );

    test(
      'monthly boundaries: first and last instant in, neighbours out',
      () async {
        tx(1, DateTime(2026, 1, 1), category: food);
        tx(2, DateTime(2026, 1, 31, 23, 59, 59, 999), category: food);
        tx(100, DateTime(2025, 12, 31, 23, 59, 59, 999), category: food);
        tx(100, DateTime(2026, 2, 1), category: food);

        final p = await progressOf(budget(10, category: food));
        expect(p.spent, 3);
        expect(p.period.start, DateTime(2026, 1, 1));
        expect(p.period.end, DateTime(2026, 2, 1));
      },
    );

    test('custom range counts its whole last day and nothing after', () async {
      tx(1, DateTime(2026, 1, 10), category: food);
      tx(2, DateTime(2026, 1, 20, 23, 59, 59, 999), category: food);
      tx(100, DateTime(2026, 1, 9, 23, 59, 59, 999), category: food);
      tx(100, DateTime(2026, 1, 21), category: food);

      final p = await progressOf(
        budget(
          10,
          category: food,
          period: BudgetPeriod.custom,
          start: DateTime(2026, 1, 10),
          end: DateTime(2026, 1, 20),
        ),
      );
      expect(p.spent, 3);
    });

    // * F6: transactionDate is optional; the effective budget date is
    // * transactionDate ?? createdAt, so undated expenses are never dropped
    void undated(
      double amount,
      DateTime createdAt, {
      Category? category,
      CategoryType type = CategoryType.expense,
    }) {
      final t = Transaction(
        amount: amount,
        type: type.index,
        createdAt: createdAt,
        updatedAt: createdAt,
      )..asset.target = cash;
      if (category != null) t.category.target = category;
      store.storage.box<Transaction>().put(t);
      expect(
        store.storage.box<Transaction>().get(t.id)!.transactionDate,
        isNull,
      );
    }

    test(
      'F6 an undated expense counts by createdAt inside the period',
      () async {
        undated(40, DateTime(2026, 1, 9, 8), category: fruit);
        undated(5, DateTime(2026, 1, 9, 8));

        expect((await progressOf(budget(100, category: food))).spent, 40);
        expect((await progressOf(budget(100))).spent, 45);
      },
    );

    test('F6 an explicit transactionDate wins over createdAt', () async {
      // * created inside the period but dated outside -> excluded
      final out =
          Transaction(
              amount: 70,
              type: CategoryType.expense.index,
              transactionDate: DateTime(2025, 12, 31),
              createdAt: DateTime(2026, 1, 10),
            )
            ..asset.target = cash
            ..category.target = food;
      // * created outside but dated inside -> included
      final inside =
          Transaction(
              amount: 3,
              type: CategoryType.expense.index,
              transactionDate: DateTime(2026, 1, 10),
              createdAt: DateTime(2025, 11, 1),
            )
            ..asset.target = cash
            ..category.target = food;
      store.storage.box<Transaction>().putMany([out, inside]);

      expect((await progressOf(budget(100, category: food))).spent, 3);
    });

    test('F6 undated fallback keeps the half-open local period', () async {
      undated(1, DateTime(2026, 1, 1), category: food);
      undated(2, DateTime(2026, 1, 31, 23, 59, 59, 999), category: food);
      undated(100, DateTime(2025, 12, 31, 23, 59, 59, 999), category: food);
      undated(100, DateTime(2026, 2, 1), category: food);

      expect((await progressOf(budget(10, category: food))).spent, 3);
    });

    test(
      'F6 undated income is still excluded; undated descendants count',
      () async {
        undated(
          500,
          DateTime(2026, 1, 3),
          category: salary,
          type: CategoryType.income,
        );
        undated(
          999,
          DateTime(2026, 1, 3),
          category: food,
          type: CategoryType.income,
        );
        undated(12, DateTime(2026, 1, 3), category: groceries);

        expect((await progressOf(budget(100, category: food))).spent, 12);
        expect((await progressOf(budget(100))).spent, 12);
      },
    );

    test('F6 undated zero and overspend semantics', () async {
      final empty = await progressOf(budget(100, category: transport));
      expect(empty.spent, 0);
      expect(empty.isOverspent, isFalse);

      undated(60, DateTime(2026, 1, 4), category: transport);
      tx(60, DateTime(2026, 1, 5), category: transport);
      final over = await progressOf(budget(100, category: transport));
      expect(over.spent, 120);
      expect(over.isOverspent, isTrue);
      expect(over.remaining, -20);
    });

    test('overspend is reported unclamped with a negative remaining', () async {
      tx(150, DateTime(2026, 1, 2), category: food);

      final p = await progressOf(budget(100, category: food));
      expect(p.spent, 150);
      expect(p.limit, 100);
      expect(p.ratio, 1.5);
      expect(p.isOverspent, isTrue);
      expect(p.remaining, -50);
      expect(p.barValue, 1.0);
    });

    test('an empty period reports zero spent and the full remaining', () async {
      tx(80, DateTime(2025, 12, 20), category: food);

      final p = await progressOf(budget(100, category: food));
      expect(p.spent, 0);
      expect(p.ratio, 0);
      expect(p.remaining, 100);
      expect(p.isOverspent, isFalse);
      expect(p.barValue, 0);
    });

    test('sums in integer minor units: 3 x 0.10 against a 0.30 limit is '
        'exactly 100%, not overspent', () async {
      store.storage.box<CurrencyMarker>().put(CurrencyMarker(currency: 'usd'));
      for (var i = 0; i < 3; i++) {
        tx(0.1, DateTime(2026, 1, 2 + i), category: food);
      }

      final p = await progressOf(budget(0.3, category: food));
      expect(p.decimalDigits, 2);
      expect(p.spentMinor, 30);
      expect(p.limitMinor, 30);
      expect(p.ratio, 1.0);
      expect(p.isOverspent, isFalse);
      expect(p.remaining, 0);
    });

    test('a stored non-positive limit never divides by zero', () async {
      tx(5, DateTime(2026, 1, 2), category: food);

      final p = await progressOf(budget(0, category: food));
      expect(p.ratio, isNull);
      expect(p.barValue, 1.0);
      expect(p.isOverspent, isTrue);
    });

    test(
      'createBudget and updateBudget reject a zero or negative limit',
      () async {
        for (final limit in [0.0, -5.0, double.nan]) {
          final r = await repo
              .createBudget(
                CreateBudgetParams(categoryUlid: food.ulid, amountLimit: limit),
              )
              .run();
          expect(r.isLeft(), isTrue, reason: 'limit $limit');
        }
        expect(store.storage.box<Budget>().count(), 0);

        final ok =
            (await repo
                    .createBudget(
                      CreateBudgetParams(
                        categoryUlid: food.ulid,
                        amountLimit: 50,
                      ),
                    )
                    .run())
                .getOrElse((f) => throw Exception(f.message))
                .data!;
        final upd = await repo
            .updateBudget(UpdateBudgetParams(ulid: ok.ulid, amountLimit: 0))
            .run();
        expect(upd.isLeft(), isTrue);
        expect(store.storage.box<Budget>().get(ok.id)!.amountLimit, 50);
      },
    );

    test('BudgetBloc exposes progress for every fetched budget', () async {
      tx(30, DateTime.now(), category: food);
      final b = budget(120, category: food);
      final bloc = BudgetBloc(repo);
      addTearDown(bloc.close);
      bloc.add(const BudgetFetched());
      final s = await bloc.stream
          .firstWhere((s) => s.status == BudgetStatus.success)
          .timeout(const Duration(seconds: 10));
      expect(s.progress[b.ulid]?.spent, 30);
      expect(s.progress[b.ulid]?.ratio, 0.25);
    });
  });

  testWidgets('the budget card shows spent, limit and overspent state', (
    tester,
  ) async {
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
    final cash = Asset(name: 'Cash', type: 0, balance: 0);
    app.storage.box<Asset>().put(cash);
    final food = Category(name: 'Food', type: CategoryType.expense.index);
    app.storage.box<Category>().put(food);
    app.storage.box<Transaction>().put(
      Transaction(
          amount: 150,
          transactionDate: DateTime.now(),
          type: CategoryType.expense.index,
        )
        ..asset.target = cash
        ..category.target = food,
    );
    app.storage.box<Budget>().put(
      Budget(amountLimit: 100)..category.target = food,
    );

    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    app.router.go('/budget');
    await tester.pumpAndSettle();

    expect(find.textContaining('150%'), findsOneWidget);
    final overspent = LocaleKeys.budgetCardOverspent
        .tr(namedArgs: {'amount': 'X'})
        .split('X')
        .first
        .trim();
    expect(overspent, isNotEmpty);
    expect(find.textContaining(overspent), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
