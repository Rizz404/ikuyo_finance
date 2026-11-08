import 'dart:io';

import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/core/extensions/logger_extension.dart';
import 'package:ikuyo_finance/features/backup/models/backup_data.dart';
import 'package:ikuyo_finance/features/backup/models/backup_schedule_settings.dart';
import 'package:ikuyo_finance/features/backup/repositories/backup_repository_impl.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

const autoBackupTaskName = 'autoBackupTask';
const autoBackupTaskUniqueName = 'ikuyo_auto_backup';

/// Auto backup hanya memakai WorkManager (periodik, tidak eksak; bisa
/// tertunda oleh Doze). Jalur exact alarm dihapus karena tidak pernah
/// menjalankan backup dan membuat startup crash (A06/A07/BKSEC-2/BKSEC-3).
class AutoBackupService {
  final SharedPreferences _prefs;

  const AutoBackupService(this._prefs);

  /// Jumlah file auto backup terbaru yang disimpan; sisanya dihapus.
  static const maxAutoBackupFiles = 10;

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

  Future<void> schedule(
    BackupScheduleSettings settings, {
    bool keepExisting = false,
  }) async {
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
      existingWorkPolicy: keepExisting
          ? ExistingPeriodicWorkPolicy.keep
          : ExistingPeriodicWorkPolicy.replace,
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
    ObjectBoxStorage? storage;
    try {
      storage = ObjectBoxStorage();
      await storage.init();

      final repo = BackupRepositoryImpl(storage);
      final result = await repo.exportData().run();

      return await result.fold(
        (failure) async {
          talker.error('AutoBackup background gagal: ${failure.message}');
          return false;
        },
        (success) async {
          final filePath = await _saveBackupToFile(success.data!);
          talker.info('AutoBackup background selesai: $filePath');
          return true;
        },
      );
    } catch (e, s) {
      talker.error('AutoBackup background exception', e, s);
      return false;
    } finally {
      try {
        storage?.close();
      } catch (_) {}
    }
  }

  /// Hapus file auto backup lama, sisakan [keep] file terbaru.
  static Future<void> pruneOldBackups(
    Directory dir, {
    int keep = maxAutoBackupFiles,
  }) async {
    if (!await dir.exists()) return;
    final files = await dir
        .list()
        .where(
          (e) =>
              e is File &&
              RegExp(r'ikuyo_backup_\d{8}_\d{6}\.json$').hasMatch(e.path),
        )
        .cast<File>()
        .toList();
    if (files.length <= keep) return;
    // * Nama file memuat timestamp yyyyMMdd_HHmmss, urut leksikal = urut waktu
    files.sort((a, b) => b.path.compareTo(a.path));
    for (final f in files.skip(keep)) {
      try {
        await f.delete();
      } catch (e) {
        talker.warning('AutoBackup: gagal hapus backup lama ${f.path}: $e');
      }
    }
  }

  static Future<String> _saveBackupToFile(BackupData backupData) async {
    final prefs = await SharedPreferences.getInstance();
    final baseDir = prefs.getString(_exportDirKey);

    final Directory targetDir;
    if (baseDir != null && baseDir.isNotEmpty) {
      targetDir = Directory('$baseDir/Auto Backup');
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      targetDir = Directory('${appDir.path}/Auto Backup');
    }

    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${targetDir.path}/ikuyo_backup_$timestamp.json');
    await file.writeAsString(backupData.toJsonString());
    await pruneOldBackups(targetDir);
    return file.path;
  }

  // ─── Private ──────────────────────────────────────────────────────────────

  static const _settingsKey = 'auto_backup_settings';
  static const _exportDirKey = 'export_directory';
}
