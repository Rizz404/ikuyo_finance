import 'package:fpdart/fpdart.dart' hide Order;
import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';
import 'package:ikuyo_finance/core/wrapper/failure.dart';
import 'package:ikuyo_finance/core/wrapper/success.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_group.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_item.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_log.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_schedule_calculator.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/create_auto_group_params.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/create_auto_item_params.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/update_auto_group_params.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/update_auto_item_params.dart';
import 'package:ikuyo_finance/features/auto_transaction/repositories/auto_transaction_repository.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/objectbox.g.dart';

class AutoTransactionRepositoryImpl implements AutoTransactionRepository {
  final ObjectBoxStorage _storage;

  const AutoTransactionRepositoryImpl(this._storage);

  Box<AutoTransactionGroup> get _groupBox =>
      _storage.box<AutoTransactionGroup>();
  Box<AutoTransactionItem> get _itemBox => _storage.box<AutoTransactionItem>();
  Box<AutoTransactionLog> get _logBox => _storage.box<AutoTransactionLog>();
  Box<Transaction> get _transactionBox => _storage.box<Transaction>();

  // ─── Group CRUD ───────────────────────────────────────────────────────────

  @override
  TaskEither<Failure, Success<AutoTransactionGroup>> createGroup(
    CreateAutoGroupParams params,
  ) {
    return TaskEither.tryCatch(
      () async {
        logService('Buat auto transaction group', 'nama: ${params.name}');

        // * Validasi batas 10 grup dengan scheduleHour:scheduleMinute yang sama
        final conflictCount = _groupBox
            .query(
              AutoTransactionGroup_.scheduleHour
                  .equals(params.scheduleHour)
                  .and(
                    AutoTransactionGroup_.scheduleMinute.equals(
                      params.scheduleMinute,
                    ),
                  )
                  .and(AutoTransactionGroup_.isActive.equals(true)),
            )
            .build()
            .count();

        if (conflictCount >= 10) {
          throw Exception(
            'Maksimal 10 grup dengan jadwal ${params.scheduleHour.toString().padLeft(2, '0')}:${params.scheduleMinute.toString().padLeft(2, '0')} yang sama',
          );
        }

        final group = AutoTransactionGroup(
          name: params.name,
          description: params.description,
          frequency: params.frequency.index,
          scheduleHour: params.scheduleHour,
          scheduleMinute: params.scheduleMinute,
          dayOfWeek: params.dayOfWeek,
          dayOfMonth: params.dayOfMonth,
          monthOfYear: params.monthOfYear,
          intervalDays: params.intervalDays,
          activeDaysMask: params.activeDaysMask,
          startDate: params.startDate,
          endDate: params.endDate,
        );

        group.nextExecutedAt = AutoScheduleCalculator.calculateFirst(group);
        _groupBox.put(group);
        logInfo('Auto transaction group berhasil dibuat: ${group.ulid}');

        return Success(message: 'Grup berhasil dibuat', data: group);
      },
      (error, stackTrace) {
        logError('Gagal membuat auto transaction group', error, stackTrace);
        return Failure(message: error.toString());
      },
    );
  }

