import 'dart:io';

import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';
import 'package:ikuyo_finance/features/backup/models/backup_data.dart';
import 'package:ikuyo_finance/features/backup/models/backup_schedule_settings.dart';
import 'package:ikuyo_finance/features/backup/repositories/backup_repository_impl.dart';
import 'package:ikuyo_finance/features/backup/services/auto_backup_notification_service.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

const autoBackupTaskName = 'autoBackupTask';
const autoBackupTaskUniqueName = 'ikuyo_auto_backup';

class AutoBackupService {
  final SharedPreferences _prefs;

  const AutoBackupService(this._prefs);

  // ─── Settings ─────────────────────────────────────────────────────────────

  BackupScheduleSettings loadSettings() {
    final raw = _prefs.getString(_settingsKey);
    if (raw == null) return BackupScheduleSettings.defaultSettings;
    try {
      return BackupScheduleSettings.fromJsonString(raw);
    } catch (_) {
      return BackupScheduleSettings.defaultSettings;
    }
  }

  Future<void> saveSettings(BackupScheduleSettings settings) async {
    await _prefs.setString(_settingsKey, settings.toJsonString());
    logService(
      'AutoBackupService: settings disimpan — ${settings.toJsonString()}',
    );
  }

  // ─── Scheduling ───────────────────────────────────────────────────────────

  Future<void> schedule(BackupScheduleSettings settings) async {
    if (!settings.isEnabled) {
      await cancel();
      return;
    }

    logService(
      'AutoBackupService: jadwal backup ${settings.formattedTime} '
      '(${settings.frequency.name}), '
      'initialDelay=${settings.initialDelay.inMinutes}m',
    );

    await Workmanager().registerPeriodicTask(
      autoBackupTaskUniqueName,
      autoBackupTaskName,
      frequency: settings.frequencyDuration,
      initialDelay: settings.initialDelay,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      constraints: Constraints(requiresStorageNotLow: true),
    );
  }

  Future<void> cancel() async {
    await Workmanager().cancelByUniqueName(autoBackupTaskUniqueName);
    logService('AutoBackupService: jadwal dibatalkan');
  }

  // ─── Background Execution (called from Workmanager isolate) ───────────────

  /// Runs inside the Workmanager isolate — no DI available.
  static Future<bool> runBackup() async {
    final notifService = AutoBackupNotificationService();
    try {
      await notifService.initializeForBackground();

      final storage = ObjectBoxStorage();
      await storage.init();

      final repo = BackupRepositoryImpl(storage);
      final result = await repo.exportData().run();

      storage.close();

      return await result.fold(
        (failure) async {
          talker.error('AutoBackup background gagal: ${failure.message}');
          await notifService.showFailure(failure.message);
          return false;
        },
        (success) async {
          final backupData = success.data!;
          final filePath = await _saveBackupToFile(backupData);
          talker.info('AutoBackup background selesai: $filePath');
          await notifService.showSuccess(filePath);
          return true;
        },
      );
    } catch (e, s) {
      talker.error('AutoBackup background exception', e, s);
      await notifService.showFailure(e.toString());
      return false;
    }
  }

  static Future<String> _saveBackupToFile(BackupData backupData) async {
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/ikuyo_backup_$timestamp.json');
    await file.writeAsString(backupData.toJsonString());
    return file.path;
  }

  // ─── Private ──────────────────────────────────────────────────────────────

  static const _settingsKey = 'auto_backup_settings';
}
