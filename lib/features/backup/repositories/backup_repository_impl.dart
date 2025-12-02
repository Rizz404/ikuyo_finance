import 'package:fpdart/fpdart.dart';
import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';
import 'package:ikuyo_finance/core/wrapper/failure.dart';
import 'package:ikuyo_finance/core/wrapper/success.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
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

  @override
  TaskEither<Failure, Success<BackupData>> exportData() {
    return TaskEither.tryCatch(
      () async {
        logService('Ekspor data', 'Memulai ekspor cadangan');

        // * Get all data from ObjectBox
        final categories = _categoryBox.getAll();
        final assets = _assetBox.getAll();
        final transactions = _transactionBox.getAll();
        final budgets = _budgetBox.getAll();

        // * Convert to backup models
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

        // * Clear existing data (order matters due to relations)
        _transactionBox.removeAll();
        _budgetBox.removeAll();
        _categoryBox.removeAll();
        _assetBox.removeAll();

        logInfo('Data yang ada berhasil dihapus');

        // * Import categories (parents first)
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

        // * Import assets
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

        // * Import transactions
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
        }

        logInfo('Transaksi diimpor: ${backupData.transactions.length}');

        // * Import budgets
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
