import 'package:fpdart/fpdart.dart';
import 'package:ikuyo_finance/core/wrapper/failure.dart';
import 'package:ikuyo_finance/core/wrapper/success.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/features/transaction/models/create_transaction_params.dart';
import 'package:ikuyo_finance/features/transaction/models/get_transactions_params.dart';
import 'package:ikuyo_finance/features/transaction/models/update_transaction_params.dart';

abstract class TransactionRepository {
  TaskEither<Failure, Success<Transaction>> createTransaction(
    CreateTransactionParams params,
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
}
