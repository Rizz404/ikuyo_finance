import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/budget/models/create_budget_params.dart';
import 'package:ikuyo_finance/features/budget/models/get_budgets_params.dart';
import 'package:ikuyo_finance/features/budget/models/update_budget_params.dart';
import 'package:ikuyo_finance/features/budget/repositories/budget_repository.dart';
import 'package:stream_transform/stream_transform.dart';

part 'budget_event.dart';
part 'budget_state.dart';

// * Debounce transformer for search
EventTransformer<E> debounce<E>(Duration duration) {
  return (events, mapper) => events.debounce(duration).switchMap(mapper);
}

class BudgetBloc extends Bloc<BudgetEvent, BudgetState> {
  BudgetBloc(this._budgetRepository) : super(const BudgetState()) {
    // * Read events
    on<BudgetFetched>(_onBudgetFetched);
    on<BudgetFetchedMore>(_onBudgetFetchedMore);
    on<BudgetRefreshed>(_onBudgetRefreshed);

    // * Search & filter events
    on<BudgetSearched>(
      _onBudgetSearched,
      transformer: debounce(const Duration(milliseconds: 300)),
    );
    on<BudgetFiltered>(_onBudgetFiltered);
    on<BudgetSorted>(_onBudgetSorted);
    on<BudgetFilterCleared>(_onBudgetFilterCleared);

    // * Write events
    on<BudgetCreated>(_onBudgetCreated);
    on<BudgetUpdated>(_onBudgetUpdated);
    on<BudgetDeleted>(_onBudgetDeleted);
    on<BudgetWriteStatusReset>(_onWriteStatusReset);
  }

  final BudgetRepository _budgetRepository;

