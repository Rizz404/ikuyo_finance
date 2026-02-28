import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/features/transaction/models/create_transaction_params.dart';
import 'package:ikuyo_finance/features/transaction/models/get_transactions_params.dart';
import 'package:ikuyo_finance/features/transaction/models/update_transaction_params.dart';
import 'package:ikuyo_finance/features/transaction/repositories/transaction_repository.dart';
import 'package:stream_transform/stream_transform.dart';

part 'transaction_event.dart';
part 'transaction_state.dart';

// * Debounce transformer for search
EventTransformer<E> debounce<E>(Duration duration) {
  return (events, mapper) => events.debounce(duration).switchMap(mapper);
}

class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  TransactionBloc(this._transactionRepository) : super(TransactionState()) {
    // * Read events
    on<TransactionFetched>(_onTransactionFetched);
    on<TransactionFetchedMore>(_onTransactionFetchedMore);
    on<TransactionRefreshed>(_onTransactionRefreshed);

    // * Search & filter events
    on<TransactionSearched>(
      _onTransactionSearched,
      transformer: debounce(const Duration(milliseconds: 300)),
    );
    on<TransactionFiltered>(_onTransactionFiltered);
    on<TransactionSorted>(_onTransactionSorted);
    on<TransactionFilterCleared>(_onTransactionFilterCleared);
    on<TransactionMonthChanged>(_onTransactionMonthChanged);
    on<TransactionYearChanged>(_onTransactionYearChanged);

