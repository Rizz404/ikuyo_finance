import 'package:fpdart/fpdart.dart';
import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';
import 'package:ikuyo_finance/core/wrapper/failure.dart';
import 'package:ikuyo_finance/core/wrapper/success.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_group.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_item.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_log.dart';
import 'package:ikuyo_finance/features/backup/models/backup_data.dart';
import 'package:ikuyo_finance/features/backup/repositories/backup_repository.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/objectbox.g.dart';

class BackupRepositoryImpl implements BackupRepository {
  final ObjectBoxStorage _storage;

  const BackupRepositoryImpl(this._storage);

  Box<Category> get _categoryBox => _storage.box<Category>();
  Box<Asset> get _assetBox => _storage.box<Asset>();
  Box<Transaction> get _transactionBox => _storage.box<Transaction>();
  Box<Budget> get _budgetBox => _storage.box<Budget>();
  Box<AutoTransactionGroup> get _autoGroupBox =>
      _storage.box<AutoTransactionGroup>();
  Box<AutoTransactionItem> get _autoItemBox =>
      _storage.box<AutoTransactionItem>();
  Box<AutoTransactionLog> get _autoLogBox => _storage.box<AutoTransactionLog>();

  @override
  TaskEither<Failure, Success<BackupData>> exportData() {
    return TaskEither.tryCatch(
      () async {
        logService('Ekspor data', 'Memulai ekspor cadangan');

        // * Export order: categories → assets → transactions → budgets
        // *               → autoGroups → autoItems → autoLogs
        final categories = _categoryBox.getAll();
        final assets = _assetBox.getAll();
        final transactions = _transactionBox.getAll();
        final budgets = _budgetBox.getAll();
        final autoGroups = _autoGroupBox.getAll();
        final autoItems = _autoItemBox.getAll();
        final autoLogs = _autoLogBox.getAll();

        final backupData = BackupData(
          version: '1.0.0',
          createdAt: DateTime.now(),
          appName: 'Ikuyo Finance',
          categories: categories.map(CategoryBackup.fromEntity).toList(),
          assets: assets.map(AssetBackup.fromEntity).toList(),
          transactions: transactions
              .where((t) => t.asset.target != null)
              .map(TransactionBackup.fromEntity)
              .toList(),
          budgets: budgets
              .where((b) => b.category.target != null)
              .map(BudgetBackup.fromEntity)
              .toList(),
          autoGroups: autoGroups.map(AutoGroupBackup.fromEntity).toList(),
          autoItems: autoItems
              .where(
                (i) => i.group.target != null && i.transaction.target != null,
              )
              .map(AutoItemBackup.fromEntity)
              .toList(),
          autoLogs: autoLogs
              .where((l) => l.group.target != null)
              .map(AutoLogBackup.fromEntity)
              .toList(),
        );

        logInfo('Ekspor selesai: ${backupData.totalItems} item');

        return Success(message: 'Data berhasil diekspor', data: backupData);
      },
      (error, stackTrace) {
        logError('Gagal mengekspor data', error, stackTrace);
        return Failure(message: 'Gagal mengekspor data: ${error.toString()}');
      },
    );
  }

