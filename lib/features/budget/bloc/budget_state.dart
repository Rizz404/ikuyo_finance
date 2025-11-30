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

  // * Filter state
  final BudgetPeriod? currentPeriodFilter;
  final String? currentCategoryFilter;
  final String? currentSearchQuery;
  final BudgetSortBy currentSortBy;
  final BudgetSortOrder currentSortOrder;
  final double? currentMinAmountLimit;
  final double? currentMaxAmountLimit;
  final DateTime? currentStartDateFrom;
  final DateTime? currentStartDateTo;
  final DateTime? currentEndDateFrom;
  final DateTime? currentEndDateTo;

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
    this.currentSearchQuery,
    this.currentSortBy = BudgetSortBy.createdAt,
    this.currentSortOrder = BudgetSortOrder.descending,
    this.currentMinAmountLimit,
    this.currentMaxAmountLimit,
    this.currentStartDateFrom,
    this.currentStartDateTo,
    this.currentEndDateFrom,
    this.currentEndDateTo,
    this.writeStatus = BudgetWriteStatus.initial,
    this.writeSuccessMessage,
    this.writeErrorMessage,
    this.lastCreatedBudget,
  });

  // * Factory constructors for cleaner state creation
  const BudgetState.initial() : this();

  // * Computed properties
  bool get isLoading => status == BudgetStatus.loading;
  bool get isLoadingMore => status == BudgetStatus.loadingMore;
  bool get isWriting => writeStatus == BudgetWriteStatus.loading;

  // * Check if any filter is active
  bool get hasActiveFilters =>
      currentPeriodFilter != null ||
      currentCategoryFilter != null ||
      currentSearchQuery != null ||
      currentMinAmountLimit != null ||
      currentMaxAmountLimit != null ||
      currentStartDateFrom != null ||
      currentStartDateTo != null ||
      currentEndDateFrom != null ||
      currentEndDateTo != null;

  // * Get current params for refetching (useful for pagination)
  GetBudgetsParams get currentParams => GetBudgetsParams(
    cursor: nextCursor,
    period: currentPeriodFilter,
    categoryUlid: currentCategoryFilter,
    searchQuery: currentSearchQuery,
    sortBy: currentSortBy,
    sortOrder: currentSortOrder,
    minAmountLimit: currentMinAmountLimit,
    maxAmountLimit: currentMaxAmountLimit,
    startDateFrom: currentStartDateFrom,
    startDateTo: currentStartDateTo,
    endDateFrom: currentEndDateFrom,
    endDateTo: currentEndDateTo,
  );

  BudgetState copyWith({
    BudgetStatus? status,
    List<Budget>? budgets,
    String? Function()? errorMessage,
    bool? hasReachedMax,
    String? Function()? nextCursor,
    BudgetPeriod? Function()? currentPeriodFilter,
    String? Function()? currentCategoryFilter,
    String? Function()? currentSearchQuery,
    BudgetSortBy? currentSortBy,
    BudgetSortOrder? currentSortOrder,
    double? Function()? currentMinAmountLimit,
    double? Function()? currentMaxAmountLimit,
    DateTime? Function()? currentStartDateFrom,
    DateTime? Function()? currentStartDateTo,
    DateTime? Function()? currentEndDateFrom,
    DateTime? Function()? currentEndDateTo,
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
      currentSearchQuery: currentSearchQuery != null
          ? currentSearchQuery()
          : this.currentSearchQuery,
      currentSortBy: currentSortBy ?? this.currentSortBy,
      currentSortOrder: currentSortOrder ?? this.currentSortOrder,
      currentMinAmountLimit: currentMinAmountLimit != null
          ? currentMinAmountLimit()
          : this.currentMinAmountLimit,
      currentMaxAmountLimit: currentMaxAmountLimit != null
          ? currentMaxAmountLimit()
          : this.currentMaxAmountLimit,
      currentStartDateFrom: currentStartDateFrom != null
          ? currentStartDateFrom()
          : this.currentStartDateFrom,
      currentStartDateTo: currentStartDateTo != null
          ? currentStartDateTo()
          : this.currentStartDateTo,
      currentEndDateFrom: currentEndDateFrom != null
          ? currentEndDateFrom()
          : this.currentEndDateFrom,
      currentEndDateTo: currentEndDateTo != null
          ? currentEndDateTo()
          : this.currentEndDateTo,
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
    currentSearchQuery,
    currentSortBy,
    currentSortOrder,
    currentMinAmountLimit,
    currentMaxAmountLimit,
    currentStartDateFrom,
    currentStartDateTo,
    currentEndDateFrom,
    currentEndDateTo,
    writeStatus,
    writeSuccessMessage,
    writeErrorMessage,
    lastCreatedBudget,
  ];
}
