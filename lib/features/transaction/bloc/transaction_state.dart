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
  final String? currentWalletFilter;
  final String? currentCategoryFilter;
  final DateTime? currentStartDateFilter;
  final DateTime? currentEndDateFilter;

  // * Write state (terpisah dari read)
  final TransactionWriteStatus writeStatus;
  final String? writeSuccessMessage;
  final String? writeErrorMessage;
  final Transaction? lastCreatedTransaction;

  const TransactionState({
    this.status = TransactionStatus.initial,
    this.transactions = const [],
    this.errorMessage,
    this.hasReachedMax = false,
    this.nextCursor,
    this.currentWalletFilter,
    this.currentCategoryFilter,
    this.currentStartDateFilter,
    this.currentEndDateFilter,
    this.writeStatus = TransactionWriteStatus.initial,
    this.writeSuccessMessage,
    this.writeErrorMessage,
    this.lastCreatedTransaction,
  });

  // * Factory constructors for cleaner state creation
  const TransactionState.initial() : this();

  bool get isLoading => status == TransactionStatus.loading;
  bool get isLoadingMore => status == TransactionStatus.loadingMore;
  bool get isWriting => writeStatus == TransactionWriteStatus.loading;

  TransactionState copyWith({
    TransactionStatus? status,
    List<Transaction>? transactions,
    String? Function()? errorMessage,
    bool? hasReachedMax,
    String? Function()? nextCursor,
    String? Function()? currentWalletFilter,
    String? Function()? currentCategoryFilter,
    DateTime? Function()? currentStartDateFilter,
    DateTime? Function()? currentEndDateFilter,
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
      currentWalletFilter: currentWalletFilter != null
          ? currentWalletFilter()
          : this.currentWalletFilter,
      currentCategoryFilter: currentCategoryFilter != null
          ? currentCategoryFilter()
          : this.currentCategoryFilter,
      currentStartDateFilter: currentStartDateFilter != null
          ? currentStartDateFilter()
          : this.currentStartDateFilter,
      currentEndDateFilter: currentEndDateFilter != null
          ? currentEndDateFilter()
          : this.currentEndDateFilter,
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
    currentWalletFilter,
    currentCategoryFilter,
    currentStartDateFilter,
    currentEndDateFilter,
    writeStatus,
    writeSuccessMessage,
    writeErrorMessage,
    lastCreatedTransaction,
  ];
}
