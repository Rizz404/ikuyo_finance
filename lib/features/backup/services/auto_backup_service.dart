import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/core/extensions/logger_extension.dart';
import 'package:ikuyo_finance/features/backup/models/backup_data.dart';
import 'package:ikuyo_finance/features/backup/models/backup_schedule_settings.dart';
import 'package:ikuyo_finance/features/backup/repositories/backup_repository_impl.dart';
import 'package:ikuyo_finance/features/backup/services/auto_backup_key_store.dart';
import 'package:ikuyo_finance/features/backup/services/auto_backup_notification_service.dart';
import 'package:ikuyo_finance/features/backup/services/backup_crypto.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

const autoBackupTaskName = 'autoBackupTask';
const autoBackupTaskUniqueName = 'ikuyo_auto_backup';

/// Hasil satu eksekusi auto backup di latar belakang.
enum AutoBackupOutcome {
  written,

  /// Belum ada kunci (mis. upgrade dari versi plaintext): jeda, tidak menulis
  keyMissing,

  /// Kunci tidak terbaca/rusak: gagal tertutup, tidak menulis
  keyUnreadable,
  tooLarge,
  failed,
}

/// Auto backup hanya memakai WorkManager (periodik, tidak eksak; bisa
/// tertunda oleh Doze). Jalur exact alarm dihapus karena tidak pernah
/// menjalankan backup dan membuat startup crash (A06/A07/BKSEC-2/BKSEC-3).
/// * F10: setiap file auto backup adalah envelope IKYB v1 terenkripsi yang
///   disegel dengan kunci tersimpan; tidak pernah ada fallback plaintext.
class AutoBackupService {
  final SharedPreferences _prefs;
  final AutoBackupKeyStore _keyStore;

  const AutoBackupService(
    this._prefs, [
    this._keyStore = const AutoBackupKeyStore(),
  ]);

  /// Jumlah file auto backup terenkripsi terbaru yang disimpan; sisanya
  /// dihapus. File .json lama tidak pernah dihitung maupun dihapus.
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

  // ─── Encryption key ───────────────────────────────────────────────────────

  Future<AutoBackupKeyState> keyState() => _keyStore.state();

  /// Menurunkan kunci baru (salt acak baru) dari [passphrase] dan
  /// menyimpannya. Passphrase sendiri tidak pernah disimpan.
  /// * Gagal simpan: kunci dibersihkan, [AutoBackupKeyException] diteruskan
  Future<void> setupKey(String passphrase) async {
    final material = await BackupCrypto.deriveKeyMaterial(passphrase);
    try {
      await _keyStore.save(material);
    } finally {
      material.destroy();
    }
    logService('AutoBackupService: kunci auto backup disiapkan');
  }

