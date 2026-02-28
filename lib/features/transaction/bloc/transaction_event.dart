part of 'transaction_bloc.dart';

sealed class TransactionEvent {
  const TransactionEvent();
}

// * Read Events
final class TransactionFetched extends TransactionEvent {
  const TransactionFetched({
    this.assetUlid,
    this.categoryUlid,
    this.startDate,
    this.endDate,
    this.searchQuery,
    this.sortBy,
    this.sortOrder,
    this.minAmount,
    this.maxAmount,
  });

  final String? assetUlid;
  final String? categoryUlid;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? searchQuery;
  final TransactionSortBy? sortBy;
  final SortOrder? sortOrder;
  final double? minAmount;
  final double? maxAmount;
}

final class TransactionFetchedMore extends TransactionEvent {
  const TransactionFetchedMore();
}

final class TransactionRefreshed extends TransactionEvent {
  const TransactionRefreshed();
}

// * Search event - dedicated for search functionality
final class TransactionSearched extends TransactionEvent {
  const TransactionSearched({required this.query});

  final String query;
}

// * Filter event - apply multiple filters at once
final class TransactionFiltered extends TransactionEvent {
  const TransactionFiltered({
    this.assetUlid,
    this.categoryUlid,
    this.startDate,
    this.endDate,
    this.minAmount,
    this.maxAmount,
  });

  final String? assetUlid;
  final String? categoryUlid;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? minAmount;
  final double? maxAmount;
}

// * Sort event - change sorting options
final class TransactionSorted extends TransactionEvent {
  const TransactionSorted({
    required this.sortBy,
    this.sortOrder = SortOrder.descending,
  });

  final TransactionSortBy sortBy;
  final SortOrder sortOrder;
}

// * Clear all filters
final class TransactionFilterCleared extends TransactionEvent {
  const TransactionFilterCleared();
}

// * Month navigation - changes the current displayed month
final class TransactionMonthChanged extends TransactionEvent {
  const TransactionMonthChanged({required this.month});

  final DateTime month;
}

// * Year navigation - changes the current displayed year (for monthly view)
final class TransactionYearChanged extends TransactionEvent {
  const TransactionYearChanged({required this.year});

  final int year;
}

// * Write Events
final class TransactionCreated extends TransactionEvent {
  final CreateTransactionParams params;

  const TransactionCreated({required this.params});
}

// * Bulk Create Event - create multiple transactions at once
final class TransactionBulkCreated extends TransactionEvent {
  final List<CreateTransactionParams> paramsList;

  const TransactionBulkCreated({required this.paramsList});
}

final class TransactionUpdated extends TransactionEvent {
  final UpdateTransactionParams params;

  const TransactionUpdated({required this.params});
}

final class TransactionDeleted extends TransactionEvent {
  const TransactionDeleted({required this.ulid});

  final String ulid;
}

// * Reset write status setelah UI handle
final class TransactionWriteStatusReset extends TransactionEvent {
  const TransactionWriteStatusReset();
}