    // * Write events
    on<TransactionCreated>(_onTransactionCreated);
    on<TransactionBulkCreated>(_onTransactionBulkCreated);
    on<TransactionUpdated>(_onTransactionUpdated);
    on<TransactionDeleted>(_onTransactionDeleted);
    on<TransactionWriteStatusReset>(_onWriteStatusReset);
  }

  final TransactionRepository _transactionRepository;

  // * Fetch initial transactions with all filter options
  // * Auto-filters by current month if no date filter provided
  Future<void> _onTransactionFetched(
    TransactionFetched event,
    Emitter<TransactionState> emit,
  ) async {
    // * Use month filter by default if no explicit date range given
    final month = state.currentMonth;
    final startDate = event.startDate ?? DateTime(month.year, month.month, 1);
    final endDate =
        event.endDate ?? DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    emit(
      state.copyWith(
        status: TransactionStatus.loading,
        currentAssetFilter: () => event.assetUlid,
        currentCategoryFilter: () => event.categoryUlid,
        currentStartDateFilter: () => startDate,
        currentEndDateFilter: () => endDate,
        currentSearchQuery: () => event.searchQuery,
        currentSortBy: event.sortBy ?? state.currentSortBy,
        currentSortOrder: event.sortOrder ?? state.currentSortOrder,
        currentMinAmount: () => event.minAmount,
        currentMaxAmount: () => event.maxAmount,
      ),
    );

    final result = await _transactionRepository
        .getTransactions(
          GetTransactionsParams(
            assetUlid: event.assetUlid,
            categoryUlid: event.categoryUlid,
            startDate: startDate,
            endDate: endDate,
            searchQuery: event.searchQuery,
            sortBy: event.sortBy ?? state.currentSortBy,
            sortOrder: event.sortOrder ?? state.currentSortOrder,
            minAmount: event.minAmount,
            maxAmount: event.maxAmount,
          ),
        )
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: TransactionStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: TransactionStatus.success,
          transactions: success.data,
          hasReachedMax: !success.cursor.hasNextPage,
          nextCursor: () => success.cursor.nextCursor,
          errorMessage: () => null,
        ),
      ),
    );
  }

  // * Load more transactions (cursor-based pagination)
  Future<void> _onTransactionFetchedMore(
    TransactionFetchedMore event,
    Emitter<TransactionState> emit,
  ) async {
    if (state.hasReachedMax || state.isLoadingMore) return;

    emit(state.copyWith(status: TransactionStatus.loadingMore));

    final result = await _transactionRepository
        .getTransactions(
          GetTransactionsParams(
            cursor: state.nextCursor,
            assetUlid: state.currentAssetFilter,
            categoryUlid: state.currentCategoryFilter,
            startDate: state.currentStartDateFilter,
            endDate: state.currentEndDateFilter,
            searchQuery: state.currentSearchQuery,
            sortBy: state.currentSortBy,
            sortOrder: state.currentSortOrder,
            minAmount: state.currentMinAmount,
            maxAmount: state.currentMaxAmount,
          ),
        )
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: TransactionStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: TransactionStatus.success,
          transactions: [...state.transactions, ...?success.data],
          hasReachedMax: !success.cursor.hasNextPage,
          nextCursor: () => success.cursor.nextCursor,
          errorMessage: () => null,
        ),
      ),
    );
  }

  // * Refresh transactions (reset & fetch with current filters)
  Future<void> _onTransactionRefreshed(
    TransactionRefreshed event,
    Emitter<TransactionState> emit,
  ) async {
    emit(
      state.copyWith(
        status: TransactionStatus.loading,
        hasReachedMax: false,
        nextCursor: () => null,
      ),
    );

    final result = await _transactionRepository
        .getTransactions(
          GetTransactionsParams(
            assetUlid: state.currentAssetFilter,
            categoryUlid: state.currentCategoryFilter,
            startDate: state.currentStartDateFilter,
            endDate: state.currentEndDateFilter,
            searchQuery: state.currentSearchQuery,
            sortBy: state.currentSortBy,
            sortOrder: state.currentSortOrder,
            minAmount: state.currentMinAmount,
            maxAmount: state.currentMaxAmount,
          ),
        )
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: TransactionStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: TransactionStatus.success,
          transactions: success.data,
          hasReachedMax: !success.cursor.hasNextPage,
          nextCursor: () => success.cursor.nextCursor,
          errorMessage: () => null,
        ),
      ),
    );
  }

  // * Search transactions by description (debounced)
  Future<void> _onTransactionSearched(
    TransactionSearched event,
    Emitter<TransactionState> emit,
  ) async {
    final query = event.query.trim();

    emit(
      state.copyWith(
        status: TransactionStatus.loading,
        currentSearchQuery: () => query.isEmpty ? null : query,
        hasReachedMax: false,
        nextCursor: () => null,
      ),
    );

    final result = await _transactionRepository
        .getTransactions(
          GetTransactionsParams(
            assetUlid: state.currentAssetFilter,
            categoryUlid: state.currentCategoryFilter,
            startDate: state.currentStartDateFilter,
            endDate: state.currentEndDateFilter,
            searchQuery: query.isEmpty ? null : query,
            sortBy: state.currentSortBy,
            sortOrder: state.currentSortOrder,
            minAmount: state.currentMinAmount,
            maxAmount: state.currentMaxAmount,
          ),
        )
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: TransactionStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: TransactionStatus.success,
          transactions: success.data,
          hasReachedMax: !success.cursor.hasNextPage,
          nextCursor: () => success.cursor.nextCursor,
          errorMessage: () => null,
        ),
      ),
    );
  }

  // * Apply multiple filters at once
  Future<void> _onTransactionFiltered(
    TransactionFiltered event,
    Emitter<TransactionState> emit,
  ) async {
    emit(
      state.copyWith(
        status: TransactionStatus.loading,
        currentAssetFilter: () => event.assetUlid,
        currentCategoryFilter: () => event.categoryUlid,
        currentStartDateFilter: () => event.startDate,
        currentEndDateFilter: () => event.endDate,
        currentMinAmount: () => event.minAmount,
        currentMaxAmount: () => event.maxAmount,
        hasReachedMax: false,
        nextCursor: () => null,
      ),
    );

    final result = await _transactionRepository
        .getTransactions(
          GetTransactionsParams(
            assetUlid: event.assetUlid,
            categoryUlid: event.categoryUlid,
            startDate: event.startDate,
            endDate: event.endDate,
            searchQuery: state.currentSearchQuery,
            sortBy: state.currentSortBy,
            sortOrder: state.currentSortOrder,
            minAmount: event.minAmount,
            maxAmount: event.maxAmount,
          ),
        )
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: TransactionStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: TransactionStatus.success,
          transactions: success.data,
          hasReachedMax: !success.cursor.hasNextPage,
          nextCursor: () => success.cursor.nextCursor,
          errorMessage: () => null,
        ),
      ),
    );
  }

  // * Change sorting options
  Future<void> _onTransactionSorted(
    TransactionSorted event,
    Emitter<TransactionState> emit,
  ) async {
    emit(
      state.copyWith(
        status: TransactionStatus.loading,
        currentSortBy: event.sortBy,
        currentSortOrder: event.sortOrder,
        hasReachedMax: false,
        nextCursor: () => null,
      ),
    );

    final result = await _transactionRepository
        .getTransactions(
          GetTransactionsParams(
            assetUlid: state.currentAssetFilter,
            categoryUlid: state.currentCategoryFilter,
            startDate: state.currentStartDateFilter,
            endDate: state.currentEndDateFilter,
            searchQuery: state.currentSearchQuery,
            sortBy: event.sortBy,
            sortOrder: event.sortOrder,
            minAmount: state.currentMinAmount,
            maxAmount: state.currentMaxAmount,
          ),
        )
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: TransactionStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: TransactionStatus.success,
          transactions: success.data,
          hasReachedMax: !success.cursor.hasNextPage,
          nextCursor: () => success.cursor.nextCursor,
          errorMessage: () => null,
        ),
      ),
    );
  }

  // * Clear all filters and reset to default
  Future<void> _onTransactionFilterCleared(
    TransactionFilterCleared event,
    Emitter<TransactionState> emit,
  ) async {
    // * Reset filters but keep month navigation
    final startDate = DateTime(
      state.currentMonth.year,
      state.currentMonth.month,
      1,
    );
    final endDate = DateTime(
      state.currentMonth.year,
      state.currentMonth.month + 1,
      0,
      23,
      59,
      59,
    );

    emit(
      state.copyWith(
        status: TransactionStatus.loading,
        currentAssetFilter: () => null,
        currentCategoryFilter: () => null,
        currentStartDateFilter: () => startDate,
        currentEndDateFilter: () => endDate,
        currentSearchQuery: () => null,
        currentMinAmount: () => null,
        currentMaxAmount: () => null,
        currentSortBy: TransactionSortBy.transactionDate,
        currentSortOrder: SortOrder.descending,
        hasReachedMax: false,
        nextCursor: () => null,
      ),
    );

    final result = await _transactionRepository
        .getTransactions(
          GetTransactionsParams(startDate: startDate, endDate: endDate),
        )
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: TransactionStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: TransactionStatus.success,
          transactions: success.data,
          hasReachedMax: !success.cursor.hasNextPage,
          nextCursor: () => success.cursor.nextCursor,
          errorMessage: () => null,
        ),
      ),
    );
  }

  // * Change month and fetch transactions for that month
  Future<void> _onTransactionMonthChanged(
    TransactionMonthChanged event,
    Emitter<TransactionState> emit,
  ) async {
    final startDate = DateTime(event.month.year, event.month.month, 1);
    final endDate = DateTime(
      event.month.year,
      event.month.month + 1,
      0,
      23,
      59,
      59,
    );

    emit(
      state.copyWith(
        status: TransactionStatus.loading,
        currentMonth: event.month,
        currentStartDateFilter: () => startDate,
        currentEndDateFilter: () => endDate,
        hasReachedMax: false,
        nextCursor: () => null,
      ),
    );

    final result = await _transactionRepository
        .getTransactions(
          GetTransactionsParams(
            assetUlid: state.currentAssetFilter,
            categoryUlid: state.currentCategoryFilter,
            startDate: startDate,
            endDate: endDate,
            searchQuery: state.currentSearchQuery,
            sortBy: state.currentSortBy,
            sortOrder: state.currentSortOrder,
            minAmount: state.currentMinAmount,
            maxAmount: state.currentMaxAmount,
          ),
        )
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: TransactionStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: TransactionStatus.success,
          transactions: success.data,
          hasReachedMax: !success.cursor.hasNextPage,
          nextCursor: () => success.cursor.nextCursor,
          errorMessage: () => null,
        ),
      ),
    );
  }

  // * Change year and fetch transactions for that year (for monthly view)
  Future<void> _onTransactionYearChanged(
    TransactionYearChanged event,
    Emitter<TransactionState> emit,
  ) async {
    final startDate = DateTime(event.year, 1, 1);
    final endDate = DateTime(event.year, 12, 31, 23, 59, 59);

    emit(
      state.copyWith(
        status: TransactionStatus.loading,
        currentYear: event.year,
        currentStartDateFilter: () => startDate,
        currentEndDateFilter: () => endDate,
        hasReachedMax: false,
        nextCursor: () => null,
      ),
    );

    final result = await _transactionRepository
        .getTransactions(
          GetTransactionsParams(
            assetUlid: state.currentAssetFilter,
            categoryUlid: state.currentCategoryFilter,
            startDate: startDate,
            endDate: endDate,
            searchQuery: state.currentSearchQuery,
            sortBy: state.currentSortBy,
            sortOrder: state.currentSortOrder,
            minAmount: state.currentMinAmount,
            maxAmount: state.currentMaxAmount,
            limit: 500, // * Fetch more for yearly view
          ),
        )
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: TransactionStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: TransactionStatus.success,
          transactions: success.data,
          hasReachedMax: !success.cursor.hasNextPage,
          nextCursor: () => success.cursor.nextCursor,
          errorMessage: () => null,
        ),
      ),
    );
  }

  // * Create transaction
  Future<void> _onTransactionCreated(
    TransactionCreated event,
    Emitter<TransactionState> emit,
  ) async {
    emit(state.copyWith(writeStatus: TransactionWriteStatus.loading));

    final result = await _transactionRepository
        .createTransaction(event.params)
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          writeStatus: TransactionWriteStatus.failure,
          writeErrorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          writeStatus: TransactionWriteStatus.success,
          writeSuccessMessage: () => success.message,
          lastCreatedTransaction: () => success.data,
          // * Tambah ke list langsung untuk UX responsif
          transactions: [success.data!, ...state.transactions],
        ),
      ),
    );
  }

  // * Bulk create transactions
  Future<void> _onTransactionBulkCreated(
    TransactionBulkCreated event,
    Emitter<TransactionState> emit,
  ) async {
    emit(state.copyWith(writeStatus: TransactionWriteStatus.loading));

    final result = await _transactionRepository
        .createManyTransactions(event.paramsList)
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          writeStatus: TransactionWriteStatus.failure,
          writeErrorMessage: () => failure.message,
        ),
      ),
      (success) {
        final bulkResult = success.data!;
        final stateResult = BulkCreateStateResult(
          successCount: bulkResult.successfulTransactions.length,
          failureCount: bulkResult.failedTransactions.length,
          failedReasons: bulkResult.failedTransactions
              .map((f) => 'Item ${f.index + 1}: ${f.errorMessage}')
              .toList(),
        );

        emit(
          state.copyWith(
            writeStatus: TransactionWriteStatus.success,
            writeSuccessMessage: () => success.message,
            bulkCreateResult: () => stateResult,
            // * Tambah ke list langsung untuk UX responsif
            transactions: [
              ...bulkResult.successfulTransactions,
              ...state.transactions,
            ],
          ),
        );
      },
    );
  }

  // * Update transaction
  Future<void> _onTransactionUpdated(
    TransactionUpdated event,
    Emitter<TransactionState> emit,
  ) async {
    emit(state.copyWith(writeStatus: TransactionWriteStatus.loading));

    final result = await _transactionRepository
        .updateTransaction(event.params)
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          writeStatus: TransactionWriteStatus.failure,
          writeErrorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          writeStatus: TransactionWriteStatus.success,
          writeSuccessMessage: () => success.message,
          // * Update item di list
          transactions: state.transactions.map((transaction) {
            return transaction.ulid == event.params.ulid
                ? success.data!
                : transaction;
          }).toList(),
        ),
      ),
    );
  }

  // * Delete transaction
  Future<void> _onTransactionDeleted(
    TransactionDeleted event,
    Emitter<TransactionState> emit,
  ) async {
    emit(state.copyWith(writeStatus: TransactionWriteStatus.loading));

    final result = await _transactionRepository
        .deleteTransaction(ulid: event.ulid)
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          writeStatus: TransactionWriteStatus.failure,
          writeErrorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          writeStatus: TransactionWriteStatus.success,
          writeSuccessMessage: () => success.message,
          // * Hapus dari list
          transactions: state.transactions
              .where((transaction) => transaction.ulid != event.ulid)
              .toList(),
        ),
      ),
    );
  }

  // * Reset write status (panggil dari UI setelah handle success/error)
  void _onWriteStatusReset(
    TransactionWriteStatusReset event,
    Emitter<TransactionState> emit,
  ) {
    emit(
      state.copyWith(
        writeStatus: TransactionWriteStatus.initial,
        writeSuccessMessage: () => null,
        writeErrorMessage: () => null,
        lastCreatedTransaction: () => null,
      ),
    );
  }

  // * Public method for searchable dropdown - returns Future directly
  // * Does NOT affect bloc state, purely for dropdown search
  Future<List<Transaction>> searchTransactionsForDropdown({
    String? query,
  }) async {
    final result = await _transactionRepository
        .getTransactions(
          GetTransactionsParams(
            searchQuery: query?.isEmpty == true ? null : query,
            limit: 50,
            sortBy: TransactionSortBy.transactionDate,
            sortOrder: SortOrder.descending,
          ),
        )
        .run();

    return result.fold((failure) => [], (success) => success.data ?? []);
  }
}
