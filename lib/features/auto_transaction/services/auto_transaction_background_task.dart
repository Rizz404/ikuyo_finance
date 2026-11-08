import 'package:flutter/foundation.dart';
import 'package:ikuyo_finance/core/extensions/logger_extension.dart';
import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/features/auto_transaction/repositories/auto_transaction_repository_impl.dart';
import 'package:ikuyo_finance/features/auto_transaction/services/auto_transaction_notification_service.dart';
import 'package:ikuyo_finance/features/auto_transaction/services/auto_transaction_scheduler.dart';
import 'package:ikuyo_finance/features/transaction/repositories/transaction_repository_impl.dart';
import 'package:workmanager/workmanager.dart';

const autoTransactionTaskName = 'autoTransactionTask';
const autoTransactionTaskUniqueName = 'ikuyo_auto_transaction';

/// * Eksekusi auto transaction di latar belakang via WorkManager (Android).
/// * Periodik 15 menit (minimum WorkManager), tidak eksak dan bisa tertunda
/// * oleh Doze. Duplikasi dengan run foreground dicegah oleh klaim tick.
class AutoTransactionBackgroundTask {
  const AutoTransactionBackgroundTask._();

  static Future<void> register() async {
    // ! iOS butuh konfigurasi BGTaskScheduler (lihat PLAT-3), hanya Android
    if (defaultTargetPlatform != TargetPlatform.android) return;
    await Workmanager().registerPeriodicTask(
      autoTransactionTaskUniqueName,
      autoTransactionTaskName,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
    talker.info('AutoTransactionBackgroundTask: task periodik terdaftar');
  }

  /// * Dipanggil dari isolate WorkManager — tanpa DI
  static Future<bool> run({
    String? storageDirectory,
    AutoTransactionNotificationService? notifService,
  }) async {
    ObjectBoxStorage? storage;
    try {
      storage = ObjectBoxStorage();
      await storage.init(directory: storageDirectory);

      final notif = notifService ?? AutoTransactionNotificationService();
      try {
        await notif.initializeForBackground();
      } catch (e, s) {
        talker.error('AutoTransaction background: notifikasi gagal init', e, s);
      }

      await AutoTransactionScheduler(
        repo: AutoTransactionRepositoryImpl(storage),
        transactionRepo: TransactionRepositoryImpl(storage),
        notifService: notif,
      ).runPendingExecutions();
      return true;
    } catch (e, s) {
      talker.error('AutoTransaction background exception', e, s);
      return false;
    } finally {
      try {
        storage?.close();
      } catch (_) {}
    }
  }
}
