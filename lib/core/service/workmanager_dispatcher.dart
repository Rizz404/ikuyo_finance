import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import 'package:ikuyo_finance/core/extensions/logger_extension.dart';
import 'package:ikuyo_finance/features/auto_transaction/services/auto_transaction_background_task.dart';
import 'package:ikuyo_finance/features/auto_transaction/services/auto_transaction_notification_service.dart';
import 'package:ikuyo_finance/features/backup/services/auto_backup_service.dart';

@pragma('vm:entry-point')
void workmanagerCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      initLogger();
      return await handleBackgroundTask(task);
    } catch (e, s) {
      talker.error('[WORKER] Workmanager: task gagal', e, s);
      return false;
    }
  });
}

/// * Routing task WorkManager; parameter opsional untuk pengujian
Future<bool> handleBackgroundTask(
  String task, {
  String? storageDirectory,
  AutoTransactionNotificationService? autoTxNotifService,
}) async {
  talker.info('[WORKER][SERVICE] Workmanager: mulai task "$task"');

  if (task == autoBackupTaskName) {
    final success = await AutoBackupService.runBackup();
    talker.info(
      '[WORKER][SERVICE] AutoBackup: ${success ? 'berhasil' : 'gagal'}',
    );
    return success;
  }

  if (task == autoTransactionTaskName) {
    final success = await AutoTransactionBackgroundTask.run(
      storageDirectory: storageDirectory,
      notifService: autoTxNotifService,
    );
    talker.info(
      '[WORKER][SERVICE] AutoTransaction: ${success ? 'berhasil' : 'gagal'}',
    );
    return success;
  }

  talker.warning('[WORKER] Workmanager: task tidak dikenal "$task", skip');
  return true;
}
