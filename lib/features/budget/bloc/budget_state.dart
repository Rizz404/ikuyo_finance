part of 'budget_bloc.dart';

// * Status untuk read operations (fetch, load more)
enum BudgetStatus { initial, loading, loadingMore, success, failure }

// * Status untuk write operations (create, update, delete)
enum BudgetWriteStatus { initial, loading, success, failure }

final class BudgetState extends Equatable {
  // * Read state
  final BudgetStatus status;
  final List<Budget> budgets;
  final String? errorMessage;
  final bool hasReachedMax;
  final String? nextCursor;
  final BudgetPeriod? currentPeriodFilter;
  final String? currentCategoryFilter;

  // * Write state (terpisah dari read)
  final BudgetWriteStatus writeStatus;
  final String? writeSuccessMessage;
  final String? writeErrorMessage;
  final Budget? lastCreatedBudget;

  const BudgetState({
    this.status = BudgetStatus.initial,
    this.budgets = const [],
    this.errorMessage,
    this.hasReachedMax = false,
    this.nextCursor,
    this.currentPeriodFilter,
    this.currentCategoryFilter,
    this.writeStatus = BudgetWriteStatus.initial,
    this.writeSuccessMessage,
    this.writeErrorMessage,
    this.lastCreatedBudget,
  });

  // * Factory constructors for cleaner state creation
  const BudgetState.initial() : this();

  bool get isLoading => status == BudgetStatus.loading;
  bool get isLoadingMore => status == BudgetStatus.loadingMore;
  bool get isWriting => writeStatus == BudgetWriteStatus.loading;

  BudgetState copyWith({
    BudgetStatus? status,
    List<Budget>? budgets,
    String? Function()? errorMessage,
    bool? hasReachedMax,
    String? Function()? nextCursor,
    BudgetPeriod? Function()? currentPeriodFilter,
    String? Function()? currentCategoryFilter,
    BudgetWriteStatus? writeStatus,
    String? Function()? writeSuccessMessage,
    String? Function()? writeErrorMessage,
    Budget? Function()? lastCreatedBudget,
  }) {
    return BudgetState(
      status: status ?? this.status,
      budgets: budgets ?? this.budgets,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      nextCursor: nextCursor != null ? nextCursor() : this.nextCursor,
      currentPeriodFilter: currentPeriodFilter != null
          ? currentPeriodFilter()
          : this.currentPeriodFilter,
      currentCategoryFilter: currentCategoryFilter != null
          ? currentCategoryFilter()
          : this.currentCategoryFilter,
      writeStatus: writeStatus ?? this.writeStatus,
      writeSuccessMessage: writeSuccessMessage != null
          ? writeSuccessMessage()
          : this.writeSuccessMessage,
      writeErrorMessage: writeErrorMessage != null
          ? writeErrorMessage()
          : this.writeErrorMessage,
      lastCreatedBudget: lastCreatedBudget != null
          ? lastCreatedBudget()
          : this.lastCreatedBudget,
    );
  }

  @override
  List<Object?> get props => [
    status,
    budgets,
    errorMessage,
    hasReachedMax,
    nextCursor,
    currentPeriodFilter,
    currentCategoryFilter,
    writeStatus,
    writeSuccessMessage,
    writeErrorMessage,
    lastCreatedBudget,
  ];
}
