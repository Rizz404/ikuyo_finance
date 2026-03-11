import 'package:fpdart/fpdart.dart';
import 'package:ikuyo_finance/core/wrapper/failure.dart';
import 'package:ikuyo_finance/core/wrapper/success.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_group.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_item.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_log.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/create_auto_group_params.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/create_auto_item_params.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/update_auto_group_params.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/update_auto_item_params.dart';

abstract class AutoTransactionRepository {
  // * Group CRUD
  TaskEither<Failure, Success<AutoTransactionGroup>> createGroup(
    CreateAutoGroupParams params,
  );
  TaskEither<Failure, Success<AutoTransactionGroup>> updateGroup(
    UpdateAutoGroupParams params,
  );
  TaskEither<Failure, ActionSuccess> deleteGroup({required String ulid});
  TaskEither<Failure, Success<List<AutoTransactionGroup>>> getGroups();
  TaskEither<Failure, Success<AutoTransactionGroup>> getGroupByUlid({
    required String ulid,
  });

  // * Item CRUD
  TaskEither<Failure, Success<AutoTransactionItem>> createItem(
    CreateAutoItemParams params,
  );
  TaskEither<Failure, Success<AutoTransactionItem>> updateItem(
    UpdateAutoItemParams params,
  );
  TaskEither<Failure, ActionSuccess> deleteItem({required String ulid});
  TaskEither<Failure, Success<List<AutoTransactionItem>>> getItemsByGroup({
    required String groupUlid,
  });

  // * Reorder items dalam sebuah grup
  TaskEither<Failure, ActionSuccess> reorderItems({
    required String groupUlid,
    required List<String> orderedUlids,
  });

  // * Pause management
  TaskEither<Failure, ActionSuccess> pauseGroup({
    required String ulid,
    DateTime? pauseStartAt,
    DateTime? resumeAt,
  });
  TaskEither<Failure, ActionSuccess> resumeGroup({required String ulid});

  // * Toggle aktif/nonaktif grup
  TaskEither<Failure, ActionSuccess> toggleGroup({
    required String ulid,
    required bool isActive,
  });

  // * Scheduler operations
  /// * Query semua grup yang aktif dan nextExecutedAt ≤ now
  TaskEither<Failure, Success<List<AutoTransactionGroup>>> getPendingGroups();

  /// * Update grup setelah eksekusi (nextExecutedAt, lastExecutedAt, isActive)
  TaskEither<Failure, ActionSuccess> updateGroupAfterExecution({
    required String ulid,
    required DateTime nextExecutedAt,
    required DateTime lastExecutedAt,
    required bool isActive,
  });

  TaskEither<Failure, ActionSuccess> saveExecutionLog(AutoTransactionLog log);
  TaskEither<Failure, Success<List<AutoTransactionLog>>> getLogsByGroup({
    required String groupUlid,
  });
}
