import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/budget/bloc/budget_bloc.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/budget/models/create_budget_params.dart';
import 'package:ikuyo_finance/features/budget/models/get_budgets_params.dart';
import 'package:ikuyo_finance/features/budget/models/update_budget_params.dart';
import 'package:ikuyo_finance/features/budget/repositories/budget_repository_impl.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';

import '../../../support/objectbox_test_store.dart';
import '../../../support/test_logger.dart';

void main() {
  setUpAll(bootstrapTestLogger);

  late ObjectBoxTestStore testStore;
  late BudgetRepositoryImpl repository;

  setUp(() async {
    testStore = await ObjectBoxTestStore.open();
    repository = BudgetRepositoryImpl(testStore.storage);
  });

  tearDown(() => testStore.close());

  // * Budgets belong to a Category, which BudgetRepositoryImpl looks up
  // * directly via ObjectBoxStorage - seed categories straight into the box.
  Category createCategory({String name = 'Food', CategoryType type = CategoryType.expense}) {
    final category = Category(name: name, type: type.index);
    testStore.storage.box<Category>().put(category);
    return category;
  }

  group('BudgetFetched', () {
    blocTest<BudgetBloc, BudgetState>(
      'emits [loading, success] with the fetched budgets',
      setUp: () async {
        final category = createCategory();
        await repository
            .createBudget(
              CreateBudgetParams(categoryUlid: category.ulid, amountLimit: 500),
            )
            .run();
      },
      build: () => BudgetBloc(repository),
      act: (bloc) => bloc.add(const BudgetFetched()),
      expect: () => [
        predicate<BudgetState>((s) => s.status == BudgetStatus.loading),
        predicate<BudgetState>(
          (s) =>
              s.status == BudgetStatus.success &&
              s.budgets.length == 1 &&
              s.budgets.first.amountLimit == 500,
        ),
      ],
    );

    blocTest<BudgetBloc, BudgetState>(
      'emits an empty success state when there is no data',
      build: () => BudgetBloc(repository),
      act: (bloc) => bloc.add(const BudgetFetched()),
      expect: () => [
        predicate<BudgetState>((s) => s.status == BudgetStatus.loading),
        predicate<BudgetState>(
          (s) => s.status == BudgetStatus.success && s.budgets.isEmpty,
        ),
      ],
    );

    blocTest<BudgetBloc, BudgetState>(
      'filters by period when fetching',
      setUp: () async {
        final category = createCategory();
        await repository
            .createBudget(
              CreateBudgetParams(
                categoryUlid: category.ulid,
                amountLimit: 500,
                period: BudgetPeriod.monthly,
              ),
            )
            .run();
        await repository
            .createBudget(
              CreateBudgetParams(
                categoryUlid: category.ulid,
                amountLimit: 900,
                period: BudgetPeriod.weekly,
              ),
            )
            .run();
      },
      build: () => BudgetBloc(repository),
      act: (bloc) => bloc.add(const BudgetFetched(period: BudgetPeriod.weekly)),
      expect: () => [
        predicate<BudgetState>((s) => s.status == BudgetStatus.loading),
        predicate<BudgetState>(
          (s) =>
              s.status == BudgetStatus.success &&
              s.budgets.length == 1 &&
              s.budgets.first.amountLimit == 900 &&
              s.currentPeriodFilter == BudgetPeriod.weekly,
        ),
      ],
    );
  });

  group('BudgetFetchedMore', () {
    blocTest<BudgetBloc, BudgetState>(
      'loads the next page and reports hasReachedMax once exhausted',
      setUp: () async {
        final category = createCategory();
        for (var i = 0; i < 25; i++) {
          await repository
              .createBudget(
                CreateBudgetParams(categoryUlid: category.ulid, amountLimit: (100 + i).toDouble()),
              )
              .run();
        }
      },
      build: () => BudgetBloc(repository),
      act: (bloc) async {
        bloc.add(const BudgetFetched());
        await bloc.stream.firstWhere((s) => s.status == BudgetStatus.success);
        bloc.add(const BudgetFetchedMore());
      },
      skip: 1,
      expect: () => [
        predicate<BudgetState>(
          (s) =>
              s.status == BudgetStatus.success &&
              s.budgets.length == 20 &&
              !s.hasReachedMax,
        ),
        predicate<BudgetState>((s) => s.status == BudgetStatus.loadingMore),
        predicate<BudgetState>(
          (s) =>
              s.status == BudgetStatus.success &&
              s.budgets.length == 25 &&
              s.hasReachedMax,
        ),
      ],
    );

    blocTest<BudgetBloc, BudgetState>(
      'does nothing when hasReachedMax is already true',
      seed: () => const BudgetState(hasReachedMax: true),
      build: () => BudgetBloc(repository),
      act: (bloc) => bloc.add(const BudgetFetchedMore()),
      expect: () => [],
    );
  });

  group('BudgetRefreshed', () {
    blocTest<BudgetBloc, BudgetState>(
      'resets pagination and refetches with current filters',
      setUp: () async {
        final category = createCategory();
        await repository
            .createBudget(
              CreateBudgetParams(categoryUlid: category.ulid, amountLimit: 500),
            )
            .run();
      },
      build: () => BudgetBloc(repository),
      seed: () => const BudgetState(hasReachedMax: true, nextCursor: '20'),
      act: (bloc) => bloc.add(const BudgetRefreshed()),
      expect: () => [
        predicate<BudgetState>(
          (s) => s.status == BudgetStatus.loading && !s.hasReachedMax,
        ),
        predicate<BudgetState>(
          (s) => s.status == BudgetStatus.success && s.budgets.length == 1,
        ),
      ],
    );
  });

  group('BudgetSearched', () {
    blocTest<BudgetBloc, BudgetState>(
      'debounces and filters by category name',
      setUp: () async {
        final food = createCategory(name: 'Food');
        final transport = createCategory(name: 'Transport');
        await repository
            .createBudget(
              CreateBudgetParams(categoryUlid: food.ulid, amountLimit: 500),
            )
            .run();
        await repository
            .createBudget(
              CreateBudgetParams(categoryUlid: transport.ulid, amountLimit: 900),
            )
            .run();
      },
      build: () => BudgetBloc(repository),
      act: (bloc) => bloc.add(const BudgetSearched(query: 'foo')),
      wait: const Duration(milliseconds: 350),
      expect: () => [
        predicate<BudgetState>((s) => s.status == BudgetStatus.loading),
        predicate<BudgetState>(
          (s) =>
              s.status == BudgetStatus.success &&
              s.budgets.length == 1 &&
              s.budgets.first.amountLimit == 500,
        ),
      ],
    );
  });

  group('BudgetFiltered', () {
    blocTest<BudgetBloc, BudgetState>(
      'applies amount limit range filters',
      setUp: () async {
        final category = createCategory();
        await repository
            .createBudget(
              CreateBudgetParams(categoryUlid: category.ulid, amountLimit: 100),
            )
            .run();
        await repository
            .createBudget(
              CreateBudgetParams(categoryUlid: category.ulid, amountLimit: 900),
            )
            .run();
      },
      build: () => BudgetBloc(repository),
      act: (bloc) => bloc.add(const BudgetFiltered(minAmountLimit: 500)),
      expect: () => [
        predicate<BudgetState>((s) => s.status == BudgetStatus.loading),
        predicate<BudgetState>(
          (s) =>
              s.status == BudgetStatus.success &&
              s.budgets.length == 1 &&
              s.budgets.first.amountLimit == 900 &&
              s.currentMinAmountLimit == 500,
        ),
      ],
    );
  });

  group('BudgetSorted', () {
    blocTest<BudgetBloc, BudgetState>(
      'sorts budgets by amountLimit ascending',
      setUp: () async {
        final category = createCategory();
        await repository
            .createBudget(
              CreateBudgetParams(categoryUlid: category.ulid, amountLimit: 900),
            )
            .run();
        await repository
            .createBudget(
              CreateBudgetParams(categoryUlid: category.ulid, amountLimit: 100),
            )
            .run();
      },
      build: () => BudgetBloc(repository),
      act: (bloc) => bloc.add(
        const BudgetSorted(
          sortBy: BudgetSortBy.amountLimit,
          sortOrder: BudgetSortOrder.ascending,
        ),
      ),
      expect: () => [
        predicate<BudgetState>((s) => s.status == BudgetStatus.loading),
        predicate<BudgetState>(
          (s) =>
              s.status == BudgetStatus.success &&
              s.budgets.first.amountLimit == 100,
        ),
      ],
    );
  });

  group('BudgetFilterCleared', () {
    blocTest<BudgetBloc, BudgetState>(
      'resets filters and sort back to defaults',
      build: () => BudgetBloc(repository),
      seed: () => const BudgetState(
        currentPeriodFilter: BudgetPeriod.weekly,
        currentSearchQuery: 'foo',
        currentMinAmountLimit: 100,
      ),
      act: (bloc) => bloc.add(const BudgetFilterCleared()),
      expect: () => [
        predicate<BudgetState>(
          (s) => s.status == BudgetStatus.loading && !s.hasActiveFilters,
        ),
        predicate<BudgetState>(
          (s) => s.status == BudgetStatus.success && !s.hasActiveFilters,
        ),
      ],
    );
  });

  group('BudgetCreated', () {
    blocTest<BudgetBloc, BudgetState>(
      'emits [writeLoading, writeSuccess] and prepends the new budget',
      setUp: () => createCategory(),
      build: () => BudgetBloc(repository),
      act: (bloc) async {
        final category = testStore.storage.box<Category>().getAll().single;
        bloc.add(
          BudgetCreated(
            params: CreateBudgetParams(
              categoryUlid: category.ulid,
              amountLimit: 500,
            ),
          ),
        );
      },
      expect: () => [
        predicate<BudgetState>((s) => s.writeStatus == BudgetWriteStatus.loading),
        predicate<BudgetState>(
          (s) =>
              s.writeStatus == BudgetWriteStatus.success &&
              s.budgets.length == 1 &&
              s.budgets.first.amountLimit == 500 &&
              s.lastCreatedBudget?.amountLimit == 500,
        ),
      ],
    );

    blocTest<BudgetBloc, BudgetState>(
      'emits [writeLoading, writeFailure] when the category does not exist',
      build: () => BudgetBloc(repository),
      act: (bloc) => bloc.add(
        const BudgetCreated(
          params: CreateBudgetParams(categoryUlid: 'unknown', amountLimit: 500),
        ),
      ),
      expect: () => [
        predicate<BudgetState>((s) => s.writeStatus == BudgetWriteStatus.loading),
        predicate<BudgetState>((s) => s.writeStatus == BudgetWriteStatus.failure),
      ],
    );
  });

  group('BudgetUpdated', () {
    blocTest<BudgetBloc, BudgetState>(
      'replaces the matching budget in the list on success',
      setUp: () async {
        final category = createCategory();
        await repository
            .createBudget(
              CreateBudgetParams(categoryUlid: category.ulid, amountLimit: 500),
            )
            .run();
      },
      build: () => BudgetBloc(repository),
      act: (bloc) async {
        bloc.add(const BudgetFetched());
        await bloc.stream.firstWhere((s) => s.status == BudgetStatus.success);
        final ulid = bloc.state.budgets.single.ulid;
        bloc.add(
          BudgetUpdated(
            params: UpdateBudgetParams(ulid: ulid, amountLimit: 750),
          ),
        );
      },
      skip: 2,
      expect: () => [
        predicate<BudgetState>((s) => s.writeStatus == BudgetWriteStatus.loading),
        predicate<BudgetState>(
          (s) =>
              s.writeStatus == BudgetWriteStatus.success &&
              s.budgets.single.amountLimit == 750,
        ),
      ],
    );

    blocTest<BudgetBloc, BudgetState>(
      'emits writeFailure for an unknown ulid',
      build: () => BudgetBloc(repository),
      act: (bloc) => bloc.add(
        const BudgetUpdated(
          params: UpdateBudgetParams(ulid: 'unknown', amountLimit: 100),
        ),
      ),
      expect: () => [
        predicate<BudgetState>((s) => s.writeStatus == BudgetWriteStatus.loading),
        predicate<BudgetState>((s) => s.writeStatus == BudgetWriteStatus.failure),
      ],
    );
  });

  group('BudgetDeleted', () {
    blocTest<BudgetBloc, BudgetState>(
      'removes the budget from the list on success',
      setUp: () async {
        final category = createCategory();
        await repository
            .createBudget(
              CreateBudgetParams(categoryUlid: category.ulid, amountLimit: 500),
            )
            .run();
      },
      build: () => BudgetBloc(repository),
      act: (bloc) async {
        bloc.add(const BudgetFetched());
        await bloc.stream.firstWhere((s) => s.status == BudgetStatus.success);
        final ulid = bloc.state.budgets.single.ulid;
        bloc.add(BudgetDeleted(ulid: ulid));
      },
      skip: 2,
      expect: () => [
        predicate<BudgetState>((s) => s.writeStatus == BudgetWriteStatus.loading),
        predicate<BudgetState>(
          (s) => s.writeStatus == BudgetWriteStatus.success && s.budgets.isEmpty,
        ),
      ],
    );

    blocTest<BudgetBloc, BudgetState>(
      'emits writeFailure for an unknown ulid',
      build: () => BudgetBloc(repository),
      act: (bloc) => bloc.add(const BudgetDeleted(ulid: 'unknown')),
      expect: () => [
        predicate<BudgetState>((s) => s.writeStatus == BudgetWriteStatus.loading),
        predicate<BudgetState>((s) => s.writeStatus == BudgetWriteStatus.failure),
      ],
    );
  });

  group('BudgetWriteStatusReset', () {
    blocTest<BudgetBloc, BudgetState>(
      'clears write status and messages back to initial',
      build: () => BudgetBloc(repository),
      seed: () => const BudgetState(
        writeStatus: BudgetWriteStatus.success,
        writeAction: BudgetWriteAction.create,
        writeSuccessMessage: 'done',
      ),
      act: (bloc) => bloc.add(const BudgetWriteStatusReset()),
      expect: () => [
        predicate<BudgetState>(
          (s) =>
              s.writeStatus == BudgetWriteStatus.initial &&
              s.writeAction == BudgetWriteAction.none &&
              s.writeSuccessMessage == null,
        ),
      ],
    );
  });
}
