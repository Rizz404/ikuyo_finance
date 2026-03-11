import 'package:ikuyo_finance/core/utils/logger.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_schedule_calculator.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_group.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_log.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_log_status.dart';
import 'package:ikuyo_finance/features/auto_transaction/repositories/auto_transaction_repository.dart';
import 'package:ikuyo_finance/features/auto_transaction/services/auto_transaction_notification_service.dart';
import 'package:ikuyo_finance/features/transaction/models/create_transaction_params.dart';
import 'package:ikuyo_finance/features/transaction/repositories/transaction_repository.dart';

class AutoTransactionScheduler {
  final AutoTransactionRepository _repo;
  final TransactionRepository _transactionRepo;
  final AutoTransactionNotificationService _notifService;

  const AutoTransactionScheduler({
    required AutoTransactionRepository repo,
    required TransactionRepository transactionRepo,
    required AutoTransactionNotificationService notifService,
  }) : _repo = repo,
       _transactionRepo = transactionRepo,
       _notifService = notifService;

  // * Entry point utama — dipanggil dari Workmanager & foreground trigger
  Future<void> runPendingExecutions() async {
    logService('AutoTransactionScheduler: mulai scan pending groups');

    final result = await _repo.getPendingGroups().run();
    result.fold(
      (failure) => logError(
        'Gagal mengambil pending groups: ${failure.message}',
        null,
        null,
      ),
      (success) async {
        final groups = success.data ?? [];
        logData('Pending groups ditemukan: ${groups.length}');

        for (final group in groups) {
          await _processGroup(group);
        }
      },
    );

    logService('AutoTransactionScheduler: selesai');
  }

  // * Ekspos untuk testing
  DateTime calculateNext(AutoTransactionGroup group, DateTime from) =>
      AutoScheduleCalculator.calculateNext(group, from);

  // ─── Private ──────────────────────────────────────────────────────────────

  Future<void> _processGroup(AutoTransactionGroup group) async {
    final now = DateTime.now();
    final windowStart = now.subtract(const Duration(days: 7));

    logDomain('Processing group: ${group.ulid} (${group.name})');

    // * Auto-resume jika pauseEndAt sudah lewat
    if (group.isCurrentlyPaused()) {
      final pauseEnd = group.pauseEndAt;
      if (pauseEnd != null && !pauseEnd.isAfter(now)) {
        await _repo.resumeGroup(ulid: group.ulid).run();
        group.isPaused = false;
        group.pauseEndAt = null;
        logInfo('Auto-resume group: ${group.ulid}');
      } else {
        // * Masih pause — lewati semua tick, lanjut nextExecutedAt
        await _skipAllPendingTicks(group, now);
        return;
      }
    }

    var scheduled = group.nextExecutedAt ?? now;
    final List<AutoTransactionLog> logs = [];
    int totalSuccess = 0;
    int totalFailure = 0;
    int totalSkipped = 0;

    // * Loop semua tick yang belum dieksekusi
    while (!scheduled.isAfter(now)) {
      if (scheduled.isBefore(windowStart)) {
        // * Terlalu lama terlewat → skip
        final log = AutoTransactionLog(
          scheduledAt: scheduled,
          executedAt: now,
          status: AutoTransactionLogStatus.skipped.index,
          errorMessage: 'Eksekusi terlewat lebih dari 7 hari',
        );
        log.group.target = group;
        await _repo.saveExecutionLog(log).run();
        logs.add(log);
        totalSkipped++;
      } else {
        final log = await _executeOneTick(group, scheduled, now);
        logs.add(log);
        totalSuccess += log.successCount;
        totalFailure += log.failureCount;
      }

      scheduled = AutoScheduleCalculator.calculateNext(group, scheduled);
    }

    // * Nonaktifkan grup jika sudah melewati endDate
    bool stillActive = group.isActive;
    final endDate = group.endDate;
    if (endDate != null && !scheduled.isBefore(endDate)) {
      stillActive = false;
      logInfo('Group ${group.ulid} nonaktif karena melewati endDate');
    }

    await _repo
        .updateGroupAfterExecution(
          ulid: group.ulid,
          nextExecutedAt: scheduled,
          lastExecutedAt: now,
          isActive: stillActive,
        )
        .run();

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
  ) async {
    var scheduled = group.nextExecutedAt ?? now;
    while (!scheduled.isAfter(now)) {
      final log = AutoTransactionLog(
        scheduledAt: scheduled,
        executedAt: now,
        status: AutoTransactionLogStatus.skipped.index,
        errorMessage: 'Grup sedang di-pause',
      );
      log.group.target = group;
      await _repo.saveExecutionLog(log).run();
      scheduled = AutoScheduleCalculator.calculateNext(group, scheduled);
    }

    await _repo
        .updateGroupAfterExecution(
          ulid: group.ulid,
          nextExecutedAt: scheduled,
          lastExecutedAt: now,
          isActive: group.isActive,
        )
        .run();
  }

