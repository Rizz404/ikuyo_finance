part of 'budget_bloc.dart';

sealed class BudgetEvent {
  const BudgetEvent();
}

// * Read Events
final class BudgetFetched extends BudgetEvent {
  const BudgetFetched({
    this.period,
    this.categoryUlid,
    this.searchQuery,
    this.sortBy,
    this.sortOrder,
    this.minAmountLimit,
    this.maxAmountLimit,
    this.startDateFrom,
    this.startDateTo,
    this.endDateFrom,
    this.endDateTo,
  });

  final BudgetPeriod? period;
  final String? categoryUlid;
  final String? searchQuery;
  final BudgetSortBy? sortBy;
  final BudgetSortOrder? sortOrder;
  final double? minAmountLimit;
  final double? maxAmountLimit;
  final DateTime? startDateFrom;
  final DateTime? startDateTo;
  final DateTime? endDateFrom;
  final DateTime? endDateTo;
}

final class BudgetFetchedMore extends BudgetEvent {
  const BudgetFetchedMore();
}

final class BudgetRefreshed extends BudgetEvent {
  const BudgetRefreshed();
}

// * Search event - dedicated for search functionality
final class BudgetSearched extends BudgetEvent {
  const BudgetSearched({required this.query});

  final String query;
}

// * Filter event - apply multiple filters at once
final class BudgetFiltered extends BudgetEvent {
  const BudgetFiltered({
    this.period,
    this.categoryUlid,
    this.minAmountLimit,
    this.maxAmountLimit,
    this.startDateFrom,
    this.startDateTo,
    this.endDateFrom,
    this.endDateTo,
  });

  final BudgetPeriod? period;
  final String? categoryUlid;
  final double? minAmountLimit;
  final double? maxAmountLimit;
  final DateTime? startDateFrom;
  final DateTime? startDateTo;
  final DateTime? endDateFrom;
  final DateTime? endDateTo;
}

// * Sort event - change sorting options
final class BudgetSorted extends BudgetEvent {
  const BudgetSorted({
    required this.sortBy,
    this.sortOrder = BudgetSortOrder.descending,
  });

  final BudgetSortBy sortBy;
  final BudgetSortOrder sortOrder;
}

// * Clear all filters
final class BudgetFilterCleared extends BudgetEvent {
  const BudgetFilterCleared();
}

// * Write Events
final class BudgetCreated extends BudgetEvent {
  const BudgetCreated({required this.params});

  final CreateBudgetParams params;
}

final class BudgetUpdated extends BudgetEvent {
  const BudgetUpdated({required this.params});

  final UpdateBudgetParams params;
}

final class BudgetDeleted extends BudgetEvent {
  const BudgetDeleted({required this.ulid});

  final String ulid;
}

// * Reset write status setelah UI handle
final class BudgetWriteStatusReset extends BudgetEvent {
  const BudgetWriteStatusReset();
}
