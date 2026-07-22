import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/budget/models/create_budget_params.dart';
import 'package:ikuyo_finance/features/budget/models/get_budgets_params.dart';
import 'package:ikuyo_finance/features/budget/models/update_budget_params.dart';
import 'package:ikuyo_finance/features/budget/repositories/budget_repository_impl.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';

import '../../../support/objectbox_test_store.dart';
import '../../../support/test_logger.dart';

void main() {
  late ObjectBoxTestStore testStore;
  late BudgetRepositoryImpl repository;

  setUpAll(bootstrapTestLogger);

  setUp(() async {
    testStore = await ObjectBoxTestStore.open();
    repository = BudgetRepositoryImpl(testStore.storage);
  });

  tearDown(() => testStore.close());

  // * Budgets belong to a Category, which BudgetRepositoryImpl looks up
  // * directly via ObjectBoxStorage (no repository dependency) - so tests
  // * seed categories straight into the box.
  Category createCategory({String name = 'Food', CategoryType type = CategoryType.expense}) {
    final category = Category(name: name, type: type.index);
    testStore.storage.box<Category>().put(category);
    return category;
  }

  group('createBudget', () {
    test('persists a budget and assigns a ulid', () async {
      final category = createCategory();

      final result = await repository
          .createBudget(
            CreateBudgetParams(
              categoryUlid: category.ulid,
              amountLimit: 1000000,
            ),
          )
          .run();

      expect(result.isRight(), isTrue);
      final budget = result.getOrElse((_) => throw Exception()).data!;
      expect(budget.ulid, isNotEmpty);
      expect(budget.amountLimit, 1000000);
      expect(budget.budgetPeriod, BudgetPeriod.monthly);
      expect(budget.category.target?.ulid, category.ulid);
    });

    test('persists the given period, startDate and endDate', () async {
      final category = createCategory();
      final start = DateTime(2026, 1, 1);
      final end = DateTime(2026, 1, 31);

      final result = await repository
          .createBudget(
            CreateBudgetParams(
              categoryUlid: category.ulid,
              amountLimit: 500,
              period: BudgetPeriod.custom,
              startDate: start,
              endDate: end,
            ),
          )
          .run();

      final budget = result.getOrElse((_) => throw Exception()).data!;
      expect(budget.budgetPeriod, BudgetPeriod.custom);
      expect(budget.startDate, start);
      expect(budget.endDate, end);
    });

    test('fails when the category does not exist', () async {
      final result = await repository
          .createBudget(
            const CreateBudgetParams(
              categoryUlid: 'unknown-ulid',
              amountLimit: 1000,
            ),
          )
          .run();

      expect(result.isLeft(), isTrue);
    });
  });

  group('getBudgets', () {
    late Category food;
    late Category transport;

    setUp(() async {
      food = createCategory(name: 'Food');
      transport = createCategory(name: 'Transport');

      await repository
          .createBudget(
            CreateBudgetParams(
              categoryUlid: food.ulid,
              amountLimit: 500,
              period: BudgetPeriod.monthly,
              startDate: DateTime(2026, 1, 1),
              endDate: DateTime(2026, 1, 31),
            ),
          )
          .run();
      await repository
          .createBudget(
            CreateBudgetParams(
              categoryUlid: transport.ulid,
              amountLimit: 900,
              period: BudgetPeriod.weekly,
              startDate: DateTime(2026, 2, 1),
              endDate: DateTime(2026, 2, 7),
            ),
          )
          .run();
      await repository
          .createBudget(
            CreateBudgetParams(
              categoryUlid: food.ulid,
              amountLimit: 1500,
              period: BudgetPeriod.yearly,
            ),
          )
          .run();
    });

    test('returns all budgets with no filters', () async {
      final result = await repository.getBudgets(const GetBudgetsParams()).run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data, hasLength(3));
    });

    test('filters by period', () async {
      final result = await repository
          .getBudgets(const GetBudgetsParams(period: BudgetPeriod.weekly))
          .run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data, hasLength(1));
      expect(success.data!.single.amountLimit, 900);
    });

    test('filters by categoryUlid', () async {
      final result = await repository
          .getBudgets(GetBudgetsParams(categoryUlid: food.ulid))
          .run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data, hasLength(2));
      expect(success.data!.every((b) => b.category.target?.ulid == food.ulid), isTrue);
    });

    test('searches case-insensitively by category name', () async {
      final result = await repository
          .getBudgets(const GetBudgetsParams(searchQuery: 'foo'))
          .run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data, hasLength(2));
      expect(success.data!.every((b) => b.category.target?.name == 'Food'), isTrue);
    });

    test('filters by amount limit range', () async {
      final result = await repository
          .getBudgets(const GetBudgetsParams(minAmountLimit: 600, maxAmountLimit: 1000))
          .run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data, hasLength(1));
      expect(success.data!.single.amountLimit, 900);
    });

    test('filters by startDate range', () async {
      final result = await repository
          .getBudgets(
            GetBudgetsParams(
              startDateFrom: DateTime(2026, 1, 15),
              startDateTo: DateTime(2026, 2, 15),
            ),
          )
          .run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data, hasLength(1));
      expect(success.data!.single.amountLimit, 900);
    });

    test('filters by endDate range', () async {
      final result = await repository
          .getBudgets(
            GetBudgetsParams(
              endDateFrom: DateTime(2026, 1, 1),
              endDateTo: DateTime(2026, 1, 31),
            ),
          )
          .run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data, hasLength(1));
      expect(success.data!.single.amountLimit, 500);
    });

    test('sorts by amountLimit ascending', () async {
      final result = await repository
          .getBudgets(
            const GetBudgetsParams(
              sortBy: BudgetSortBy.amountLimit,
              sortOrder: BudgetSortOrder.ascending,
            ),
          )
          .run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data!.map((b) => b.amountLimit), [500, 900, 1500]);
    });

    test('paginates using cursor and reports hasNextPage', () async {
      final firstPage = (await repository
              .getBudgets(const GetBudgetsParams(limit: 2))
              .run())
          .getOrElse((_) => throw Exception());

      expect(firstPage.data, hasLength(2));
      expect(firstPage.cursor.hasNextPage, isTrue);

      final secondPage = (await repository
              .getBudgets(GetBudgetsParams(limit: 2, cursor: firstPage.cursor.nextCursor))
              .run())
          .getOrElse((_) => throw Exception());

      expect(secondPage.data, hasLength(1));
      expect(secondPage.cursor.hasNextPage, isFalse);
    });

    test('returns empty result set when no budget matches', () async {
      final result = await repository
          .getBudgets(const GetBudgetsParams(searchQuery: 'nonexistent'))
          .run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data, isEmpty);
      expect(success.cursor.hasNextPage, isFalse);
    });
  });

  group('getBudgetById', () {
    test('returns the matching budget', () async {
      final category = createCategory();
      final created = (await repository
              .createBudget(
                CreateBudgetParams(categoryUlid: category.ulid, amountLimit: 1000),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;

      final result = await repository.getBudgetById(ulid: created.ulid).run();

      expect(result.isRight(), isTrue);
      expect(result.getOrElse((_) => throw Exception()).data!.amountLimit, 1000);
    });

    test('fails for an unknown ulid', () async {
      final result = await repository.getBudgetById(ulid: 'unknown').run();

      expect(result.isLeft(), isTrue);
    });
  });

  group('updateBudget', () {
    test('updates amountLimit, period, startDate and endDate', () async {
      final category = createCategory();
      final created = (await repository
              .createBudget(
                CreateBudgetParams(categoryUlid: category.ulid, amountLimit: 1000),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;

      final result = await repository
          .updateBudget(
            UpdateBudgetParams(
              ulid: created.ulid,
              amountLimit: 2000,
              period: BudgetPeriod.yearly,
              startDate: DateTime(2026, 1, 1),
              endDate: DateTime(2026, 12, 31),
            ),
          )
          .run();

      final updated = result.getOrElse((_) => throw Exception()).data!;
      expect(updated.amountLimit, 2000);
      expect(updated.budgetPeriod, BudgetPeriod.yearly);
      expect(updated.startDate, DateTime(2026, 1, 1));
      expect(updated.endDate, DateTime(2026, 12, 31));
    });

    test('partially updates only amountLimit, leaving category untouched', () async {
      final category = createCategory();
      final created = (await repository
              .createBudget(
                CreateBudgetParams(categoryUlid: category.ulid, amountLimit: 1000),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;

      final result = await repository
          .updateBudget(
            UpdateBudgetParams(ulid: created.ulid, amountLimit: 5000),
          )
          .run();

      final updated = result.getOrElse((_) => throw Exception()).data!;
      expect(updated.amountLimit, 5000);
      expect(updated.category.target?.ulid, category.ulid);
    });

    test('reassigns to a different category', () async {
      final food = createCategory(name: 'Food');
      final transport = createCategory(name: 'Transport');
      final created = (await repository
              .createBudget(
                CreateBudgetParams(categoryUlid: food.ulid, amountLimit: 1000),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;

      final result = await repository
          .updateBudget(
            UpdateBudgetParams(ulid: created.ulid, categoryUlid: transport.ulid),
          )
          .run();

      final updated = result.getOrElse((_) => throw Exception()).data!;
      expect(updated.category.target?.ulid, transport.ulid);
    });

    test('fails for an unknown ulid', () async {
      final result = await repository
          .updateBudget(const UpdateBudgetParams(ulid: 'unknown', amountLimit: 100))
          .run();

      expect(result.isLeft(), isTrue);
    });

    test('fails when reassigned to a category that does not exist', () async {
      final category = createCategory();
      final created = (await repository
              .createBudget(
                CreateBudgetParams(categoryUlid: category.ulid, amountLimit: 1000),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;

      final result = await repository
          .updateBudget(
            UpdateBudgetParams(ulid: created.ulid, categoryUlid: 'unknown-ulid'),
          )
          .run();

      expect(result.isLeft(), isTrue);
    });
  });

  group('deleteBudget', () {
    test('removes the budget', () async {
      final category = createCategory();
      final created = (await repository
              .createBudget(
                CreateBudgetParams(categoryUlid: category.ulid, amountLimit: 1000),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;

      final result = await repository.deleteBudget(ulid: created.ulid).run();

      expect(result.isRight(), isTrue);
      final getResult = await repository.getBudgetById(ulid: created.ulid).run();
      expect(getResult.isLeft(), isTrue);
    });

    test('fails for an unknown ulid', () async {
      final result = await repository.deleteBudget(ulid: 'unknown').run();

      expect(result.isLeft(), isTrue);
    });
  });
}