  Future<AutoTransactionLog> _executeOneTick(
    AutoTransactionGroup group,
    DateTime scheduledAt,
    DateTime now,
  ) async {
    // * Ambil items grup yang aktif
    final itemsResult = await _repo
        .getItemsByGroup(groupUlid: group.ulid)
        .run();

    if (itemsResult.isLeft()) {
      final log = AutoTransactionLog(
        scheduledAt: scheduledAt,
        executedAt: now,
        status: AutoTransactionLogStatus.failed.index,
        errorMessage: 'Gagal membaca item grup',
      );
      log.group.target = group;
      await _repo.saveExecutionLog(log).run();
      return log;
    }

    final allItems = itemsResult.getRight().toNullable()!.data ?? [];
    final activeItems = allItems.where((i) => i.isActive).toList();

    if (activeItems.isEmpty) {
      final log = AutoTransactionLog(
        scheduledAt: scheduledAt,
        executedAt: now,
        status: AutoTransactionLogStatus.skipped.index,
        errorMessage: 'Tidak ada item aktif dalam grup',
      );
      log.group.target = group;
      await _repo.saveExecutionLog(log).run();
      return log;
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
          amount: template.amount,
          transactionDate: scheduledAt,
          description: template.description,
        ),
      );
    }

    // * Semua item invalid
    if (params.isEmpty) {
      final log = AutoTransactionLog(
        scheduledAt: scheduledAt,
        executedAt: now,
        status: AutoTransactionLogStatus.failed.index,
        failureCount: activeItems.length,
        errorMessage: skipErrors.join('; '),
      );
      log.group.target = group;
      await _repo.saveExecutionLog(log).run();
      return log;
    }

    // * Eksekusi bulk create transaction
    int successCount = 0;
    int failureCount = skipErrors.length;
    String? txError;

    final txResult = await _transactionRepo
        .createManyTransactions(params)
        .run();
    txResult.fold(
      (failure) {
        failureCount += params.length;
        txError = failure.message;
        logError(
          'Bulk create gagal untuk group ${group.ulid}: ${failure.message}',
          null,
          null,
        );
      },
      (success) {
        final data = success.data!;
        successCount = data.successfulTransactions.length;
        failureCount += data.failedTransactions.length;
        if (data.failedTransactions.isNotEmpty) {
          txError = data.failedTransactions
              .map((f) => f.errorMessage)
              .join('; ');
        }
        logInfo(
          'Group ${group.ulid}: $successCount berhasil, ${data.failedTransactions.length} gagal',
        );
      },
    );

    // * Gabungkan semua pesan error
    final allErrors = [
      if (skipErrors.isNotEmpty) skipErrors.join('; '),
      if (txError != null) txError!,
    ].join('; ');

    final logStatus = switch ((successCount, failureCount)) {
      (> 0, 0) when skipErrors.isEmpty => AutoTransactionLogStatus.success,
      (> 0, _) => AutoTransactionLogStatus.partial,
      _ => AutoTransactionLogStatus.failed,
    };

    final log = AutoTransactionLog(
      scheduledAt: scheduledAt,
      executedAt: now,
      status: logStatus.index,
      successCount: successCount,
      failureCount: failureCount,
      errorMessage: allErrors.isEmpty ? null : allErrors,
    );
    log.group.target = group;
    await _repo.saveExecutionLog(log).run();
    return log;
  }
}
