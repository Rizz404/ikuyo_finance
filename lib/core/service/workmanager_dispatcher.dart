import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/core/extensions/logger_extension.dart';
import 'package:ikuyo_finance/features/auto_transaction/repositories/auto_transaction_repository_impl.dart';
import 'package:ikuyo_finance/features/auto_transaction/services/auto_transaction_notification_service.dart';
import 'package:ikuyo_finance/features/auto_transaction/services/auto_transaction_scheduler.dart';
import 'package:ikuyo_finance/features/backup/services/auto_backup_service.dart';
import 'package:ikuyo_finance/features/transaction/repositories/transaction_repository_impl.dart';

const autoTransactionTaskName = 'autoTransactionTask';
const autoTransactionTaskUniqueName = 'ikuyo_auto_transaction';

/// * Entry point Workmanager — HARUS top-level function & @pragma
/// * Semua dependensi diinisialisasi ulang di isolate ini, tidak dari getIt
@pragma('vm:entry-point')
void workmanagerCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      initLogger();

      talker.info('[WORKER][SERVICE] Workmanager: mulai task $task');

      // * Handle auto backup task
      if (task == autoBackupTaskName) {
        final success = await AutoBackupService.runBackup();
        talker.info(
          '[WORKER][SERVICE] AutoBackup: ${success ? 'berhasil' : 'gagal'}',
        );
        return success;
      }

      if (task != autoTransactionTaskName) return Future.value(true);

      talker.info('[AUTO_TX_WORKER][SERVICE] Workmanager: mulai task $task');

      // * Fresh init ObjectBox — getIt tidak tersedia di isolate ini
      final storage = ObjectBoxStorage();
      await storage.init();

      final notifService = AutoTransactionNotificationService();
      await notifService.initializeForBackground();

      final scheduler = AutoTransactionScheduler(
        repo: AutoTransactionRepositoryImpl(storage),
        transactionRepo: TransactionRepositoryImpl(storage),
        notifService: notifService,
      );

      await scheduler.runPendingExecutions();

      storage.close();
      talker.info('[AUTO_TX_WORKER][SERVICE] Workmanager: task selesai');
      return Future.value(true);
    } catch (e, s) {
      talker.error('[WORKER] Workmanager: task gagal', e, s);
      return Future.value(false);
    }
  });
}
