part of 'transaction_bloc.dart';

// * Status untuk read operations (fetch, load more)
enum TransactionStatus { initial, loading, loadingMore, success, failure }

// * Status untuk write operations (create, update, delete)
enum TransactionWriteStatus { initial, loading, success, failure }

final class TransactionState extends Equatable {
  // * Read state
  final TransactionStatus status;
  final List<Transaction> transactions;
  final String? errorMessage;
  final bool hasReachedMax;
  final String? nextCursor;

  // * Month navigation state
  final DateTime currentMonth;

  // * Year navigation state (for monthly view)
  final int currentYear;

  // * Filter state
  final String? currentAssetFilter;
  final String? currentCategoryFilter;
  final DateTime? currentStartDateFilter;
  final DateTime? currentEndDateFilter;
  final String? currentSearchQuery;
  final TransactionSortBy currentSortBy;
  final SortOrder currentSortOrder;
  final double? currentMinAmount;
  final double? currentMaxAmount;

  // * Write state (terpisah dari read)
  final TransactionWriteStatus writeStatus;
  final String? writeSuccessMessage;
  final String? writeErrorMessage;
  final Transaction? lastCreatedTransaction;

  TransactionState({
    this.status = TransactionStatus.initial,
    this.transactions = const [],
    this.errorMessage,
    this.hasReachedMax = false,
    this.nextCursor,
    DateTime? currentMonth,
    int? currentYear,
    this.currentAssetFilter,
    this.currentCategoryFilter,
    this.currentStartDateFilter,
    this.currentEndDateFilter,
    this.currentSearchQuery,
    this.currentSortBy = TransactionSortBy.transactionDate,
    this.currentSortOrder = SortOrder.descending,
    this.currentMinAmount,
    this.currentMaxAmount,
    this.writeStatus = TransactionWriteStatus.initial,
    this.writeSuccessMessage,
    this.writeErrorMessage,
    this.lastCreatedTransaction,
  }) : currentMonth = currentMonth ?? DateTime.now(),
       currentYear = currentYear ?? DateTime.now().year;

  // * Factory constructors for cleaner state creation
  factory TransactionState.initial() => TransactionState();

  // * Computed properties
  bool get isLoading => status == TransactionStatus.loading;
  bool get isLoadingMore => status == TransactionStatus.loadingMore;
  bool get isWriting => writeStatus == TransactionWriteStatus.loading;

  // * Check if any filter is active
  bool get hasActiveFilters =>
      currentAssetFilter != null ||
      currentCategoryFilter != null ||
      currentStartDateFilter != null ||
      currentEndDateFilter != null ||
      currentSearchQuery != null ||
      currentMinAmount != null ||
      currentMaxAmount != null;

  // * Get current params for refetching (useful for pagination)
  GetTransactionsParams get currentParams => GetTransactionsParams(
    cursor: nextCursor,
    assetUlid: currentAssetFilter,
    categoryUlid: currentCategoryFilter,
    startDate: currentStartDateFilter,
    endDate: currentEndDateFilter,
    searchQuery: currentSearchQuery,
    sortBy: currentSortBy,
    sortOrder: currentSortOrder,
    minAmount: currentMinAmount,
    maxAmount: currentMaxAmount,
  );

  TransactionState copyWith({
    TransactionStatus? status,
    List<Transaction>? transactions,
    String? Function()? errorMessage,
    bool? hasReachedMax,
    String? Function()? nextCursor,
    DateTime? currentMonth,
    int? currentYear,
    String? Function()? currentAssetFilter,
    String? Function()? currentCategoryFilter,
    DateTime? Function()? currentStartDateFilter,
    DateTime? Function()? currentEndDateFilter,
    String? Function()? currentSearchQuery,
    TransactionSortBy? currentSortBy,
    SortOrder? currentSortOrder,
    double? Function()? currentMinAmount,
    double? Function()? currentMaxAmount,
    TransactionWriteStatus? writeStatus,
    String? Function()? writeSuccessMessage,
    String? Function()? writeErrorMessage,
    Transaction? Function()? lastCreatedTransaction,
  }) {
    return TransactionState(
      status: status ?? this.status,
      transactions: transactions ?? this.transactions,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      nextCursor: nextCursor != null ? nextCursor() : this.nextCursor,
      currentMonth: currentMonth ?? this.currentMonth,
      currentYear: currentYear ?? this.currentYear,
      currentAssetFilter: currentAssetFilter != null
          ? currentAssetFilter()
          : this.currentAssetFilter,
      currentCategoryFilter: currentCategoryFilter != null
          ? currentCategoryFilter()
          : this.currentCategoryFilter,
      currentStartDateFilter: currentStartDateFilter != null
          ? currentStartDateFilter()
          : this.currentStartDateFilter,
      currentEndDateFilter: currentEndDateFilter != null
          ? currentEndDateFilter()
          : this.currentEndDateFilter,
      currentSearchQuery: currentSearchQuery != null
          ? currentSearchQuery()
          : this.currentSearchQuery,
      currentSortBy: currentSortBy ?? this.currentSortBy,
      currentSortOrder: currentSortOrder ?? this.currentSortOrder,
      currentMinAmount: currentMinAmount != null
          ? currentMinAmount()
          : this.currentMinAmount,
      currentMaxAmount: currentMaxAmount != null
          ? currentMaxAmount()
          : this.currentMaxAmount,
      writeStatus: writeStatus ?? this.writeStatus,
      writeSuccessMessage: writeSuccessMessage != null
          ? writeSuccessMessage()
          : this.writeSuccessMessage,
      writeErrorMessage: writeErrorMessage != null
          ? writeErrorMessage()
          : this.writeErrorMessage,
      lastCreatedTransaction: lastCreatedTransaction != null
          ? lastCreatedTransaction()
          : this.lastCreatedTransaction,
    );
  }

  @override
  List<Object?> get props => [
    status,
    transactions,
    errorMessage,
    hasReachedMax,
    nextCursor,
    currentMonth,
    currentYear,
    currentAssetFilter,
    currentCategoryFilter,
    currentStartDateFilter,
    currentEndDateFilter,
    currentSearchQuery,
    currentSortBy,
    currentSortOrder,
    currentMinAmount,
    currentMaxAmount,
    writeStatus,
    writeSuccessMessage,
    writeErrorMessage,
    lastCreatedTransaction,
  ];
}
