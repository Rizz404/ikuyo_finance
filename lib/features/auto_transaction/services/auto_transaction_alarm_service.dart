import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ikuyo_finance/core/extensions/logger_extension.dart';
import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_group.dart';
import 'package:ikuyo_finance/features/auto_transaction/repositories/auto_transaction_repository_impl.dart';
import 'package:ikuyo_finance/features/auto_transaction/services/auto_transaction_notification_service.dart';
import 'package:ikuyo_finance/features/auto_transaction/services/auto_transaction_scheduler.dart';
import 'package:ikuyo_finance/features/transaction/repositories/transaction_repository_impl.dart';
import 'package:timezone/timezone.dart' as tz;

/// Fired by Android when an exact alarm notification fires while the app is
/// in the background or killed. Runs the scheduler in a fresh isolate context,
/// re-arming the next alarm automatically through the scheduler's post-exec hook.
@pragma('vm:entry-point')
void onAutoTransactionAlarmBackground(NotificationResponse details) async {
  WidgetsFlutterBinding.ensureInitialized();
  initLogger();
  talker.info('[ALARM] Auto transaction alarm: payload=${details.payload}');

  try {
    final storage = ObjectBoxStorage();
    await storage.init();

    final notifService = AutoTransactionNotificationService();
    await notifService.initializeForBackground();

    final alarmService = AutoTransactionAlarmService();
    await alarmService.initializeForBackground();

    final scheduler = AutoTransactionScheduler(
      repo: AutoTransactionRepositoryImpl(storage),
      transactionRepo: TransactionRepositoryImpl(storage),
      notifService: notifService,
      alarmService: alarmService,
    );

    await scheduler.runPendingExecutions();
    storage.close();
    talker.info('[ALARM] Auto transaction alarm selesai');
  } catch (e, s) {
    talker.error('[ALARM] Auto transaction alarm gagal', e, s);
  }
}

class AutoTransactionAlarmService {
  static const _channelId = 'auto_tx_alarm';
  static const _channelName = 'Auto Transaction Alarm';

  // Alarm notification IDs sit above the result-notification range used by
  // AutoTransactionNotificationService (group.id % 2_000_000_000).
  // We use group.id % 100_000_000 offset by 2_000_000_000.
  static const int _alarmIdOffset = 2000000000;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Full init — registers background handler. Call from main isolate.
  Future<void> initialize() async {
    const android = AndroidInitializationSettings('ic_launcher_foreground');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveBackgroundNotificationResponse:
          onAutoTransactionAlarmBackground,
    );
    await _ensureChannel();
    logService('AutoTransactionAlarmService diinisialisasi');
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

  /// Schedules (or reschedules) an exact alarm for [group].
  ///
  /// Call this after creating or updating a group and after each execution
  /// so the next tick is armed.
  Future<void> scheduleForGroup(AutoTransactionGroup group) async {
    final next = group.nextExecutedAt;
    if (next == null || !group.isActive || group.isCurrentlyPaused()) {
      await cancelForGroup(group);
      return;
    }

    final now = DateTime.now();
    if (!next.isAfter(now)) {
      // Already overdue — foreground catch-up or WorkManager will handle it.
      logInfo(
        'AutoTransactionAlarmService: grup ${group.ulid} overdue, skip alarm',
      );
      return;
    }

    final tzNext = tz.TZDateTime.from(next, tz.local);
    final notifId = _alarmIdOffset + (group.id % 100000000);

    await _plugin.zonedSchedule(
      id: notifId,
      title: null, // silent — no visible notification shown to user
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
      payload: group.ulid,
    );

    logService(
      'AutoTransactionAlarmService: alarm dijadwalkan untuk ${group.ulid} '
      'pada $tzNext (notifId=$notifId)',
    );
  }

  /// Cancels any pending alarm for [group].
  Future<void> cancelForGroup(AutoTransactionGroup group) async {
    final notifId = _alarmIdOffset + (group.id % 100000000);
    await _plugin.cancel(id: notifId);
    logInfo(
      'AutoTransactionAlarmService: alarm dibatalkan untuk ${group.ulid}',
    );
  }

  /// Cancels alarm by ObjectBox int [groupId] — use when group object is gone.
  Future<void> cancelById(int groupId) async {
    final notifId = _alarmIdOffset + (groupId % 100000000);
    await _plugin.cancel(id: notifId);
    logInfo('AutoTransactionAlarmService: alarm dibatalkan untuk id=$groupId');
  }

  /// Schedules alarms for all [groups]. Call on app startup to restore alarms.
  Future<void> scheduleAlarmsForAllGroups(
    List<AutoTransactionGroup> groups,
  ) async {
    for (final group in groups) {
      await scheduleForGroup(group);
    }
    logService(
      'AutoTransactionAlarmService: alarm dijadwalkan untuk ${groups.length} grup',
    );
  }

  /// Cancels all pending alarms. Only call on a full reset (e.g. data wipe).
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    logService('AutoTransactionAlarmService: semua alarm dibatalkan');
  }

  // ─── Private ─────────────────────────────────────────────────────────────

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
        description:
            'Alarm internal untuk eksekusi auto transaksi tepat waktu',
        importance: Importance.min,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      ),
    );
  }
}
