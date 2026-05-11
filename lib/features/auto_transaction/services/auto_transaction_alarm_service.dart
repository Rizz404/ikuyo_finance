import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:ikuyo_finance/core/extensions/logger_extension.dart';
import 'package:ikuyo_finance/core/service/workmanager_dispatcher.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_group.dart';
import 'package:workmanager/workmanager.dart';

/// Top-level callback — MUST be a top-level function with @pragma.
///
/// Called by android_alarm_manager_plus in a separate Dart isolate when an
/// exact alarm fires. Because this isolate has no access to the DI container
/// or app state, it only enqueues a WorkManager one-off task and returns.
/// The actual transaction execution happens inside [workmanagerCallbackDispatcher].
///
/// [id] is the alarm ID which equals [AutoTransactionGroup.id] masked to a
/// non-negative int (see [AutoTransactionAlarmService._alarmIdFor]).
@pragma('vm:entry-point')
void _autoTransactionAlarmCallback(int id) async {
  await Workmanager().initialize(workmanagerCallbackDispatcher);
  await Workmanager().registerOneOffTask(
    '${autoTransactionTaskName}_$id',
    autoTransactionTaskName,
    inputData: {'groupId': id},
    constraints: Constraints(networkType: NetworkType.notRequired),
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );
}

/// Schedules and cancels exact AlarmManager alarms using
/// [android_alarm_manager_plus].
///
/// ## Architecture
///
/// Dart calls [scheduleForGroup] →
/// [AndroidAlarmManager.oneShotAt] (exact, wakeup, rescheduleOnReboot) →
/// Android fires alarm at the scheduled time even when app is killed →
/// [_autoTransactionAlarmCallback] (top-level, separate isolate) →
/// Workmanager one-off task with groupId in inputData →
/// [workmanagerCallbackDispatcher] executes the transaction.
///
/// rescheduleOnReboot=true means android_alarm_manager_plus automatically
/// restores the alarm after a device reboot — no custom BootReceiver needed.
///
/// ## Non-Android
///
/// All methods are no-ops on non-Android platforms (iOS background work uses
/// a different mechanism).
class AutoTransactionAlarmService {
  /// Maps an ObjectBox group [id] to a stable, non-negative alarm ID.
  ///
  /// ObjectBox IDs are positive ints so masking to 31 bits keeps them unique
  /// and within PendingIntent request-code range.
  static int _alarmIdFor(int groupId) => groupId & 0x7fffffff;

  /// Schedules (or reschedules) an exact alarm for [group].
  ///
  /// The alarm fires at [group.nextExecutedAt]. After execution the
  /// WorkManager task calls [scheduleForGroup] again to arm the next tick.
  ///
  /// Call this after creating, updating, or resuming a group, and after each
  /// background execution so the next tick is armed.
  Future<void> scheduleForGroup(AutoTransactionGroup group) async {
    final next = group.nextExecutedAt;
    if (next == null || !group.isActive || group.isCurrentlyPaused()) {
      await cancelForGroup(group);
      return;
    }

    final now = DateTime.now();
    if (!next.isAfter(now)) {
      // Already overdue — the scheduler's catch-up logic handles this on the
      // next WorkManager run or foreground resume. No alarm needed.
      logInfo(
        'AutoTransactionAlarmService: grup ${group.ulid} overdue, skip alarm',
      );
      return;
    }

    final alarmId = _alarmIdFor(group.id);

    try {
      await AndroidAlarmManager.oneShotAt(
        next,
        alarmId,
        _autoTransactionAlarmCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
        alarmClock: false,
        allowWhileIdle: true,
        params: {'groupId': group.id},
      );
      logService(
        'AutoTransactionAlarmService: alarm dijadwalkan untuk ${group.ulid} '
        'pada $next (alarmId=$alarmId)',
      );
    } catch (e, s) {
      logError(
        'AutoTransactionAlarmService: gagal menjadwalkan alarm untuk '
        '${group.ulid}',
        e,
        s,
      );
    }
  }

  /// Cancels any pending alarm for [group].
  Future<void> cancelForGroup(AutoTransactionGroup group) async {
    await cancelById(group.id);
  }

  /// Cancels alarm by ObjectBox int [groupId] — use when the group object
  /// is no longer available.
  Future<void> cancelById(int groupId) async {
    final alarmId = _alarmIdFor(groupId);
    try {
      await AndroidAlarmManager.cancel(alarmId);
      logInfo(
        'AutoTransactionAlarmService: alarm dibatalkan untuk id=$groupId',
      );
    } catch (e, s) {
      logError(
        'AutoTransactionAlarmService: gagal membatalkan alarm id=$groupId',
        e,
        s,
      );
    }
  }

  /// Schedules alarms for all [groups]. Call on app startup to restore alarms
  /// after reboot or first install.
  Future<void> scheduleAlarmsForAllGroups(
    List<AutoTransactionGroup> groups,
  ) async {
    for (final group in groups) {
      await scheduleForGroup(group);
    }
    logService(
      'AutoTransactionAlarmService: alarm dijadwalkan untuk '
      '${groups.length} grup',
    );
  }

  /// Cancels alarms for all [groups]. Only call on a full data reset.
  Future<void> cancelAll(List<AutoTransactionGroup> groups) async {
    for (final group in groups) {
      await cancelForGroup(group);
    }
    logService('AutoTransactionAlarmService: semua alarm dibatalkan');
  }

  /// Returns true if exact alarms can be scheduled on this device.
  /// android_alarm_manager_plus handles permission internally; always true
  /// on Android < 12 and non-Android platforms.
  Future<bool> canScheduleExactAlarms() async => true;

  /// Initializes AndroidAlarmManager. Must be called before any scheduling.
  /// Called from [setupAutoTransactionServices] in commons.dart.
  Future<void> initialize() async {
    await AndroidAlarmManager.initialize();
    logService('AutoTransactionAlarmService: AndroidAlarmManager initialized');
  }

  /// No-op — kept for API compatibility. Called from WorkManager isolate;
  /// AndroidAlarmManager.initialize() is not needed in a background isolate
  /// because the alarm callback only enqueues a WorkManager task.
  Future<void> initializeForBackground() async {}

  /// No-op — kept for API compatibility.
  /// SCHEDULE_EXACT_ALARM / USE_EXACT_ALARM are declared in AndroidManifest.
  Future<void> requestExactAlarmPermission() async {}
}
