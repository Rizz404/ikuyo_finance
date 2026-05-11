import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/core/extensions/logger_extension.dart';
import 'package:ikuyo_finance/features/auto_transaction/repositories/auto_transaction_repository_impl.dart';
import 'package:ikuyo_finance/features/auto_transaction/services/auto_transaction_alarm_service.dart';
import 'package:ikuyo_finance/features/auto_transaction/services/auto_transaction_notification_service.dart';
import 'package:ikuyo_finance/features/auto_transaction/services/auto_transaction_scheduler.dart';
import 'package:ikuyo_finance/features/backup/services/auto_backup_service.dart';
import 'package:ikuyo_finance/features/transaction/repositories/transaction_repository_impl.dart';

const autoTransactionTaskName = 'autoTransactionTask';
const autoTransactionTaskUniqueName = 'ikuyo_auto_transaction';

/// Entry point for WorkManager — MUST be a top-level function with @pragma.
///
/// All dependencies are initialised fresh in this isolate; getIt is not
/// available here. The Flutter engine is spun up by the workmanager plugin's
/// BackgroundWorker before this function is called.
///
/// Task names handled:
///   [autoBackupTaskName]      — periodic auto-backup
///   [autoTransactionTaskName] — auto transaction execution
///                               • Triggered by periodic WorkManager task
///                               • OR by android_alarm_manager_plus exact alarm
///                                 via [_autoTransactionAlarmCallback] in
///                                 auto_transaction_alarm_service.dart
///
/// When triggered by an exact alarm, [inputData] contains:
///   {'groupId': int} — the ObjectBox id of the group that fired.
///   The scheduler still runs [runPendingExecutions] which processes all
///   pending groups (including the triggered one). The groupId is used only
///   for logging and task-name deduplication.
@pragma('vm:entry-point')
void workmanagerCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      initLogger();

      final groupId = inputData?['groupId'] as int?;
      talker.info(
        '[WORKER][SERVICE] Workmanager: mulai task "$task"'
        '${groupId != null ? ' (groupId=$groupId)' : ''}',
      );

      // ── Auto backup ──────────────────────────────────────────────────────
      if (task == autoBackupTaskName) {
        final success = await AutoBackupService.runBackup();
        talker.info(
          '[WORKER][SERVICE] AutoBackup: ${success ? 'berhasil' : 'gagal'}',
        );
        return success;
      }

      // ── Auto transaction (alarm-triggered OR periodic WorkManager) ───────
      if (task == autoTransactionTaskName) {
        return await _runAutoTransactionScheduler(groupId: groupId);
      }

      talker.warning('[WORKER] Workmanager: task tidak dikenal "$task", skip');
      return true;
    } catch (e, s) {
      talker.error('[WORKER] Workmanager: task gagal', e, s);
      return false;
    }
  });
}

/// Runs [AutoTransactionScheduler.runPendingExecutions].
///
/// [groupId] is the ObjectBox int id of the group that triggered the alarm,
/// or null when invoked by the periodic WorkManager task. In both cases the
/// scheduler processes ALL pending groups — the groupId is used only for
/// logging. This is correct behaviour: any overdue groups benefit from the
/// same run, and the alarm fires precisely for the group that is due.
Future<bool> _runAutoTransactionScheduler({int? groupId}) async {
  talker.info(
    '[AUTO_TX_WORKER][SERVICE] Workmanager: mulai auto transaction scheduler'
    '${groupId != null ? ' untuk groupId=$groupId' : ' (periodic)'}',
  );

  // Fresh ObjectBox — getIt is not available in a WorkManager isolate.
  final storage = ObjectBoxStorage();
  await storage.init();

  try {
    final notifService = AutoTransactionNotificationService();
    await notifService.initializeForBackground();

    // Always pass alarmService so the scheduler re-arms the next alarm for
    // each processed group. Without this, alarm-triggered executions would
    // not schedule the subsequent alarm, breaking the chain.
    final alarmService = AutoTransactionAlarmService();
    await alarmService.initializeForBackground();

    final repo = AutoTransactionRepositoryImpl(storage);

    final scheduler = AutoTransactionScheduler(
      repo: repo,
      transactionRepo: TransactionRepositoryImpl(storage),
      notifService: notifService,
      alarmService: alarmService,
    );

    await scheduler.runPendingExecutions();

    talker.info('[AUTO_TX_WORKER][SERVICE] Workmanager: task selesai');
    return true;
  } finally {
    storage.close();
  }
}