  @override
  TaskEither<Failure, Success<AutoTransactionGroup>> updateGroup(
    UpdateAutoGroupParams params,
  ) {
    return TaskEither.tryCatch(
      () async {
        logService('Update auto transaction group', 'ulid: ${params.ulid}');

        final group = _groupBox
            .query(AutoTransactionGroup_.ulid.equals(params.ulid))
            .build()
            .findFirst();

        if (group == null) {
          throw Exception('Grup tidak ditemukan');
        }

        // * Validasi konflik jadwal jika jam/menit berubah
        final newHour = params.scheduleHour ?? group.scheduleHour;
        final newMinute = params.scheduleMinute ?? group.scheduleMinute;
        if (newHour != group.scheduleHour ||
            newMinute != group.scheduleMinute) {
          final conflictCount = _groupBox
              .query(
                AutoTransactionGroup_.scheduleHour
                    .equals(newHour)
                    .and(AutoTransactionGroup_.scheduleMinute.equals(newMinute))
                    .and(AutoTransactionGroup_.isActive.equals(true))
                    .and(AutoTransactionGroup_.ulid.notEquals(params.ulid)),
              )
              .build()
              .count();

          if (conflictCount >= 10) {
            throw Exception(
              'Maksimal 10 grup dengan jadwal ${newHour.toString().padLeft(2, '0')}:${newMinute.toString().padLeft(2, '0')} yang sama',
            );
          }
        }

        if (params.name != null) group.name = params.name!;
        if (params.description != null) {
          group.description = params.description!();
        }
        if (params.frequency != null) {
          group.frequency = params.frequency!.index;
        }
        if (params.scheduleHour != null) {
          group.scheduleHour = params.scheduleHour!;
        }
        if (params.scheduleMinute != null) {
          group.scheduleMinute = params.scheduleMinute!;
        }
        if (params.dayOfWeek != null) group.dayOfWeek = params.dayOfWeek!();
        if (params.dayOfMonth != null) {
          group.dayOfMonth = params.dayOfMonth!();
        }
        if (params.monthOfYear != null) {
          group.monthOfYear = params.monthOfYear!();
        }
        if (params.intervalDays != null)
          group.intervalDays = params.intervalDays!;
        if (params.activeDaysMask != null)
          group.activeDaysMask = params.activeDaysMask!;
        if (params.startDate != null) group.startDate = params.startDate!;
        if (params.endDate != null) group.endDate = params.endDate!();
        if (params.isActive != null) group.isActive = params.isActive!;

        // * Recalculate nextExecutedAt jika ada field jadwal yang berubah
        final scheduleChanged =
            params.frequency != null ||
            params.scheduleHour != null ||
            params.scheduleMinute != null ||
            params.dayOfWeek != null ||
            params.dayOfMonth != null ||
            params.monthOfYear != null ||
            params.intervalDays != null ||
            params.activeDaysMask != null ||
            params.startDate != null;
        if (scheduleChanged) {
          group.nextExecutedAt = AutoScheduleCalculator.calculateFirst(group);
        }

        group.updatedAt = DateTime.now();
        _groupBox.put(group);

        logInfo('Auto transaction group berhasil diupdate: ${group.ulid}');
        return Success(message: 'Grup berhasil diperbarui', data: group);
      },
      (error, stackTrace) {
        logError('Gagal update auto transaction group', error, stackTrace);
        return Failure(message: error.toString());
      },
    );
  }

  @override
  TaskEither<Failure, ActionSuccess> deleteGroup({required String ulid}) {
    return TaskEither.tryCatch(
      () async {
        logService('Hapus auto transaction group', 'ulid: $ulid');

        final group = _groupBox
            .query(AutoTransactionGroup_.ulid.equals(ulid))
            .build()
            .findFirst();

        if (group == null) {
          throw Exception('Grup tidak ditemukan');
        }

        // * Hapus semua items milik grup ini
        final items = _itemBox
            .query(AutoTransactionItem_.group.equals(group.id))
            .build()
            .find();
        _itemBox.removeMany(items.map((e) => e.id).toList());

        // * Hapus semua logs milik grup ini
        final logs = _logBox
            .query(AutoTransactionLog_.group.equals(group.id))
            .build()
            .find();
        _logBox.removeMany(logs.map((e) => e.id).toList());

        _groupBox.remove(group.id);

        logInfo('Auto transaction group berhasil dihapus: $ulid');
        return const ActionSuccess(message: 'Grup berhasil dihapus');
      },
      (error, stackTrace) {
        logError('Gagal hapus auto transaction group', error, stackTrace);
        return Failure(message: error.toString());
      },
    );
  }

  @override
  TaskEither<Failure, Success<List<AutoTransactionGroup>>> getGroups() {
    return TaskEither.tryCatch(
      () async {
        final groups = _groupBox.getAll();
        groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return Success(
          message: '${groups.length} grup ditemukan',
          data: groups,
        );
      },
      (error, stackTrace) {
        logError('Gagal mengambil auto transaction groups', error, stackTrace);
        return Failure(message: 'Gagal mengambil daftar grup');
      },
    );
  }

