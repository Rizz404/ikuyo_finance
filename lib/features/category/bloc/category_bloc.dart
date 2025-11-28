import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/category/models/create_category_params.dart';
import 'package:ikuyo_finance/features/category/models/get_categories_params.dart';
import 'package:ikuyo_finance/features/category/models/update_category_params.dart';
import 'package:ikuyo_finance/features/category/repositories/category_repository.dart';

part 'category_event.dart';
part 'category_state.dart';

class CategoryBloc extends Bloc<CategoryEvent, CategoryState> {
  CategoryBloc(this._categoryRepository) : super(const CategoryState()) {
    // * Read events
    on<CategoryFetched>(_onCategoryFetched);
    on<CategoryFetchedMore>(_onCategoryFetchedMore);
    on<CategoryRefreshed>(_onCategoryRefreshed);

    // * Write events
    on<CategoryCreated>(_onCategoryCreated);
    on<CategoryUpdated>(_onCategoryUpdated);
    on<CategoryDeleted>(_onCategoryDeleted);
    on<CategoryWriteStatusReset>(_onWriteStatusReset);
  }

  final CategoryRepository _categoryRepository;

  // * Fetch initial categories
  Future<void> _onCategoryFetched(
    CategoryFetched event,
    Emitter<CategoryState> emit,
  ) async {
    emit(
      state.copyWith(
        status: CategoryStatus.loading,
        currentFilter: () => event.type,
      ),
    );

    final result = await _categoryRepository
        .getCategories(GetCategoriesParams(type: event.type))
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

  // * Load more categories (pagination)
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
            type: state.currentFilter,
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

  // * Refresh categories (reset & fetch)
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
        .getCategories(GetCategoriesParams(type: state.currentFilter))
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
