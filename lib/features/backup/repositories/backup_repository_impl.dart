import 'package:easy_localization/easy_localization.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ikuyo_finance/core/currency/models/currency.dart';
import 'package:ikuyo_finance/core/currency/service/currency_migration_service.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/core/extensions/logger_extension.dart';
import 'package:ikuyo_finance/core/wrapper/failure.dart';
import 'package:ikuyo_finance/core/wrapper/success.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_schedule_frequency.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_group.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_item.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_log.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_log_status.dart';
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
  CurrencyMigrationService get _currencyService =>
      CurrencyMigrationService(_storage);

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
        // * Penanda mata uang DB (bukan preferensi tampilan); tanpa penanda
        // *   tidak ditebak, backup ditandai tanpa mata uang
        final marker = _currencyService.readMarker();

        final backupData = BackupData(
          version: BackupData.currentVersion,
          createdAt: DateTime.now(),
          appName: 'Ikuyo Finance',
          currency: marker == null ? null : BackupCurrency.of(marker),
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

        // ! Validasi snapshot sebelum menyentuh data yang ada
        _validateBackup(backupData);

        // * Semua penghapusan dan penulisan dalam satu transaksi tulis:
        // * jika ada error, ObjectBox me-rollback sehingga data lama utuh
        // * Penanda mata uang ditulis di transaksi yang sama dengan data
        // *   (markStoredCurrency memakai ulang transaksi tulis yang aktif)
        // * Transaksi berjalan di isolate worker (F5) dengan store yang
        // *   di-attach ObjectBox; isolate UI tidak terblokir selama impor
        final currency = backupData.currency!.currencyCode!;
        await _storage.store.runInTransactionAsync(
          TxMode.write,
          _importInTransaction,
          (backupData, currency),
        );

        logInfo('Impor selesai: ${backupData.totalItems} item');

        return const Success(message: 'Data berhasil diimpor');
      },
      (error, stackTrace) {
        logError('Gagal mengimpor data', error, stackTrace);
        if (error is BackupCurrencyException) {
          return Failure(message: error.message);
        }
        return Failure(message: 'Gagal mengimpor data: ${error.toString()}');
      },
    );
  }

  /// Worker `runInTransactionAsync`: tanpa DI, tr() atau logger (talker hanya
  /// ada di isolate UI); store worker ditutup oleh ObjectBox, bukan di sini
  static void _importInTransaction(
    Store store,
    (BackupData, CurrencyCode) param,
  ) {
    final (backupData, currency) = param;
    final storage = ObjectBoxStorage.wrap(store);
    BackupRepositoryImpl(storage)._replaceAllData(backupData);
    CurrencyMigrationService(storage).markStoredCurrency(currency);
  }

  /// Validasi struktur backup: ulid unik per entitas dan nilai enum valid
  void _validateBackup(BackupData data) {
    // * Mata uang divalidasi sebelum penghapusan; backup tanpa metadata tidak
    // *   ditafsirkan ulang dalam mata uang DB tujuan (F3)
    final currency = data.currency;
    if (currency == null) {
      throw BackupCurrencyException(
        LocaleKeys.backupScreenCurrencyMissing.tr(),
      );
    }
    if (!currency.isSupported) {
      throw BackupCurrencyException(
        LocaleKeys.backupScreenCurrencyUnsupported.tr(
          namedArgs: {'code': currency.code},
        ),
      );
    }

    void checkUnique(String entity, Iterable<String> ulids) {
      final seen = <String>{};
      for (final ulid in ulids) {
        if (!seen.add(ulid)) {
          throw FormatException('ulid $entity duplikat: $ulid');
        }
      }
    }

    void checkRange(String field, int value, int length) {
      if (value < 0 || value >= length) {
        throw FormatException('Nilai $field tidak valid: $value');
      }
    }

    checkUnique('kategori', data.categories.map((e) => e.ulid));
    checkUnique('aset', data.assets.map((e) => e.ulid));
    checkUnique('transaksi', data.transactions.map((e) => e.ulid));
    checkUnique('anggaran', data.budgets.map((e) => e.ulid));
    checkUnique('auto group', data.autoGroups.map((e) => e.ulid));
    checkUnique('auto item', data.autoItems.map((e) => e.ulid));
    checkUnique('auto log', data.autoLogs.map((e) => e.ulid));

    // * Referensi harus menunjuk ke entitas di snapshot yang sama; baris
    // * yatim ditolak (bukan dilewati diam-diam) sebelum data lama dihapus
    void checkRef(String what, String? ref, Set<String> known) {
      if (ref != null && !known.contains(ref)) {
        throw FormatException('Referensi $what tidak ditemukan: $ref');
      }
    }

    final categoryUlids = data.categories.map((e) => e.ulid).toSet();
    final assetUlids = data.assets.map((e) => e.ulid).toSet();
    final transactionUlids = data.transactions.map((e) => e.ulid).toSet();
    final groupUlids = data.autoGroups.map((e) => e.ulid).toSet();

    for (final c in data.categories) {
      checkRef('induk kategori ${c.ulid}', c.parentUlid, categoryUlids);
    }
    for (final t in data.transactions) {
      checkRef('aset transaksi ${t.ulid}', t.assetUlid, assetUlids);
      checkRef('kategori transaksi ${t.ulid}', t.categoryUlid, categoryUlids);
    }
    for (final b in data.budgets) {
      checkRef('kategori anggaran ${b.ulid}', b.categoryUlid, categoryUlids);
    }
    for (final i in data.autoItems) {
      checkRef('grup auto item ${i.ulid}', i.groupUlid, groupUlids);
      checkRef(
        'transaksi auto item ${i.ulid}',
        i.transactionUlid,
        transactionUlids,
      );
    }
    for (final l in data.autoLogs) {
      checkRef('grup auto log ${l.ulid}', l.groupUlid, groupUlids);
    }

    for (final t in data.transactions) {
      final type = t.type;
      if (type != null) {
        checkRange('tipe transaksi', type, CategoryType.values.length);
      }
    }
    for (final c in data.categories) {
      checkRange('tipe kategori', c.type, CategoryType.values.length);
    }
    for (final a in data.assets) {
      checkRange('tipe aset', a.type, AssetType.values.length);
    }
    for (final b in data.budgets) {
      checkRange('periode anggaran', b.period, BudgetPeriod.values.length);
    }
    for (final g in data.autoGroups) {
      checkRange(
        'frekuensi auto group',
        g.frequency,
        AutoScheduleFrequency.values.length,
      );
    }
    for (final l in data.autoLogs) {
      checkRange(
        'status auto log',
        l.status,
        AutoTransactionLogStatus.values.length,
      );
    }
  }

  /// Hapus semua data lalu tulis snapshot (dipanggil di dalam transaksi)
  void _replaceAllData(BackupData backupData) {
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

      // * Backup lama tanpa type: pakai arah kategori / income (perilaku lama)
      transaction.type =
          backup.type ??
          transaction.category.target?.type ??
          CategoryType.income.index;

      _transactionBox.put(transaction);
      transactionMap[backup.ulid] = transaction;
    }

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

/// Metadata mata uang backup tidak ada/tidak didukung; pesan sudah lokal
class BackupCurrencyException implements Exception {
  final String message;

  const BackupCurrencyException(this.message);

  @override
  String toString() => message;
}
