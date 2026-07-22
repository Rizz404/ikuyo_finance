import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/category/bloc/category_bloc.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/category/models/create_category_params.dart';
import 'package:ikuyo_finance/features/category/models/update_category_params.dart';
import 'package:ikuyo_finance/features/category/repositories/category_repository_impl.dart';

import '../../../support/fake_app_file_storage.dart';
import '../../../support/objectbox_test_store.dart';
import '../../../support/test_logger.dart';

void main() {
  setUpAll(bootstrapTestLogger);

  late ObjectBoxTestStore testStore;
  late CategoryRepositoryImpl repository;

  setUp(() async {
    testStore = await ObjectBoxTestStore.open();
    repository = CategoryRepositoryImpl(testStore.storage, FakeAppFileStorage());
  });

  tearDown(() => testStore.close());

  group('CategoryFetched', () {
    blocTest<CategoryBloc, CategoryState>(
      'emits [loading, success] with the fetched categories',
      setUp: () async {
        await repository
            .createCategory(
              const CreateCategoryParams(name: 'Salary', type: CategoryType.income),
            )
            .run();
      },
      build: () => CategoryBloc(repository),
      act: (bloc) => bloc.add(const CategoryFetched()),
      expect: () => [
        predicate<CategoryState>((s) => s.status == CategoryStatus.loading),
        predicate<CategoryState>(
          (s) =>
              s.status == CategoryStatus.success &&
              s.categories.length == 1 &&
              s.categories.first.name == 'Salary',
        ),
      ],
    );

    blocTest<CategoryBloc, CategoryState>(
      'emits an empty success state when there is no data',
      build: () => CategoryBloc(repository),
      act: (bloc) => bloc.add(const CategoryFetched()),
      expect: () => [
        predicate<CategoryState>((s) => s.status == CategoryStatus.loading),
        predicate<CategoryState>(
          (s) => s.status == CategoryStatus.success && s.categories.isEmpty,
        ),
      ],
    );
  });

  group('CategoryCreated', () {
    blocTest<CategoryBloc, CategoryState>(
      'emits [writeLoading, writeSuccess] and prepends the new category',
      build: () => CategoryBloc(repository),
      act: (bloc) => bloc.add(
        const CategoryCreated(
          params: CreateCategoryParams(name: 'Food', type: CategoryType.expense),
        ),
      ),
      expect: () => [
        predicate<CategoryState>((s) => s.writeStatus == CategoryWriteStatus.loading),
        predicate<CategoryState>(
          (s) =>
              s.writeStatus == CategoryWriteStatus.success &&
              s.categories.length == 1 &&
              s.categories.first.name == 'Food',
        ),
      ],
    );

    blocTest<CategoryBloc, CategoryState>(
      'emits [writeLoading, writeFailure] when the parent does not exist',
      build: () => CategoryBloc(repository),
      act: (bloc) => bloc.add(
        const CategoryCreated(
          params: CreateCategoryParams(
            name: 'Snacks',
            type: CategoryType.expense,
            parentUlid: 'unknown',
          ),
        ),
      ),
      expect: () => [
        predicate<CategoryState>((s) => s.writeStatus == CategoryWriteStatus.loading),
        predicate<CategoryState>((s) => s.writeStatus == CategoryWriteStatus.failure),
      ],
    );
  });

  group('CategoryUpdated', () {
    blocTest<CategoryBloc, CategoryState>(
      'replaces the matching category in the list on success',
      setUp: () async {
        await repository
            .createCategory(
              const CreateCategoryParams(name: 'Food', type: CategoryType.expense),
            )
            .run();
      },
      build: () => CategoryBloc(repository),
      act: (bloc) async {
        bloc.add(const CategoryFetched());
        await bloc.stream.firstWhere((s) => s.status == CategoryStatus.success);
        final ulid = bloc.state.categories.single.ulid;
        bloc.add(
          CategoryUpdated(
            params: UpdateCategoryParams(ulid: ulid, name: 'Groceries', type: null),
          ),
        );
      },
      skip: 2,
      expect: () => [
        predicate<CategoryState>((s) => s.writeStatus == CategoryWriteStatus.loading),
        predicate<CategoryState>(
          (s) =>
              s.writeStatus == CategoryWriteStatus.success &&
              s.categories.single.name == 'Groceries',
        ),
      ],
    );
  });

  group('CategoryDeleted', () {
    blocTest<CategoryBloc, CategoryState>(
      'removes the category from the list on success',
      setUp: () async {
        await repository
            .createCategory(
              const CreateCategoryParams(name: 'Food', type: CategoryType.expense),
            )
            .run();
      },
      build: () => CategoryBloc(repository),
      act: (bloc) async {
        bloc.add(const CategoryFetched());
        await bloc.stream.firstWhere((s) => s.status == CategoryStatus.success);
        final ulid = bloc.state.categories.single.ulid;
        bloc.add(CategoryDeleted(ulid: ulid));
      },
      skip: 2,
      expect: () => [
        predicate<CategoryState>((s) => s.writeStatus == CategoryWriteStatus.loading),
        predicate<CategoryState>(
          (s) => s.writeStatus == CategoryWriteStatus.success && s.categories.isEmpty,
        ),
      ],
    );

    blocTest<CategoryBloc, CategoryState>(
      'emits writeFailure for an unknown ulid',
      build: () => CategoryBloc(repository),
      act: (bloc) => bloc.add(const CategoryDeleted(ulid: 'unknown')),
      expect: () => [
        predicate<CategoryState>((s) => s.writeStatus == CategoryWriteStatus.loading),
        predicate<CategoryState>((s) => s.writeStatus == CategoryWriteStatus.failure),
      ],
    );
  });

  group('CategorySearched', () {
    blocTest<CategoryBloc, CategoryState>(
      'debounces and filters by the search query',
      setUp: () async {
        await repository
            .createCategory(
              const CreateCategoryParams(name: 'Food', type: CategoryType.expense),
            )
            .run();
        await repository
            .createCategory(
              const CreateCategoryParams(name: 'Transport', type: CategoryType.expense),
            )
            .run();
      },
      build: () => CategoryBloc(repository),
      act: (bloc) => bloc.add(const CategorySearched(query: 'foo')),
      wait: const Duration(milliseconds: 350),
      expect: () => [
        predicate<CategoryState>((s) => s.status == CategoryStatus.loading),
        predicate<CategoryState>(
          (s) =>
              s.status == CategoryStatus.success &&
              s.categories.length == 1 &&
              s.categories.first.name == 'Food',
        ),
      ],
    );
  });

  group('CategoryFilterCleared', () {
    blocTest<CategoryBloc, CategoryState>(
      'resets filters and sort back to defaults',
      build: () => CategoryBloc(repository),
      seed: () => const CategoryState(
        currentTypeFilter: CategoryType.expense,
        currentSearchQuery: 'foo',
      ),
      act: (bloc) => bloc.add(const CategoryFilterCleared()),
      expect: () => [
        predicate<CategoryState>((s) => s.status == CategoryStatus.loading && !s.hasActiveFilters),
        predicate<CategoryState>((s) => s.status == CategoryStatus.success && !s.hasActiveFilters),
      ],
    );
  });

  group('CategoryWriteStatusReset', () {
    blocTest<CategoryBloc, CategoryState>(
      'clears write status and messages back to initial',
      build: () => CategoryBloc(repository),
      seed: () => const CategoryState(
        writeStatus: CategoryWriteStatus.success,
        writeAction: CategoryWriteAction.create,
        writeSuccessMessage: 'done',
      ),
      act: (bloc) => bloc.add(const CategoryWriteStatusReset()),
      expect: () => [
        predicate<CategoryState>(
          (s) =>
              s.writeStatus == CategoryWriteStatus.initial &&
              s.writeAction == CategoryWriteAction.none &&
              s.writeSuccessMessage == null,
        ),
      ],
    );
  });

  group('ValidParentCategoriesFetched', () {
    blocTest<CategoryBloc, CategoryState>(
      'loads only root categories of the requested type',
      setUp: () async {
        await repository
            .createCategory(
              const CreateCategoryParams(name: 'Food', type: CategoryType.expense),
            )
            .run();
        await repository
            .createCategory(
              const CreateCategoryParams(name: 'Salary', type: CategoryType.income),
            )
            .run();
      },
      build: () => CategoryBloc(repository),
      act: (bloc) => bloc.add(
        const ValidParentCategoriesFetched(type: CategoryType.expense),
      ),
      expect: () => [
        predicate<CategoryState>((s) => s.isLoadingParentCategories),
        predicate<CategoryState>(
          (s) =>
              !s.isLoadingParentCategories &&
              s.validParentCategories.length == 1 &&
              s.validParentCategories.first.name == 'Food',
        ),
      ],
    );
  });
}
