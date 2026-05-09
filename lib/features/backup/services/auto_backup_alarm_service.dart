import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ikuyo_finance/core/extensions/logger_extension.dart';
import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/features/backup/models/backup_data.dart';
import 'package:ikuyo_finance/features/backup/models/backup_schedule_settings.dart';
import 'package:ikuyo_finance/features/backup/repositories/backup_repository_impl.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

/// Fired when the exact backup alarm triggers. Runs backup silently (no
/// notification) then re-arms the next alarm based on saved settings.
@pragma('vm:entry-point')
void onAutoBackupAlarmBackground(NotificationResponse details) async {
  WidgetsFlutterBinding.ensureInitialized();
  initLogger();
  talker.info('[BACKUP_ALARM] Auto backup alarm fired');

  try {
    final storage = ObjectBoxStorage();
    await storage.init();

    final repo = BackupRepositoryImpl(storage);
    final result = await repo.exportData().run();

    storage.close();

    await result.fold(
      (failure) async {
        talker.error('[BACKUP_ALARM] Export gagal: ${failure.message}');
      },
      (success) async {
        final filePath = await _saveBackupFile(success.data!);
        talker.info('[BACKUP_ALARM] Backup selesai: $filePath');
      },
    );

    // Re-arm next alarm based on saved settings
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw != null) {
      final settings = BackupScheduleSettings.fromJsonString(raw);
      if (settings.isEnabled) {
        final alarmService = AutoBackupAlarmService();
        await alarmService.initializeForBackground();
        await alarmService.scheduleFromSettings(settings);
      }
    }
  } catch (e, s) {
    talker.error('[BACKUP_ALARM] Alarm handler gagal', e, s);
  }
}

class AutoBackupAlarmService {
  static const _channelId = 'auto_backup_alarm';
  static const _channelName = 'Auto Backup Alarm';
  static const _notifId = 3000000001;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Full init — registers background handler. Call from main isolate.
  Future<void> initialize() async {
    const android = AndroidInitializationSettings('ic_launcher_foreground');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveBackgroundNotificationResponse: onAutoBackupAlarmBackground,
    );
    await _ensureChannel();
    logService('AutoBackupAlarmService diinisialisasi');
  }

  /// Lightweight init — no handler registration. Call from background isolate.
  Future<void> initializeForBackground() async {
    const android = AndroidInitializationSettings('ic_launcher_foreground');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );
    await _ensureChannel();
  }

  /// Schedules (or reschedules) the next backup exact alarm from [settings].
  Future<void> scheduleFromSettings(BackupScheduleSettings settings) async {
    if (!settings.isEnabled) {
      await cancel();
      return;
    }

    final next = _nextOccurrence(settings);
    final tzNext = tz.TZDateTime.from(next, tz.local);

    await _plugin.zonedSchedule(
      id: _notifId,
      title: null,
      body: null,
      scheduledDate: tzNext,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.min,
          priority: Priority.min,
          playSound: false,
          enableVibration: false,
          showWhen: false,
          visibility: NotificationVisibility.secret,
          styleInformation: DefaultStyleInformation(false, false),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'backup',
    );

    logService('AutoBackupAlarmService: alarm dijadwalkan pada $tzNext');
  }

  Future<void> cancel() async {
    await _plugin.cancel(id: _notifId);
    logService('AutoBackupAlarmService: alarm dibatalkan');
  }

  // ─── Private ──────────────────────────────────────────────────────────────

  /// Returns the next occurrence of [settings.hour]:[settings.minute] based
  /// on frequency, always strictly after [after] (defaults to now).
  DateTime _nextOccurrence(BackupScheduleSettings settings, {DateTime? after}) {
    final from = after ?? DateTime.now();
    final base = DateTime(
      from.year,
      from.month,
      from.day,
      settings.hour,
      settings.minute,
    );

    switch (settings.frequency) {
      case BackupFrequency.daily:
        return base.isAfter(from) ? base : base.add(const Duration(days: 1));
      case BackupFrequency.weekly:
        var next = base;
        while (!next.isAfter(from)) {
          next = next.add(const Duration(days: 7));
        }
        return next;
      case BackupFrequency.monthly:
        var next = base;
        while (!next.isAfter(from)) {
          next = next.add(const Duration(days: 30));
        }
        return next;
    }
  }

  Future<void> _ensureChannel() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return;

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Alarm internal untuk eksekusi auto backup tepat waktu',
        importance: Importance.min,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      ),
    );
  }
}

// ─── Shared helpers (used by background handler) ──────────────────────────────

const _settingsKey = 'auto_backup_settings';
const _exportDirKey = 'export_directory';

Future<String> _saveBackupFile(BackupData backupData) async {
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
  return file.path;
}