  Future<void> clearKey() async {
    await _keyStore.clear();
    logService('AutoBackupService: kunci auto backup dihapus');
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
  /// * Kunci belum di-setup = jeda (true, tanpa retry WorkManager); kunci
  ///   tidak terbaca atau gagal tulis = false. Keduanya tanpa file.
  static Future<bool> runBackup() async {
    final outcome = await runEncryptedBackup();
    return outcome == AutoBackupOutcome.written ||
        outcome == AutoBackupOutcome.keyMissing;
  }

  /// Inti auto backup; semua dependensi platform dapat diganti di test.
  @visibleForTesting
  static Future<AutoBackupOutcome> runEncryptedBackup({
    AutoBackupKeyStore keyStore = const AutoBackupKeyStore(),
    Future<BackupData?> Function()? exportData,
    Future<Directory> Function()? resolveTargetDir,
    Future<void> Function(AutoBackupOutcome outcome)? notifyFailure,
    DateTime? now,
  }) async {
    final notify = notifyFailure ?? _notifyFailure;

    // * Kunci dicek sebelum DB dibuka: tanpa kunci tidak ada yang diekspor
    final BackupKeyMaterial? key;
    try {
      key = await keyStore.read();
    } on AutoBackupKeyException {
      talker.error('AutoBackup: kunci tidak terbaca; backup tidak ditulis');
      await _safeNotify(notify, AutoBackupOutcome.keyUnreadable);
      return AutoBackupOutcome.keyUnreadable;
    }
    if (key == null) {
      talker.warning(
        'AutoBackup: passphrase belum diatur; backup dijeda, tidak ditulis',
      );
      await _safeNotify(notify, AutoBackupOutcome.keyMissing);
      return AutoBackupOutcome.keyMissing;
    }

    try {
      final data = await (exportData ?? _exportFromStore)();
      if (data == null) {
        await _safeNotify(notify, AutoBackupOutcome.failed);
        return AutoBackupOutcome.failed;
      }
      final dir = await (resolveTargetDir ?? _resolveTargetDir)();
      final path = await writeBackupFile(dir, data, key, now: now);
      if (path == null) {
        await _safeNotify(notify, AutoBackupOutcome.tooLarge);
        return AutoBackupOutcome.tooLarge;
      }
      talker.info('AutoBackup background selesai: $path');
      return AutoBackupOutcome.written;
    } catch (e, s) {
      talker.error('AutoBackup background exception', e, s);
      await _safeNotify(notify, AutoBackupOutcome.failed);
      return AutoBackupOutcome.failed;
    } finally {
      key.destroy();
    }
  }

  static Future<BackupData?> _exportFromStore() async {
    ObjectBoxStorage? storage;
    try {
      storage = ObjectBoxStorage();
      await storage.init();
      final result = await BackupRepositoryImpl(storage).exportData().run();
      return result.fold((failure) {
        talker.error('AutoBackup background gagal: ${failure.message}');
        return null;
      }, (success) => success.data);
    } finally {
      try {
        storage?.close();
      } catch (_) {}
    }
  }

  static Future<Directory> _resolveTargetDir() async {
    final prefs = await SharedPreferences.getInstance();
    final baseDir = prefs.getString(_exportDirKey);
    if (baseDir != null && baseDir.isNotEmpty) {
      return Directory('$baseDir/Auto Backup');
    }
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/Auto Backup');
  }

  static Future<void> _safeNotify(
    Future<void> Function(AutoBackupOutcome) notify,
    AutoBackupOutcome outcome,
  ) async {
    try {
      await notify(outcome);
    } catch (e) {
      talker.warning('AutoBackup: notifikasi gagal: ${e.runtimeType}');
    }
  }

  static Future<void> _notifyFailure(AutoBackupOutcome outcome) async {
    final message = switch (outcome) {
      AutoBackupOutcome.keyMissing =>
        'Atur passphrase backup di aplikasi untuk melanjutkan backup '
            'otomatis terenkripsi. Tidak ada file yang ditulis.',
      AutoBackupOutcome.keyUnreadable =>
        'Kunci backup tidak dapat dibaca. Buka aplikasi dan atur ulang '
            'passphrase backup. Tidak ada file yang ditulis.',
      AutoBackupOutcome.tooLarge =>
        'Data melebihi batas ukuran backup. Tidak ada file yang ditulis.',
      _ => 'Backup otomatis gagal. Backup lama tetap disimpan.',
    };
    final service = AutoBackupNotificationService();
    await service.initializeForBackground();
    await service.showFailure(message);
  }

  /// Hapus file auto backup terenkripsi lama, sisakan [keep] file terbaru.
  /// * Hanya `ikuyo_backup_<ts>.ikuyo`; file `.json` lama (plaintext dari
  ///   versi sebelumnya) tidak pernah dihapus atau diubah otomatis
  static Future<void> pruneOldBackups(
    Directory dir, {
    int keep = maxAutoBackupFiles,
  }) async {
    if (!await dir.exists()) return;
    final files = await dir
        .list()
        .where((e) => e is File && _encryptedName.hasMatch(e.path))
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

  static final _encryptedName = RegExp(
    r'ikuyo_backup_\d{8}_\d{6}\.' + BackupCrypto.fileExtension + r'$',
  );

  /// Segel lalu tulis satu file auto backup ke [targetDir], lalu rotasi.
  /// * NEW-1: batas [BackupCrypto.maxBackupBytes] dicek pada ukuran tersegel
  ///   sebelum direktori/file disentuh; di atas batas tidak ada yang ditulis
  ///   maupun dirotasi, return null.
  /// * Ditulis ke file sementara lalu di-rename agar tidak ada .ikuyo parsial
  @visibleForTesting
  static Future<String?> writeBackupFile(
    Directory targetDir,
    BackupData backupData,
    BackupKeyMaterial key, {
    DateTime? now,
  }) async {
    final Uint8List sealed;
    try {
      sealed = await BackupCrypto.encryptWithKey(backupData, key);
    } on BackupCryptoException catch (e) {
      if (e.error != BackupCryptoError.exportTooLarge) rethrow;
      talker.error(
        'AutoBackup: backup melebihi batas ${BackupCrypto.maxBackupBytes} '
        'byte setelah enkripsi; tidak ditulis, backup lama dipertahankan',
      );
      return null;
    }

    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final timestamp = DateFormat(
      'yyyyMMdd_HHmmss',
    ).format(now ?? DateTime.now());
    final name = 'ikuyo_backup_$timestamp.${BackupCrypto.fileExtension}';
    final file = File('${targetDir.path}/$name');
    final temp = File('${file.path}.tmp');
    try {
      await temp.writeAsBytes(sealed, flush: true);
      await temp.rename(file.path);
    } catch (_) {
      try {
        if (await temp.exists()) await temp.delete();
      } catch (_) {}
      rethrow;
    }
    await pruneOldBackups(targetDir);
    return file.path;
  }

  // ─── Private ──────────────────────────────────────────────────────────────

  static const _settingsKey = 'auto_backup_settings';
  static const _exportDirKey = 'export_directory';
}
