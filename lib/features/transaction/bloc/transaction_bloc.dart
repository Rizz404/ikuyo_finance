import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/features/transaction/models/create_transaction_params.dart';
import 'package:ikuyo_finance/features/transaction/models/get_transactions_params.dart';
import 'package:ikuyo_finance/features/transaction/models/update_transaction_params.dart';
import 'package:ikuyo_finance/features/transaction/repositories/transaction_repository.dart';

part 'transaction_event.dart';
part 'transaction_state.dart';

class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  TransactionBloc(this._transactionRepository)
    : super(const TransactionState()) {
    // * Read events
    on<TransactionFetched>(_onTransactionFetched);
    on<TransactionFetchedMore>(_onTransactionFetchedMore);
    on<TransactionRefreshed>(_onTransactionRefreshed);

    // * Write events
    on<TransactionCreated>(_onTransactionCreated);
    on<TransactionUpdated>(_onTransactionUpdated);
    on<TransactionDeleted>(_onTransactionDeleted);
    on<TransactionWriteStatusReset>(_onWriteStatusReset);
  }

  final TransactionRepository _transactionRepository;

  // * Fetch initial transactions
  Future<void> _onTransactionFetched(
    TransactionFetched event,
    Emitter<TransactionState> emit,
  ) async {
    emit(
      state.copyWith(
        status: TransactionStatus.loading,
        currentAssetFilter: () => event.assetUlid,
        currentCategoryFilter: () => event.categoryUlid,
        currentStartDateFilter: () => event.startDate,
        currentEndDateFilter: () => event.endDate,
      ),
    );

    final result = await _transactionRepository
        .getTransactions(
          GetTransactionsParams(
            assetUlid: event.assetUlid,
            categoryUlid: event.categoryUlid,
            startDate: event.startDate,
            endDate: event.endDate,
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

  // * Load more transactions (pagination)
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

  // * Refresh transactions (reset & fetch)
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
}
