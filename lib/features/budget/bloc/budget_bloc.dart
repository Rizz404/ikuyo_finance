import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/budget/models/create_budget_params.dart';
import 'package:ikuyo_finance/features/budget/models/get_budgets_params.dart';
import 'package:ikuyo_finance/features/budget/models/update_budget_params.dart';
import 'package:ikuyo_finance/features/budget/repositories/budget_repository.dart';

part 'budget_event.dart';
part 'budget_state.dart';

class BudgetBloc extends Bloc<BudgetEvent, BudgetState> {
  BudgetBloc(this._budgetRepository) : super(const BudgetState()) {
    // * Read events
    on<BudgetFetched>(_onBudgetFetched);
    on<BudgetFetchedMore>(_onBudgetFetchedMore);
    on<BudgetRefreshed>(_onBudgetRefreshed);

    // * Write events
    on<BudgetCreated>(_onBudgetCreated);
    on<BudgetUpdated>(_onBudgetUpdated);
    on<BudgetDeleted>(_onBudgetDeleted);
    on<BudgetWriteStatusReset>(_onWriteStatusReset);
  }

  final BudgetRepository _budgetRepository;

  // * Fetch initial budgets
  Future<void> _onBudgetFetched(
    BudgetFetched event,
    Emitter<BudgetState> emit,
  ) async {
    emit(
      state.copyWith(
        status: BudgetStatus.loading,
        currentPeriodFilter: () => event.period,
        currentCategoryFilter: () => event.categoryUlid,
      ),
    );

    final result = await _budgetRepository
        .getBudgets(
          GetBudgetsParams(
            period: event.period,
            categoryUlid: event.categoryUlid,
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

  // * Load more budgets (pagination)
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

  // * Refresh budgets (reset & fetch)
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
