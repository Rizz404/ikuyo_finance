import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/category/models/create_category_params.dart';
import 'package:ikuyo_finance/features/category/models/get_categories_params.dart';
import 'package:ikuyo_finance/features/category/models/update_category_params.dart';
import 'package:ikuyo_finance/features/category/repositories/category_repository.dart';
import 'package:stream_transform/stream_transform.dart';

part 'category_event.dart';
part 'category_state.dart';

// * Debounce transformer for search
EventTransformer<E> debounce<E>(Duration duration) {
  return (events, mapper) => events.debounce(duration).switchMap(mapper);
}

class CategoryBloc extends Bloc<CategoryEvent, CategoryState> {
  CategoryBloc(this._categoryRepository) : super(const CategoryState()) {
    // * Read events
    on<CategoryFetched>(_onCategoryFetched);
    on<CategoryFetchedMore>(_onCategoryFetchedMore);
    on<CategoryRefreshed>(_onCategoryRefreshed);

    // * Search & filter events
    on<CategorySearched>(
      _onCategorySearched,
      transformer: debounce(const Duration(milliseconds: 300)),
    );
    on<CategoryFiltered>(_onCategoryFiltered);
    on<CategorySorted>(_onCategorySorted);
    on<CategoryFilterCleared>(_onCategoryFilterCleared);

    // * Write events
    on<CategoryCreated>(_onCategoryCreated);
    on<CategoryUpdated>(_onCategoryUpdated);
    on<CategoryDeleted>(_onCategoryDeleted);
    on<CategoryWriteStatusReset>(_onWriteStatusReset);
  }

  final CategoryRepository _categoryRepository;