  @override
  TaskEither<Failure, Success<void>> importData(BackupData backupData) {
    return TaskEither.tryCatch(
      () async {
        logService('Impor data', 'Memulai impor cadangan');

        // * Clear order (deepest dependents first):
        // * autoLogs → autoItems → autoGroups → transactions → budgets
        // * → categories → assets
        _autoLogBox.removeAll();
        _autoItemBox.removeAll();
        _autoGroupBox.removeAll();
        _transactionBox.removeAll();
        _budgetBox.removeAll();
        _categoryBox.removeAll();
        _assetBox.removeAll();

        logInfo('Data yang ada berhasil dihapus');

        // ── 1. Categories ──────────────────────────────────────────────────
        final categoryMap = <String, Category>{};

        // * First pass: create categories without parent relations
        for (final backup in backupData.categories) {
          final category = Category(
            ulid: backup.ulid,
            name: backup.name,
            type: backup.type,
            icon: backup.icon,
            color: backup.color,
            createdAt: backup.createdAt,
            updatedAt: backup.updatedAt,
          );
          _categoryBox.put(category);
          categoryMap[backup.ulid] = category;
        }

        // * Second pass: set parent relations
        for (final backup in backupData.categories) {
          if (backup.parentUlid != null) {
            final category = categoryMap[backup.ulid];
            final parent = categoryMap[backup.parentUlid];
            if (category != null && parent != null) {
              category.parent.target = parent;
              _categoryBox.put(category);
            }
          }
        }

        logInfo('Kategori diimpor: ${backupData.categories.length}');

        // ── 2. Assets ──────────────────────────────────────────────────────
        final assetMap = <String, Asset>{};
        for (final backup in backupData.assets) {
          final asset = Asset(
            ulid: backup.ulid,
            name: backup.name,
            type: backup.type,
            balance: backup.balance,
            icon: backup.icon,
            createdAt: backup.createdAt,
            updatedAt: backup.updatedAt,
          );
          _assetBox.put(asset);
          assetMap[backup.ulid] = asset;
        }

        logInfo('Aset diimpor: ${backupData.assets.length}');

        // ── 3. Transactions ────────────────────────────────────────────────
        final transactionMap = <String, Transaction>{};
        for (final backup in backupData.transactions) {
          final asset = assetMap[backup.assetUlid];
          if (asset == null) continue;

          final transaction = Transaction(
            ulid: backup.ulid,
            amount: backup.amount,
            transactionDate: backup.transactionDate,
            description: backup.description,
            imagePath: backup.imagePath,
            createdAt: backup.createdAt,
            updatedAt: backup.updatedAt,
          );

          transaction.asset.target = asset;

          if (backup.categoryUlid != null) {
            final category = categoryMap[backup.categoryUlid];
            if (category != null) {
              transaction.category.target = category;
            }
          }

          _transactionBox.put(transaction);
          transactionMap[backup.ulid] = transaction;
        }

        logInfo('Transaksi diimpor: ${backupData.transactions.length}');

        // ── 4. Budgets ─────────────────────────────────────────────────────
        for (final backup in backupData.budgets) {
          final category = categoryMap[backup.categoryUlid];
          if (category == null) continue;

          final budget = Budget(
            ulid: backup.ulid,
            amountLimit: backup.amountLimit,
            period: backup.period,
            startDate: backup.startDate,
            endDate: backup.endDate,
            createdAt: backup.createdAt,
            updatedAt: backup.updatedAt,
          );

          budget.category.target = category;
          _budgetBox.put(budget);
        }

        logInfo('Anggaran diimpor: ${backupData.budgets.length}');

        // ── 5. Auto Transaction Groups ─────────────────────────────────────
        final autoGroupMap = <String, AutoTransactionGroup>{};
        for (final backup in backupData.autoGroups) {
          final group = AutoTransactionGroup(
            ulid: backup.ulid,
            name: backup.name,
            description: backup.description,
            isActive: backup.isActive,
            isPaused: backup.isPaused,
            pauseStartAt: backup.pauseStartAt,
            pauseEndAt: backup.pauseEndAt,
            frequency: backup.frequency,
            scheduleHour: backup.scheduleHour,
            scheduleMinute: backup.scheduleMinute,
            dayOfWeek: backup.dayOfWeek,
            dayOfMonth: backup.dayOfMonth,
            monthOfYear: backup.monthOfYear,
            intervalDays: backup.intervalDays,
            activeDaysMask: backup.activeDaysMask,
            startDate: backup.startDate,
            endDate: backup.endDate,
            nextExecutedAt: backup.nextExecutedAt,
            lastExecutedAt: backup.lastExecutedAt,
            createdAt: backup.createdAt,
            updatedAt: backup.updatedAt,
          );
          _autoGroupBox.put(group);
          autoGroupMap[backup.ulid] = group;
        }

        logInfo('Auto group diimpor: ${backupData.autoGroups.length}');

        // ── 6. Auto Transaction Items ──────────────────────────────────────
        for (final backup in backupData.autoItems) {
          final group = autoGroupMap[backup.groupUlid];
          final transaction = transactionMap[backup.transactionUlid];
          if (group == null || transaction == null) continue;

          final item = AutoTransactionItem(
            ulid: backup.ulid,
            isActive: backup.isActive,
            sortOrder: backup.sortOrder,
            createdAt: backup.createdAt,
            updatedAt: backup.updatedAt,
          );

          item.group.target = group;
          item.transaction.target = transaction;
          _autoItemBox.put(item);
        }

        logInfo('Auto item diimpor: ${backupData.autoItems.length}');

        // ── 7. Auto Transaction Logs ───────────────────────────────────────
        for (final backup in backupData.autoLogs) {
          final group = autoGroupMap[backup.groupUlid];
          if (group == null) continue;

          final log = AutoTransactionLog(
            ulid: backup.ulid,
            scheduledAt: backup.scheduledAt,
            executedAt: backup.executedAt,
            status: backup.status,
            successCount: backup.successCount,
            failureCount: backup.failureCount,
            errorMessage: backup.errorMessage,
            createdAt: backup.createdAt,
            updatedAt: backup.updatedAt,
          );

          log.group.target = group;
          _autoLogBox.put(log);
        }

        logInfo('Auto log diimpor: ${backupData.autoLogs.length}');
        logInfo('Impor selesai: ${backupData.totalItems} item');

        return const Success(message: 'Data berhasil diimpor');
      },
      (error, stackTrace) {
        logError('Gagal mengimpor data', error, stackTrace);
        return Failure(message: 'Gagal mengimpor data: ${error.toString()}');
      },
    );
  }

  @override
  TaskEither<Failure, Success<Map<String, int>>> getDataSummary() {
    return TaskEither.tryCatch(
      () async {
        final summary = {
          'categories': _categoryBox.count(),
          'assets': _assetBox.count(),
          'transactions': _transactionBox.count(),
          'budgets': _budgetBox.count(),
          'autoGroups': _autoGroupBox.count(),
          'autoItems': _autoItemBox.count(),
          'autoLogs': _autoLogBox.count(),
        };

        return Success(message: 'Ringkasan berhasil diambil', data: summary);
      },
      (error, stackTrace) {
        logError('Gagal mengambil ringkasan data', error, stackTrace);
        return Failure(message: 'Gagal mengambil ringkasan data');
      },
    );
  }
}