  @override
  TaskEither<Failure, Success<AutoTransactionGroup>> getGroupByUlid({
    required String ulid,
  }) {
    return TaskEither.tryCatch(
      () async {
        final group = _groupBox
            .query(AutoTransactionGroup_.ulid.equals(ulid))
            .build()
            .findFirst();

        if (group == null) {
          throw Exception('Grup tidak ditemukan');
        }

        return Success(data: group);
      },
      (error, stackTrace) {
        logError('Gagal mengambil auto transaction group', error, stackTrace);
        return Failure(message: error.toString());
      },
    );
  }

  // ─── Item CRUD ────────────────────────────────────────────────────────────

  @override
  TaskEither<Failure, Success<AutoTransactionItem>> createItem(
    CreateAutoItemParams params,
  ) {
    return TaskEither.tryCatch(
      () async {
        logService(
          'Buat auto transaction item',
          'group: ${params.groupUlid}, tx: ${params.transactionUlid}',
        );

        final group = _groupBox
            .query(AutoTransactionGroup_.ulid.equals(params.groupUlid))
            .build()
            .findFirst();

        if (group == null) {
          throw Exception('Grup tidak ditemukan');
        }

        // * Validasi batas 20 item aktif per grup
        final activeItemCount = _itemBox
            .query(
              AutoTransactionItem_.group
                  .equals(group.id)
                  .and(AutoTransactionItem_.isActive.equals(true)),
            )
            .build()
            .count();

        if (activeItemCount >= 20) {
          throw Exception('Maksimal 20 item aktif per grup');
        }

        final transaction = _transactionBox
            .query(Transaction_.ulid.equals(params.transactionUlid))
            .build()
            .findFirst();

        if (transaction == null) {
          throw Exception('Transaksi template tidak ditemukan');
        }

        final item = AutoTransactionItem(sortOrder: params.sortOrder);
        item.transaction.target = transaction;
        item.group.target = group;

        _itemBox.put(item);

        logInfo('Auto transaction item berhasil dibuat: ${item.ulid}');
        return Success(message: 'Item berhasil ditambahkan', data: item);
      },
      (error, stackTrace) {
        logError('Gagal membuat auto transaction item', error, stackTrace);
        return Failure(message: error.toString());
      },
    );
  }

  @override
  TaskEither<Failure, Success<AutoTransactionItem>> updateItem(
    UpdateAutoItemParams params,
  ) {
    return TaskEither.tryCatch(
      () async {
        logService('Update auto transaction item', 'ulid: ${params.ulid}');

        final item = _itemBox
            .query(AutoTransactionItem_.ulid.equals(params.ulid))
            .build()
            .findFirst();

        if (item == null) {
          throw Exception('Item tidak ditemukan');
        }

        if (params.sortOrder != null) item.sortOrder = params.sortOrder!;
        if (params.isActive != null) item.isActive = params.isActive!;

        item.updatedAt = DateTime.now();
        _itemBox.put(item);

        logInfo('Auto transaction item berhasil diupdate: ${item.ulid}');
        return Success(message: 'Item berhasil diperbarui', data: item);
      },
      (error, stackTrace) {
        logError('Gagal update auto transaction item', error, stackTrace);
        return Failure(message: error.toString());
      },
    );
  }

  @override
  TaskEither<Failure, ActionSuccess> deleteItem({required String ulid}) {
    return TaskEither.tryCatch(
      () async {
        logService('Hapus auto transaction item', 'ulid: $ulid');

        final item = _itemBox
            .query(AutoTransactionItem_.ulid.equals(ulid))
            .build()
            .findFirst();

        if (item == null) {
          throw Exception('Item tidak ditemukan');
        }

        _itemBox.remove(item.id);
        logInfo('Auto transaction item berhasil dihapus: $ulid');
        return const ActionSuccess(message: 'Item berhasil dihapus');
      },
      (error, stackTrace) {
        logError('Gagal hapus auto transaction item', error, stackTrace);
        return Failure(message: error.toString());
      },
    );
  }

