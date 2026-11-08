import 'package:ikuyo_finance/core/extensions/logger_extension.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_schedule_calculator.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_group.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_item.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_log.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_log_status.dart';
import 'package:ikuyo_finance/features/auto_transaction/repositories/auto_transaction_repository.dart';
import 'package:ikuyo_finance/features/auto_transaction/services/auto_transaction_alarm_service.dart';
import 'package:ikuyo_finance/features/auto_transaction/services/auto_transaction_notification_service.dart';
import 'package:ikuyo_finance/features/transaction/models/create_transaction_params.dart';
import 'package:ikuyo_finance/features/transaction/repositories/transaction_repository.dart';

class AutoTransactionScheduler {
  final AutoTransactionRepository _repo;
  final TransactionRepository _transactionRepo;
  final AutoTransactionNotificationService _notifService;
  final AutoTransactionAlarmService? _alarmService;

  AutoTransactionScheduler({
    required AutoTransactionRepository repo,
    required TransactionRepository transactionRepo,
    required AutoTransactionNotificationService notifService,
    AutoTransactionAlarmService? alarmService,
  }) : _repo = repo,
       _transactionRepo = transactionRepo,
       _notifService = notifService,
       _alarmService = alarmService;

  // * Single-flight: pemanggilan yang tumpang tindih memakai Future yang sama
  Future<void>? _inFlight;

  // * Entry point utama — dipanggil dari Workmanager & foreground trigger
  Future<void> runPendingExecutions() {
    return _inFlight ??= _runPendingExecutions().whenComplete(
      () => _inFlight = null,
    );
  }

  Future<void> _runPendingExecutions() async {
    logService('AutoTransactionScheduler: mulai scan pending groups');

    final result = await _repo.getPendingGroups().run();
    final groups = result.match(
      (failure) {
        logError(
          'Gagal mengambil pending groups: ${failure.message}',
          null,
          null,
        );
        return <AutoTransactionGroup>[];
      },
      (success) => success.data ?? <AutoTransactionGroup>[],
    );
    logData('Pending groups ditemukan: ${groups.length}');

    for (final group in groups) {
      try {
        await _processGroup(group);
      } catch (e, st) {
        logError('Gagal memproses group ${group.ulid}', e, st);
      }
    }

    logService('AutoTransactionScheduler: selesai');
  }

  // * Ekspos untuk testing
  DateTime calculateNext(AutoTransactionGroup group, DateTime from) =>
      AutoScheduleCalculator.calculateNext(group, from);

  // ─── Private ──────────────────────────────────────────────────────────────

  // * Batas eksklusif endDate: seluruh hari endDate masih dieksekusi
  DateTime? _endExclusive(AutoTransactionGroup group) {
    final end = group.endDate;
    if (end == null) return null;
    return DateTime(end.year, end.month, end.day + 1);
  }

  bool _isPastEnd(DateTime scheduled, DateTime? endExclusive) =>
      endExclusive != null && !scheduled.isBefore(endExclusive);

  // * Klaim tick + pembukuan + log dalam satu write transaction. Return null
  // * jika klaim kalah atau commit gagal (semua perubahan di-rollback).
  Future<List<AutoTransactionLog>?> _commitTick(
    AutoTransactionGroup group,
    DateTime? expected,
    DateTime next,
    List<AutoTransactionLog> Function() book, {
    bool allowPaused = false,
  }) async {
    final result = await _repo
        .commitTick(
          ulid: group.ulid,
          expected: expected,
          next: next,
          allowPaused: allowPaused,
          book: (_) => book(),
        )
        .run();
    return result.match((failure) {
      logError(
        'Commit tick group ${group.ulid} gagal: ${failure.message}',
        null,
        null,
      );
      return null;
    }, (logs) => logs);
  }