  // * Fetch initial categories with all filter options
  Future<void> _onCategoryFetched(
    CategoryFetched event,
    Emitter<CategoryState> emit,
  ) async {
    emit(
      state.copyWith(
        status: CategoryStatus.loading,
        currentTypeFilter: () => event.type,
        currentSearchQuery: () => event.searchQuery,
        currentSortBy: event.sortBy ?? state.currentSortBy,
        currentSortOrder: event.sortOrder ?? state.currentSortOrder,
        currentParentUlidFilter: () => event.parentUlid,
        currentIsRootOnlyFilter: () => event.isRootOnly,
      ),
    );

    final result = await _categoryRepository
        .getCategories(
          GetCategoriesParams(
            type: event.type,
            searchQuery: event.searchQuery,
            sortBy: event.sortBy ?? state.currentSortBy,
            sortOrder: event.sortOrder ?? state.currentSortOrder,
            parentUlid: event.parentUlid,
            isRootOnly: event.isRootOnly,
          ),
        )
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: CategoryStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: CategoryStatus.success,
          categories: success.data,
          hasReachedMax: !success.cursor.hasNextPage,
          nextCursor: () => success.cursor.nextCursor,
          errorMessage: () => null,
        ),
      ),
    );
  }

  // * Load more categories (cursor-based pagination)
  Future<void> _onCategoryFetchedMore(
    CategoryFetchedMore event,
    Emitter<CategoryState> emit,
  ) async {
    if (state.hasReachedMax || state.isLoadingMore) return;

    emit(state.copyWith(status: CategoryStatus.loadingMore));

    final result = await _categoryRepository
        .getCategories(
          GetCategoriesParams(
            cursor: state.nextCursor,
            type: state.currentTypeFilter,
            searchQuery: state.currentSearchQuery,
            sortBy: state.currentSortBy,
            sortOrder: state.currentSortOrder,
            parentUlid: state.currentParentUlidFilter,
            isRootOnly: state.currentIsRootOnlyFilter,
          ),
        )
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: CategoryStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: CategoryStatus.success,
          categories: [...state.categories, ...?success.data],
          hasReachedMax: !success.cursor.hasNextPage,
          nextCursor: () => success.cursor.nextCursor,
          errorMessage: () => null,
        ),
      ),
    );
  }

  // * Refresh categories (reset & fetch with current filters)
  Future<void> _onCategoryRefreshed(
    CategoryRefreshed event,
    Emitter<CategoryState> emit,
  ) async {
    emit(
      state.copyWith(
        status: CategoryStatus.loading,
        hasReachedMax: false,
        nextCursor: () => null,
      ),
    );

    final result = await _categoryRepository
        .getCategories(
          GetCategoriesParams(
            type: state.currentTypeFilter,
            searchQuery: state.currentSearchQuery,
            sortBy: state.currentSortBy,
            sortOrder: state.currentSortOrder,
            parentUlid: state.currentParentUlidFilter,
            isRootOnly: state.currentIsRootOnlyFilter,
          ),
        )
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: CategoryStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: CategoryStatus.success,
          categories: success.data,
          hasReachedMax: !success.cursor.hasNextPage,
          nextCursor: () => success.cursor.nextCursor,
          errorMessage: () => null,
        ),
      ),
    );
  }

  // * Search categories by name (debounced)
  Future<void> _onCategorySearched(
    CategorySearched event,
    Emitter<CategoryState> emit,
  ) async {
    final query = event.query.trim();

    emit(
      state.copyWith(
        status: CategoryStatus.loading,
        currentSearchQuery: () => query.isEmpty ? null : query,
        hasReachedMax: false,
        nextCursor: () => null,
      ),
    );

    final result = await _categoryRepository
        .getCategories(
          GetCategoriesParams(
            type: state.currentTypeFilter,
            searchQuery: query.isEmpty ? null : query,
            sortBy: state.currentSortBy,
            sortOrder: state.currentSortOrder,
            parentUlid: state.currentParentUlidFilter,
            isRootOnly: state.currentIsRootOnlyFilter,
          ),
        )
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: CategoryStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: CategoryStatus.success,
          categories: success.data,
          hasReachedMax: !success.cursor.hasNextPage,
          nextCursor: () => success.cursor.nextCursor,
          errorMessage: () => null,
        ),
      ),
    );
  }

  // * Apply multiple filters at once
  Future<void> _onCategoryFiltered(
    CategoryFiltered event,
    Emitter<CategoryState> emit,
  ) async {
    emit(
      state.copyWith(
        status: CategoryStatus.loading,
        currentTypeFilter: () => event.type,
        currentParentUlidFilter: () => event.parentUlid,
        currentIsRootOnlyFilter: () => event.isRootOnly,
        hasReachedMax: false,
        nextCursor: () => null,
      ),
    );

    final result = await _categoryRepository
        .getCategories(
          GetCategoriesParams(
            type: event.type,
            searchQuery: state.currentSearchQuery,
            sortBy: state.currentSortBy,
            sortOrder: state.currentSortOrder,
            parentUlid: event.parentUlid,
            isRootOnly: event.isRootOnly,
          ),
        )
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: CategoryStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: CategoryStatus.success,
          categories: success.data,
          hasReachedMax: !success.cursor.hasNextPage,
          nextCursor: () => success.cursor.nextCursor,
          errorMessage: () => null,
        ),
      ),
    );
  }

  // * Change sorting options
  Future<void> _onCategorySorted(
    CategorySorted event,
    Emitter<CategoryState> emit,
  ) async {
    emit(
      state.copyWith(
        status: CategoryStatus.loading,
        currentSortBy: event.sortBy,
        currentSortOrder: event.sortOrder,
        hasReachedMax: false,
        nextCursor: () => null,
      ),
    );

    final result = await _categoryRepository
        .getCategories(
          GetCategoriesParams(
            type: state.currentTypeFilter,
            searchQuery: state.currentSearchQuery,
            sortBy: event.sortBy,
            sortOrder: event.sortOrder,
            parentUlid: state.currentParentUlidFilter,
            isRootOnly: state.currentIsRootOnlyFilter,
          ),
        )
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: CategoryStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: CategoryStatus.success,
          categories: success.data,
          hasReachedMax: !success.cursor.hasNextPage,
          nextCursor: () => success.cursor.nextCursor,
          errorMessage: () => null,
        ),
      ),
    );
  }

  // * Clear all filters and reset to default
  Future<void> _onCategoryFilterCleared(
    CategoryFilterCleared event,
    Emitter<CategoryState> emit,
  ) async {
    emit(
      state.copyWith(
        status: CategoryStatus.loading,
        currentTypeFilter: () => null,
        currentSearchQuery: () => null,
        currentSortBy: CategorySortBy.createdAt,
        currentSortOrder: CategorySortOrder.descending,
        currentParentUlidFilter: () => null,
        currentIsRootOnlyFilter: () => null,
        hasReachedMax: false,
        nextCursor: () => null,
      ),
    );

    final result = await _categoryRepository
        .getCategories(const GetCategoriesParams())
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: CategoryStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: CategoryStatus.success,
          categories: success.data,
          hasReachedMax: !success.cursor.hasNextPage,
          nextCursor: () => success.cursor.nextCursor,
          errorMessage: () => null,
        ),
      ),
    );
  }

  // * Create category
  Future<void> _onCategoryCreated(
    CategoryCreated event,
    Emitter<CategoryState> emit,
  ) async {
    emit(state.copyWith(writeStatus: CategoryWriteStatus.loading));

    final result = await _categoryRepository.createCategory(event.params).run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          writeStatus: CategoryWriteStatus.failure,
          writeErrorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          writeStatus: CategoryWriteStatus.success,
          writeSuccessMessage: () => success.message,
          lastCreatedCategory: () => success.data,
          // * Tambah ke list langsung untuk UX responsif
          categories: [success.data!, ...state.categories],
        ),
      ),
    );
  }

  // * Update category
  Future<void> _onCategoryUpdated(
    CategoryUpdated event,
    Emitter<CategoryState> emit,
  ) async {
    emit(state.copyWith(writeStatus: CategoryWriteStatus.loading));

    final result = await _categoryRepository.updateCategory(event.params).run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          writeStatus: CategoryWriteStatus.failure,
          writeErrorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          writeStatus: CategoryWriteStatus.success,
          writeSuccessMessage: () => success.message,
          // * Update item di list
          categories: state.categories.map((cat) {
            return cat.ulid == event.params.ulid ? success.data! : cat;
          }).toList(),
        ),
      ),
    );
  }

  // * Delete category
  Future<void> _onCategoryDeleted(
    CategoryDeleted event,
    Emitter<CategoryState> emit,
  ) async {
    emit(state.copyWith(writeStatus: CategoryWriteStatus.loading));

    final result = await _categoryRepository
        .deleteCategory(ulid: event.ulid)
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          writeStatus: CategoryWriteStatus.failure,
          writeErrorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          writeStatus: CategoryWriteStatus.success,
          writeSuccessMessage: () => success.message,
          // * Hapus dari list
          categories: state.categories
              .where((cat) => cat.ulid != event.ulid)
              .toList(),
        ),
      ),
    );
  }

  // * Reset write status (panggil dari UI setelah handle success/error)
  void _onWriteStatusReset(
    CategoryWriteStatusReset event,
    Emitter<CategoryState> emit,
  ) {
    emit(
      state.copyWith(
        writeStatus: CategoryWriteStatus.initial,
        writeSuccessMessage: () => null,
        writeErrorMessage: () => null,
        lastCreatedCategory: () => null,
      ),
    );
  }
}