  @override
  TaskEither<Failure, Success<List<AutoTransactionItem>>> getItemsByGroup({
    required String groupUlid,
  }) {
    return TaskEither.tryCatch(
      () async {
        final group = _groupBox
            .query(AutoTransactionGroup_.ulid.equals(groupUlid))
            .build()
            .findFirst();

        if (group == null) {
          throw Exception('Grup tidak ditemukan');
        }

        final items = _itemBox
            .query(AutoTransactionItem_.group.equals(group.id))
            .order(AutoTransactionItem_.sortOrder)
            .build()
            .find();

        return Success(message: '${items.length} item ditemukan', data: items);
      },
      (error, stackTrace) {
        logError('Gagal mengambil items grup', error, stackTrace);
        return Failure(message: error.toString());
      },
    );
  }

  @override
  TaskEither<Failure, ActionSuccess> reorderItems({
    required String groupUlid,
    required List<String> orderedUlids,
  }) {
    return TaskEither.tryCatch(
      () async {
        logService('Reorder items', 'group: $groupUlid');

        final group = _groupBox
            .query(AutoTransactionGroup_.ulid.equals(groupUlid))
            .build()
            .findFirst();

        if (group == null) {
          throw Exception('Grup tidak ditemukan');
        }

        final items = _itemBox
            .query(AutoTransactionItem_.group.equals(group.id))
            .build()
            .find();

        final itemMap = {for (final item in items) item.ulid: item};
        final now = DateTime.now();

        for (int i = 0; i < orderedUlids.length; i++) {
          final item = itemMap[orderedUlids[i]];
          if (item != null) {
            item.sortOrder = i;
            item.updatedAt = now;
          }
        }

        _itemBox.putMany(items);
        return const ActionSuccess(message: 'Urutan item berhasil disimpan');
      },
      (error, stackTrace) {
        logError('Gagal reorder items', error, stackTrace);
        return Failure(message: error.toString());
      },
    );
  }

  // ─── Pause Management ─────────────────────────────────────────────────────

  @override
  TaskEither<Failure, ActionSuccess> pauseGroup({
    required String ulid,
    DateTime? pauseStartAt,
    DateTime? resumeAt,
  }) {
    return TaskEither.tryCatch(
      () async {
        logService('Pause gruppe', 'ulid: $ulid, resumeAt: $resumeAt');

        final group = _groupBox
            .query(AutoTransactionGroup_.ulid.equals(ulid))
            .build()
            .findFirst();

        if (group == null) {
          throw Exception('Grup tidak ditemukan');
        }

        group.isPaused = true;
        group.pauseStartAt = pauseStartAt ?? DateTime.now();
        group.pauseEndAt = resumeAt; // * null = pause manual
        group.updatedAt = DateTime.now();
        _groupBox.put(group);

        logInfo('Grup di-pause: $ulid');
        return const ActionSuccess(message: 'Grup berhasil di-pause');
      },
      (error, stackTrace) {
        logError('Gagal pause grup', error, stackTrace);
        return Failure(message: error.toString());
      },
    );
  }

  @override
  TaskEither<Failure, ActionSuccess> resumeGroup({required String ulid}) {
    return TaskEither.tryCatch(
      () async {
        logService('Resume grup', 'ulid: $ulid');

        final group = _groupBox
            .query(AutoTransactionGroup_.ulid.equals(ulid))
            .build()
            .findFirst();

        if (group == null) {
          throw Exception('Grup tidak ditemukan');
        }

        group.isPaused = false;
        group.pauseStartAt = null;
        group.pauseEndAt = null;
        group.updatedAt = DateTime.now();
        _groupBox.put(group);

        logInfo('Grup di-resume: $ulid');
        return const ActionSuccess(message: 'Grup berhasil di-resume');
      },
      (error, stackTrace) {
        logError('Gagal resume grup', error, stackTrace);
        return Failure(message: error.toString());
      },
    );
  }