  Future<void> _processGroup(AutoTransactionGroup group) async {
    final now = DateTime.now();
    final windowStart = now.subtract(const Duration(days: 7));
    final endExclusive = _endExclusive(group);

    logDomain('Processing group: ${group.ulid} (${group.name})');

    // * Auto-resume jika pauseEndAt sudah lewat (AUTO-9)
    if (group.isPaused) {
      final pauseEnd = group.pauseEndAt;
      if (pauseEnd != null && !pauseEnd.isAfter(now)) {
        await _repo.resumeGroup(ulid: group.ulid).run();
        group.isPaused = false;
        group.pauseStartAt = null;
        group.pauseEndAt = null;
        logInfo('Auto-resume group: ${group.ulid}');
      } else {
        // * Masih pause — lewati semua tick, lanjut nextExecutedAt
        await _skipAllPendingTicks(group, now, endExclusive);
        return;
      }
    }

    // * Item dibaca sekali per run; template diselesaikan di dalam transaksi
    final itemsResult = await _repo
        .getItemsByGroup(groupUlid: group.ulid)
        .run();
    final List<AutoTransactionItem>? items = itemsResult.match(
      (_) => null,
      (success) => success.data ?? <AutoTransactionItem>[],
    );

    final DateTime? initial = group.nextExecutedAt;
    DateTime? expected = initial;
    var scheduled = expected ?? now;
    final List<AutoTransactionLog> logs = [];
    int totalSuccess = 0;
    int totalFailure = 0;
    int totalSkipped = 0;

    // * Loop semua tick yang belum dieksekusi
    while (!scheduled.isAfter(now) && !_isPastEnd(scheduled, endExclusive)) {
      final next = AutoScheduleCalculator.calculateNext(group, scheduled);
      final at = scheduled;
      final committed = await _commitTick(group, expected, next, () {
        if (at.isBefore(windowStart)) {
          // * Terlalu lama terlewat → skip
          return [
            AutoTransactionLog(
              scheduledAt: at,
              executedAt: now,
              status: AutoTransactionLogStatus.skipped.index,
              errorMessage: 'Eksekusi terlewat lebih dari 7 hari',
            ),
          ];
        }
        return [_bookOneTick(group, items, at, now)];
      });
      if (committed == null) {
        // * Runner lain/pengguna sudah mengubah grup, atau commit gagal
        // * (dan sudah di-rollback) — tick akan dicoba lagi di run berikutnya
        logInfo('Tick group ${group.ulid} tidak dibukukan pada run ini');
        if (identical(expected, initial)) return;
        break;
      }
      expected = next;
      for (final log in committed) {
        logs.add(log);
        if (log.logStatus == AutoTransactionLogStatus.skipped) {
          totalSkipped++;
        } else {
          totalSuccess += log.successCount;
          totalFailure += log.failureCount;
        }
      }

      scheduled = next;
    }

    // * Nonaktifkan grup jika sudah melewati endDate (inklusif seharian)
    bool stillActive = group.isActive;
    if (_isPastEnd(scheduled, endExclusive)) {
      stillActive = false;
      logInfo('Group ${group.ulid} nonaktif karena melewati endDate');
    }

    // * CAS: tidak menimpa perubahan jadwal/aktif/pause oleh pengguna
    await _repo
        .updateGroupAfterExecution(
          ulid: group.ulid,
          expectedNext: scheduled,
          nextExecutedAt: scheduled,
          lastExecutedAt: now,
          isActive: stillActive,
        )
        .run();
    final stored = (await _repo.getGroupByUlid(ulid: group.ulid).run())
        .match((_) => null, (success) => success.data);
    stillActive = stored?.isActive ?? stillActive;

    // * Re-arm exact alarm for the next tick so subsequent executions are
    //   triggered precisely at the scheduled time, not by WorkManager drift.
    if (stillActive && _alarmService != null) {
      // Reflect the updated nextExecutedAt on the in-memory group object
      // so the alarm service sees the correct next time.
      group.nextExecutedAt = stored?.nextExecutedAt ?? scheduled;
      group.isActive = stillActive;
      await _alarmService.scheduleForGroup(group);
    } else if (!stillActive && _alarmService != null) {
      await _alarmService.cancelForGroup(group);
    }

    // * Kirim satu notifikasi per grup per run
    if (logs.isNotEmpty) {
      await _notifService.showExecutionResult(
        group,
        totalSuccess,
        totalFailure,
        totalSkipped,
      );
    }
  }