  // * Fetch initial budgets with all filter options
  Future<void> _onBudgetFetched(
    BudgetFetched event,
    Emitter<BudgetState> emit,
  ) async {
    emit(
      state.copyWith(
        status: BudgetStatus.loading,
        currentPeriodFilter: () => event.period,
        currentCategoryFilter: () => event.categoryUlid,
        currentSearchQuery: () => event.searchQuery,
        currentSortBy: event.sortBy ?? state.currentSortBy,
        currentSortOrder: event.sortOrder ?? state.currentSortOrder,
        currentMinAmountLimit: () => event.minAmountLimit,
        currentMaxAmountLimit: () => event.maxAmountLimit,
        currentStartDateFrom: () => event.startDateFrom,
        currentStartDateTo: () => event.startDateTo,
        currentEndDateFrom: () => event.endDateFrom,
        currentEndDateTo: () => event.endDateTo,
      ),
    );

    final result = await _budgetRepository
        .getBudgets(
          GetBudgetsParams(
            period: event.period,
            categoryUlid: event.categoryUlid,
            searchQuery: event.searchQuery,
            sortBy: event.sortBy ?? state.currentSortBy,
            sortOrder: event.sortOrder ?? state.currentSortOrder,
            minAmountLimit: event.minAmountLimit,
            maxAmountLimit: event.maxAmountLimit,
            startDateFrom: event.startDateFrom,
            startDateTo: event.startDateTo,
            endDateFrom: event.endDateFrom,
            endDateTo: event.endDateTo,
          ),
        )
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: BudgetStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: BudgetStatus.success,
          budgets: success.data,
          hasReachedMax: !success.cursor.hasNextPage,
          nextCursor: () => success.cursor.nextCursor,
          errorMessage: () => null,
        ),
      ),
    );
  }

  // * Load more budgets (cursor-based pagination)
  Future<void> _onBudgetFetchedMore(
    BudgetFetchedMore event,
    Emitter<BudgetState> emit,
  ) async {
    if (state.hasReachedMax || state.isLoadingMore) return;

    emit(state.copyWith(status: BudgetStatus.loadingMore));

    final result = await _budgetRepository
        .getBudgets(
          GetBudgetsParams(
            cursor: state.nextCursor,
            period: state.currentPeriodFilter,
            categoryUlid: state.currentCategoryFilter,
            searchQuery: state.currentSearchQuery,
            sortBy: state.currentSortBy,
            sortOrder: state.currentSortOrder,
            minAmountLimit: state.currentMinAmountLimit,
            maxAmountLimit: state.currentMaxAmountLimit,
            startDateFrom: state.currentStartDateFrom,
            startDateTo: state.currentStartDateTo,
            endDateFrom: state.currentEndDateFrom,
            endDateTo: state.currentEndDateTo,
          ),
        )
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: BudgetStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: BudgetStatus.success,
          budgets: [...state.budgets, ...?success.data],
          hasReachedMax: !success.cursor.hasNextPage,
          nextCursor: () => success.cursor.nextCursor,
          errorMessage: () => null,
        ),
      ),
    );
  }

  // * Refresh budgets (reset & fetch with current filters)
  Future<void> _onBudgetRefreshed(
    BudgetRefreshed event,
    Emitter<BudgetState> emit,
  ) async {
    emit(
      state.copyWith(
        status: BudgetStatus.loading,
        hasReachedMax: false,
        nextCursor: () => null,
      ),
    );

    final result = await _budgetRepository
        .getBudgets(
          GetBudgetsParams(
            period: state.currentPeriodFilter,
            categoryUlid: state.currentCategoryFilter,
            searchQuery: state.currentSearchQuery,
            sortBy: state.currentSortBy,
            sortOrder: state.currentSortOrder,
            minAmountLimit: state.currentMinAmountLimit,
            maxAmountLimit: state.currentMaxAmountLimit,
            startDateFrom: state.currentStartDateFrom,
            startDateTo: state.currentStartDateTo,
            endDateFrom: state.currentEndDateFrom,
            endDateTo: state.currentEndDateTo,
          ),
        )
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: BudgetStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: BudgetStatus.success,
          budgets: success.data,
          hasReachedMax: !success.cursor.hasNextPage,
          nextCursor: () => success.cursor.nextCursor,
          errorMessage: () => null,
        ),
      ),
    );
  }

  // * Search budgets by category name (debounced)
  Future<void> _onBudgetSearched(
    BudgetSearched event,
    Emitter<BudgetState> emit,
  ) async {
    final query = event.query.trim();

    emit(
      state.copyWith(
        status: BudgetStatus.loading,
        currentSearchQuery: () => query.isEmpty ? null : query,
        hasReachedMax: false,
        nextCursor: () => null,
      ),
    );

    final result = await _budgetRepository
        .getBudgets(
          GetBudgetsParams(
            period: state.currentPeriodFilter,
            categoryUlid: state.currentCategoryFilter,
            searchQuery: query.isEmpty ? null : query,
            sortBy: state.currentSortBy,
            sortOrder: state.currentSortOrder,
            minAmountLimit: state.currentMinAmountLimit,
            maxAmountLimit: state.currentMaxAmountLimit,
            startDateFrom: state.currentStartDateFrom,
            startDateTo: state.currentStartDateTo,
            endDateFrom: state.currentEndDateFrom,
            endDateTo: state.currentEndDateTo,
          ),
        )
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: BudgetStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: BudgetStatus.success,
          budgets: success.data,
          hasReachedMax: !success.cursor.hasNextPage,
          nextCursor: () => success.cursor.nextCursor,
          errorMessage: () => null,
        ),
      ),
    );
  }

  // * Apply multiple filters at once
  Future<void> _onBudgetFiltered(
    BudgetFiltered event,
    Emitter<BudgetState> emit,
  ) async {
    emit(
      state.copyWith(
        status: BudgetStatus.loading,
        currentPeriodFilter: () => event.period,
        currentCategoryFilter: () => event.categoryUlid,
        currentMinAmountLimit: () => event.minAmountLimit,
        currentMaxAmountLimit: () => event.maxAmountLimit,
        currentStartDateFrom: () => event.startDateFrom,
        currentStartDateTo: () => event.startDateTo,
        currentEndDateFrom: () => event.endDateFrom,
        currentEndDateTo: () => event.endDateTo,
        hasReachedMax: false,
        nextCursor: () => null,
      ),
    );

    final result = await _budgetRepository
        .getBudgets(
          GetBudgetsParams(
            period: event.period,
            categoryUlid: event.categoryUlid,
            searchQuery: state.currentSearchQuery,
            sortBy: state.currentSortBy,
            sortOrder: state.currentSortOrder,
            minAmountLimit: event.minAmountLimit,
            maxAmountLimit: event.maxAmountLimit,
            startDateFrom: event.startDateFrom,
            startDateTo: event.startDateTo,
            endDateFrom: event.endDateFrom,
            endDateTo: event.endDateTo,
          ),
        )
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: BudgetStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: BudgetStatus.success,
          budgets: success.data,
          hasReachedMax: !success.cursor.hasNextPage,
          nextCursor: () => success.cursor.nextCursor,
          errorMessage: () => null,
        ),
      ),
    );
  }

  // * Change sorting options
  Future<void> _onBudgetSorted(
    BudgetSorted event,
    Emitter<BudgetState> emit,
  ) async {
    emit(
      state.copyWith(
        status: BudgetStatus.loading,
        currentSortBy: event.sortBy,
        currentSortOrder: event.sortOrder,
        hasReachedMax: false,
        nextCursor: () => null,
      ),
    );

    final result = await _budgetRepository
        .getBudgets(
          GetBudgetsParams(
            period: state.currentPeriodFilter,
            categoryUlid: state.currentCategoryFilter,
            searchQuery: state.currentSearchQuery,
            sortBy: event.sortBy,
            sortOrder: event.sortOrder,
            minAmountLimit: state.currentMinAmountLimit,
            maxAmountLimit: state.currentMaxAmountLimit,
            startDateFrom: state.currentStartDateFrom,
            startDateTo: state.currentStartDateTo,
            endDateFrom: state.currentEndDateFrom,
            endDateTo: state.currentEndDateTo,
          ),
        )
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: BudgetStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: BudgetStatus.success,
          budgets: success.data,
          hasReachedMax: !success.cursor.hasNextPage,
          nextCursor: () => success.cursor.nextCursor,
          errorMessage: () => null,
        ),
      ),
    );
  }

  // * Clear all filters and reset to default
  Future<void> _onBudgetFilterCleared(
    BudgetFilterCleared event,
    Emitter<BudgetState> emit,
  ) async {
    emit(
      state.copyWith(
        status: BudgetStatus.loading,
        currentPeriodFilter: () => null,
        currentCategoryFilter: () => null,
        currentSearchQuery: () => null,
        currentSortBy: BudgetSortBy.createdAt,
        currentSortOrder: BudgetSortOrder.descending,
        currentMinAmountLimit: () => null,
        currentMaxAmountLimit: () => null,
        currentStartDateFrom: () => null,
        currentStartDateTo: () => null,
        currentEndDateFrom: () => null,
        currentEndDateTo: () => null,
        hasReachedMax: false,
        nextCursor: () => null,
      ),
    );

    final result = await _budgetRepository
        .getBudgets(const GetBudgetsParams())
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: BudgetStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: BudgetStatus.success,
          budgets: success.data,
          hasReachedMax: !success.cursor.hasNextPage,
          nextCursor: () => success.cursor.nextCursor,
          errorMessage: () => null,
        ),
      ),
    );
  }

  // * Create budget
  Future<void> _onBudgetCreated(
    BudgetCreated event,
    Emitter<BudgetState> emit,
  ) async {
    emit(state.copyWith(writeStatus: BudgetWriteStatus.loading));

    final result = await _budgetRepository.createBudget(event.params).run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          writeStatus: BudgetWriteStatus.failure,
          writeErrorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          writeStatus: BudgetWriteStatus.success,
          writeSuccessMessage: () => success.message,
          lastCreatedBudget: () => success.data,
          // * Tambah ke list langsung untuk UX responsif
          budgets: [success.data!, ...state.budgets],
        ),
      ),
    );
  }

  // * Update budget
  Future<void> _onBudgetUpdated(
    BudgetUpdated event,
    Emitter<BudgetState> emit,
  ) async {
    emit(state.copyWith(writeStatus: BudgetWriteStatus.loading));

    final result = await _budgetRepository.updateBudget(event.params).run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          writeStatus: BudgetWriteStatus.failure,
          writeErrorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          writeStatus: BudgetWriteStatus.success,
          writeSuccessMessage: () => success.message,
          // * Update item di list
          budgets: state.budgets.map((budget) {
            return budget.ulid == event.params.ulid ? success.data! : budget;
          }).toList(),
        ),
      ),
    );
  }

  // * Delete budget
  Future<void> _onBudgetDeleted(
    BudgetDeleted event,
    Emitter<BudgetState> emit,
  ) async {
    emit(state.copyWith(writeStatus: BudgetWriteStatus.loading));

    final result = await _budgetRepository.deleteBudget(ulid: event.ulid).run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          writeStatus: BudgetWriteStatus.failure,
          writeErrorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          writeStatus: BudgetWriteStatus.success,
          writeSuccessMessage: () => success.message,
          // * Hapus dari list
          budgets: state.budgets
              .where((budget) => budget.ulid != event.ulid)
              .toList(),
        ),
      ),
    );
  }

  // * Reset write status (panggil dari UI setelah handle success/error)
  void _onWriteStatusReset(
    BudgetWriteStatusReset event,
    Emitter<BudgetState> emit,
  ) {
    emit(
      state.copyWith(
        writeStatus: BudgetWriteStatus.initial,
        writeSuccessMessage: () => null,
        writeErrorMessage: () => null,
        lastCreatedBudget: () => null,
      ),
    );
  }
}