  @override
  TaskEither<Failure, ActionSuccess> toggleGroup({
    required String ulid,
    required bool isActive,
  }) {
    return TaskEither.tryCatch(
      () async {
        final group = _groupBox
            .query(AutoTransactionGroup_.ulid.equals(ulid))
            .build()
            .findFirst();

        if (group == null) {
          throw Exception('Grup tidak ditemukan');
        }

        group.isActive = isActive;
        group.updatedAt = DateTime.now();
        _groupBox.put(group);

        return ActionSuccess(
          message: isActive ? 'Grup diaktifkan' : 'Grup dinonaktifkan',
        );
      },
      (error, stackTrace) {
        logError('Gagal toggle grup', error, stackTrace);
        return Failure(message: error.toString());
      },
    );
  }

  // ─── Scheduler Operations ─────────────────────────────────────────────────

  @override
  TaskEither<Failure, Success<List<AutoTransactionGroup>>> getPendingGroups() {
    return TaskEither.tryCatch(
      () async {
        final now = DateTime.now();

        final groups = _groupBox
            .query(
              AutoTransactionGroup_.isActive
                  .equals(true)
                  .and(
                    AutoTransactionGroup_.nextExecutedAt.lessOrEqualDate(now),
                  ),
            )
            .build()
            .find();

        logService(
          'Ambil pending groups',
          '${groups.length} grup menunggu eksekusi',
        );

        return Success(message: '${groups.length} grup pending', data: groups);
      },
      (error, stackTrace) {
        logError('Gagal mengambil pending groups', error, stackTrace);
        return Failure(message: 'Gagal mengambil grup yang menunggu eksekusi');
      },
    );
  }

  @override
  TaskEither<Failure, ActionSuccess> updateGroupAfterExecution({
    required String ulid,
    required DateTime nextExecutedAt,
    required DateTime lastExecutedAt,
    required bool isActive,
  }) {
    return TaskEither.tryCatch(
      () async {
        final group = _groupBox
            .query(AutoTransactionGroup_.ulid.equals(ulid))
            .build()
            .findFirst();

        if (group == null) {
          throw Exception('Grup tidak ditemukan');
        }

        group.nextExecutedAt = nextExecutedAt;
        group.lastExecutedAt = lastExecutedAt;
        group.isActive = isActive;
        group.updatedAt = DateTime.now();
        _groupBox.put(group);

        return const ActionSuccess(message: 'Grup diperbarui setelah eksekusi');
      },
      (error, stackTrace) {
        logError('Gagal update grup setelah eksekusi', error, stackTrace);
        return Failure(message: error.toString());
      },
    );
  }

  @override
  TaskEither<Failure, ActionSuccess> saveExecutionLog(AutoTransactionLog log) {
    return TaskEither.tryCatch(
      () async {
        _logBox.put(log);
        logService(
          'Simpan log eksekusi',
          'group: ${log.group.target?.ulid}, status: ${log.logStatus.name}',
        );
        return const ActionSuccess(message: 'Log disimpan');
      },
      (error, stackTrace) {
        logError('Gagal menyimpan log eksekusi', error, stackTrace);
        return Failure(message: 'Gagal menyimpan log');
      },
    );
  }

  @override
  TaskEither<Failure, Success<List<AutoTransactionLog>>> getLogsByGroup({
    required String groupUlid,
  }) {
    return TaskEither.tryCatch(
      () async {
        final group = _groupBox
            .query(AutoTransactionGroup_.ulid.equals(groupUlid))
            .build()
            .findFirst();

        if (group == null) {
          throw Exception('Grup tidak ditemukan');
        }

        final logs = _logBox
            .query(AutoTransactionLog_.group.equals(group.id))
            .order(AutoTransactionLog_.scheduledAt, flags: Order.descending)
            .build()
            .find();

        return Success(message: '${logs.length} log ditemukan', data: logs);
      },
      (error, stackTrace) {
        logError('Gagal mengambil log grup', error, stackTrace);
        return Failure(message: error.toString());
      },
    );
  }
}