  Future<void> _skipAllPendingTicks(
    AutoTransactionGroup group,
    DateTime now,
    DateTime? endExclusive,
  ) async {
    final skipped = <DateTime>[];
    var scheduled = group.nextExecutedAt ?? now;
    while (!scheduled.isAfter(now)) {
      if (!_isPastEnd(scheduled, endExclusive)) skipped.add(scheduled);
      scheduled = AutoScheduleCalculator.calculateNext(group, scheduled);
    }

    final committed = await _commitTick(
      group,
      group.nextExecutedAt,
      scheduled,
      () => [
        for (final at in skipped)
          AutoTransactionLog(
            scheduledAt: at,
            executedAt: now,
            status: AutoTransactionLogStatus.skipped.index,
            errorMessage: 'Grup sedang di-pause',
          ),
      ],
      allowPaused: true,
    );
    if (committed == null) return;

    // * Grup yang di-pause tetap dinonaktifkan setelah endDate (AUTO-6)
    final stillActive = group.isActive && !_isPastEnd(scheduled, endExclusive);
    await _repo
        .updateGroupAfterExecution(
          ulid: group.ulid,
          expectedNext: scheduled,
          nextExecutedAt: scheduled,
          lastExecutedAt: now,
          isActive: stillActive,
        )
        .run();
    if (!stillActive) await _alarmService?.cancelForGroup(group);
  }

  // * Dijalankan sinkron di dalam write transaction commitTick: exception di
  // * sini me-rollback klaim, transaksi, dan saldo sekaligus
  AutoTransactionLog _bookOneTick(
    AutoTransactionGroup group,
    List<AutoTransactionItem>? allItems,
    DateTime scheduledAt,
    DateTime now,
  ) {
    if (allItems == null) {
      return AutoTransactionLog(
        scheduledAt: scheduledAt,
        executedAt: now,
        status: AutoTransactionLogStatus.failed.index,
        errorMessage: 'Gagal membaca item grup',
      );
    }

    final activeItems = allItems.where((i) => i.isActive).toList();

    if (activeItems.isEmpty) {
      return AutoTransactionLog(
        scheduledAt: scheduledAt,
        executedAt: now,
        status: AutoTransactionLogStatus.skipped.index,
        errorMessage: 'Tidak ada item aktif dalam grup',
      );
    }

    // * Build params dari template transaction pada setiap item
    final params = <CreateTransactionParams>[];
    final skipErrors = <String>[];

    for (final item in activeItems) {
      final template = item.transaction.target;
      if (template == null) {
        skipErrors.add('Item ${item.ulid}: template transaksi tidak ditemukan');
        continue;
      }
      final assetUlid = template.asset.target?.ulid;
      if (assetUlid == null) {
        skipErrors.add('Item ${item.ulid}: aset template tidak ditemukan');
        continue;
      }
      params.add(
        CreateTransactionParams(
          assetUlid: assetUlid,
          categoryUlid: template.category.target?.ulid,
          type: template.direction,
          amount: template.amount,
          transactionDate: scheduledAt,
          description: template.description,
        ),
      );
    }

    // * Semua item invalid
    if (params.isEmpty) {
      return AutoTransactionLog(
        scheduledAt: scheduledAt,
        executedAt: now,
        status: AutoTransactionLogStatus.failed.index,
        failureCount: activeItems.length,
        errorMessage: skipErrors.join('; '),
      );
    }

    // * Eksekusi bulk create transaction di transaksi yang sama
    final data = _transactionRepo.createManyTransactionsSync(params);
    final successCount = data.successfulTransactions.length;
    final failureCount = skipErrors.length + data.failedTransactions.length;
    final String? txError = data.failedTransactions.isEmpty
        ? null
        : data.failedTransactions.map((f) => f.errorMessage).join('; ');
    logInfo(
      'Group ${group.ulid}: $successCount berhasil, ${data.failedTransactions.length} gagal',
    );

    // * Gabungkan semua pesan error
    final allErrors = [
      if (skipErrors.isNotEmpty) skipErrors.join('; '),
      ?txError,
    ].join('; ');

    final logStatus = switch ((successCount, failureCount)) {
      (> 0, 0) when skipErrors.isEmpty => AutoTransactionLogStatus.success,
      (> 0, _) => AutoTransactionLogStatus.partial,
      _ => AutoTransactionLogStatus.failed,
    };

    return AutoTransactionLog(
      scheduledAt: scheduledAt,
      executedAt: now,
      status: logStatus.index,
      successCount: successCount,
      failureCount: failureCount,
      errorMessage: allErrors.isEmpty ? null : allErrors,
    );
  }
}
