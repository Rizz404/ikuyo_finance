import 'package:fpdart/fpdart.dart';
import 'package:ikuyo_finance/core/wrapper/failure.dart';
import 'package:ikuyo_finance/core/wrapper/success.dart';
import 'package:ikuyo_finance/features/statistic/models/category_summary.dart';
import 'package:ikuyo_finance/features/statistic/models/get_statistic_params.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/features/transaction/models/create_transaction_params.dart';
import 'package:ikuyo_finance/features/transaction/models/get_transactions_params.dart';
import 'package:ikuyo_finance/features/transaction/models/update_transaction_params.dart';

/// * Result model untuk bulk create operation
class BulkCreateResult {
  final List<Transaction> successfulTransactions;
  final List<BulkCreateFailure> failedTransactions;

  const BulkCreateResult({
    required this.successfulTransactions,
    required this.failedTransactions,
  });

  bool get hasFailures => failedTransactions.isNotEmpty;
  bool get allSucceeded => failedTransactions.isEmpty;
  int get totalAttempted =>
      successfulTransactions.length + failedTransactions.length;
}

class BulkCreateFailure {
  final CreateTransactionParams params;
  final String errorMessage;
  final int index;

  const BulkCreateFailure({
    required this.params,
    required this.errorMessage,
    required this.index,
  });
}

abstract class TransactionRepository {
  TaskEither<Failure, Success<Transaction>> createTransaction(
    CreateTransactionParams params,
  );

  /// * Create multiple transactions atomically
  /// * Returns detailed result with success/failure info for each transaction
  TaskEither<Failure, Success<BulkCreateResult>> createManyTransactions(
    List<CreateTransactionParams> paramsList,
  );

  TaskEither<Failure, SuccessCursor<Transaction>> getTransactions(
    GetTransactionsParams params,
  );
  TaskEither<Failure, Success<Transaction>> getTransactionById({
    required String ulid,
  });
  TaskEither<Failure, Success<Transaction>> updateTransaction(
    UpdateTransactionParams params,
  );
  TaskEither<Failure, ActionSuccess> deleteTransaction({required String ulid});

  /// * Get transactions grouped by category for statistics
  TaskEither<Failure, Success<StatisticSummary>> getStatisticSummary(
    GetStatisticParams params,
  );
}
