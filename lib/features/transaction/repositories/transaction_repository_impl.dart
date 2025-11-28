import 'package:fpdart/fpdart.dart' hide Order;
import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';
import 'package:ikuyo_finance/core/wrapper/failure.dart';
import 'package:ikuyo_finance/core/wrapper/success.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/features/transaction/models/create_transaction_params.dart';
import 'package:ikuyo_finance/features/transaction/models/get_transactions_params.dart';
import 'package:ikuyo_finance/features/transaction/models/update_transaction_params.dart';
import 'package:ikuyo_finance/features/transaction/repositories/transaction_repository.dart';
import 'package:ikuyo_finance/features/wallet/models/wallet.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/objectbox.g.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final ObjectBoxStorage _storage;

  const TransactionRepositoryImpl(this._storage);

  Box<Transaction> get _box => _storage.box<Transaction>();
  Box<Wallet> get _walletBox => _storage.box<Wallet>();
  Box<Category> get _categoryBox => _storage.box<Category>();

  @override
  TaskEither<Failure, Success<Transaction>> createTransaction(
    CreateTransactionParams params,
  ) {
    return TaskEither.tryCatch(
      () async {
        logService('Create transaction', 'wallet: ${params.walletUlid}');

        // * Get wallet (required)
        final wallet = _walletBox
            .query(Wallet_.ulid.equals(params.walletUlid))
            .build()
            .findFirst();

        if (wallet == null) {
          throw Exception('Wallet not found');
        }

        final transaction = Transaction(
          amount: params.amount,
          transactionDate: params.transactionDate,
          description: params.description,
          imagePath: params.imagePath,
        );

        transaction.wallet.target = wallet;

        // * Set category jika ada
        if (params.categoryUlid != null) {
          final category = _categoryBox
              .query(Category_.ulid.equals(params.categoryUlid!))
              .build()
              .findFirst();

          if (category == null) {
            throw Exception('Category not found');
          }

          transaction.category.target = category;
        }

        _box.put(transaction);
        logInfo('Transaction created successfully');

        return Success(message: 'Transaction created', data: transaction);
      },
      (error, stackTrace) {
        logError('Create transaction failed', error, stackTrace);
        return Failure(
          message: error.toString().contains('not found')
              ? error.toString()
              : 'Failed to create transaction. Please try again.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, SuccessCursor<Transaction>> getTransactions(
    GetTransactionsParams params,
  ) {
    return TaskEither.tryCatch(
      () async {
        logService(
          'Get transactions',
          'cursor: ${params.cursor}, limit: ${params.limit}',
        );

        var query = _box.query();

        // * Filter by date range jika ada
        if (params.startDate != null && params.endDate != null) {
          query = _box.query(
            Transaction_.transactionDate.betweenDate(
              params.startDate!,
              params.endDate!,
            ),
          );
        } else if (params.startDate != null) {
          query = _box.query(
            Transaction_.transactionDate.greaterOrEqualDate(params.startDate!),
          );
        } else if (params.endDate != null) {
          query = _box.query(
            Transaction_.transactionDate.lessOrEqualDate(params.endDate!),
          );
        }

        // * Pagination dengan cursor (offset-based)
        final offset = params.cursor != null
            ? int.tryParse(params.cursor!) ?? 0
            : 0;
        query = query..order(Transaction_.createdAt, flags: Order.descending);

        final builtQuery = query.build();
        final allResults = builtQuery.find();
        builtQuery.close();

        // * Filter by wallet jika ada
        var filteredResults = allResults;
        if (params.walletUlid != null) {
          filteredResults = filteredResults
              .where((t) => t.wallet.target?.ulid == params.walletUlid)
              .toList();
        }

        // * Filter by category jika ada
        if (params.categoryUlid != null) {
          filteredResults = filteredResults
              .where((t) => t.category.target?.ulid == params.categoryUlid)
              .toList();
        }

        // * Manual offset & limit
        final startIndex = offset < filteredResults.length
            ? offset
            : filteredResults.length;
        final endIndex =
            (startIndex + params.limit + 1) < filteredResults.length
            ? startIndex + params.limit + 1
            : filteredResults.length;
        final results = filteredResults.sublist(startIndex, endIndex);

        final hasMore = results.length > params.limit;
        final transactions = hasMore
            ? results.sublist(0, params.limit)
            : results;

        final cursorInfo = CursorInfo(
          nextCursor: hasMore ? (offset + params.limit).toString() : '',
          hasNextPage: hasMore,
          perPage: params.limit,
        );

        logInfo('Transactions retrieved: ${transactions.length}');

        return SuccessCursor(
          message: 'Transactions retrieved',
          data: transactions,
          cursor: cursorInfo,
        );
      },
      (error, stackTrace) {
        logError('Get transactions failed', error, stackTrace);
        return Failure(
          message: 'Failed to retrieve transactions. Please try again.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, Success<Transaction>> getTransactionById({
    required String ulid,
  }) {
    return TaskEither.tryCatch(
      () async {
        logService('Get transaction by id', ulid);

        final transaction = _box
            .query(Transaction_.ulid.equals(ulid))
            .build()
            .findFirst();

        if (transaction == null) {
          throw Exception('Transaction not found');
        }

        logInfo('Transaction retrieved');
        return Success(message: 'Transaction retrieved', data: transaction);
      },
      (error, stackTrace) {
        logError('Get transaction by id failed', error, stackTrace);
        return Failure(
          message: error.toString().contains('not found')
              ? 'Transaction not found'
              : 'Failed to retrieve transaction. Please try again.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, Success<Transaction>> updateTransaction(
    UpdateTransactionParams params,
  ) {
    return TaskEither.tryCatch(
      () async {
        logService('Update transaction', params.ulid);

        final transaction = _box
            .query(Transaction_.ulid.equals(params.ulid))
            .build()
            .findFirst();

        if (transaction == null) {
          throw Exception('Transaction not found');
        }

        // * Update fields jika ada
        if (params.amount != null) transaction.amount = params.amount!;
        if (params.transactionDate != null) {
          transaction.transactionDate = params.transactionDate;
        }
        if (params.description != null) {
          transaction.description = params.description;
        }
        if (params.imagePath != null) transaction.imagePath = params.imagePath;

        // * Update wallet jika ada
        if (params.walletUlid != null) {
          final wallet = _walletBox
              .query(Wallet_.ulid.equals(params.walletUlid!))
              .build()
              .findFirst();

          if (wallet == null) {
            throw Exception('Wallet not found');
          }

          transaction.wallet.target = wallet;
        }

        // * Update category jika ada
        if (params.categoryUlid != null) {
          final category = _categoryBox
              .query(Category_.ulid.equals(params.categoryUlid!))
              .build()
              .findFirst();

          if (category == null) {
            throw Exception('Category not found');
          }

          transaction.category.target = category;
        }

        transaction.updatedAt = DateTime.now();
        _box.put(transaction);

        logInfo('Transaction updated successfully');
        return Success(message: 'Transaction updated', data: transaction);
      },
      (error, stackTrace) {
        logError('Update transaction failed', error, stackTrace);
        return Failure(
          message: error.toString().contains('not found')
              ? error.toString()
              : 'Failed to update transaction. Please try again.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, ActionSuccess> deleteTransaction({required String ulid}) {
    return TaskEither.tryCatch(
      () async {
        logService('Delete transaction', ulid);

        final transaction = _box
            .query(Transaction_.ulid.equals(ulid))
            .build()
            .findFirst();

        if (transaction == null) {
          throw Exception('Transaction not found');
        }

        _box.remove(transaction.id);
        logInfo('Transaction deleted successfully');

        return const ActionSuccess(message: 'Transaction deleted');
      },
      (error, stackTrace) {
        logError('Delete transaction failed', error, stackTrace);
        return Failure(
          message: error.toString().contains('not found')
              ? 'Transaction not found'
              : 'Failed to delete transaction. Please try again.',
        );
      },
    );
  }
}
