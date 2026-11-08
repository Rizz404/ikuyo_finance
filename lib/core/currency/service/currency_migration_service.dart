import 'package:ikuyo_finance/core/currency/currency.dart';
import 'package:ikuyo_finance/core/currency/models/currency_marker.dart';
import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/core/extensions/logger_extension.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/objectbox.g.dart';

/// Result of currency migration
class CurrencyMigrationResult {
  final int assetsUpdated;
  final int transactionsUpdated;
  final int budgetsUpdated;
  final Duration duration;
  final bool success;
  final String? errorMessage;

  const CurrencyMigrationResult({
    this.assetsUpdated = 0,
    this.transactionsUpdated = 0,
    this.budgetsUpdated = 0,
    this.duration = Duration.zero,
    this.success = true,
    this.errorMessage,
  });

  int get totalUpdated => assetsUpdated + transactionsUpdated + budgetsUpdated;

  factory CurrencyMigrationResult.failure(String message) {
    return CurrencyMigrationResult(success: false, errorMessage: message);
  }
}

/// Service to handle currency migration across all financial data
class CurrencyMigrationService {
  final ObjectBoxStorage _storage;

  const CurrencyMigrationService(this._storage);

  /// Migrate all financial data from one currency to another
  /// * This updates actual values in the database
  /// * Should be called with loading UI as it may take time for large datasets
  Future<CurrencyMigrationResult> migrateAllData({
    required CurrencyCode fromCurrency,
    required CurrencyCode toCurrency,
    void Function(String status, double progress)? onProgress,
  }) async {
    if (fromCurrency == toCurrency) {
      return const CurrencyMigrationResult();
    }

    final stopwatch = Stopwatch()..start();

    try {
      talker.info(
        '[CurrencyMigrationService] Starting migration from '
        '${fromCurrency.name} to ${toCurrency.name}',
      );

      final from = Currency.getByCode(fromCurrency);
      final to = Currency.getByCode(toCurrency);

      // * Semua langkah dalam satu write transaction: gagal di tengah jalan
      // * berarti rollback total, sehingga retry tidak mengonversi dua kali
      final (assetsUpdated, transactionsUpdated, budgetsUpdated) = _storage
          .store
          .runInTransaction(TxMode.write, () {
            // * Tolak migrasi bila nominal di DB sudah bukan mata uang asal
            // * (mis. konversi sebelumnya sudah commit tapi prefs gagal ditulis)
            final stored = readMarker();
            if (stored != null && stored != fromCurrency) {
              throw StateError(
                'Database amounts are stored in ${stored.name}, '
                'not ${fromCurrency.name}; refusing to convert again',
              );
            }

            // * Step 1: Migrate Assets
            onProgress?.call('Migrating assets...', 0.0);
            final assets = _migrateAssets(from, to, onProgress);

            // * Step 2: Migrate Transactions
            onProgress?.call('Migrating transactions...', 0.33);
            final transactions = _migrateTransactions(from, to, onProgress);

            // * Step 3: Migrate Budgets
            onProgress?.call('Migrating budgets...', 0.66);
            final budgets = _migrateBudgets(from, to, onProgress);

            // * Penanda ditulis di transaksi yang sama dengan konversi
            _writeMarker(toCurrency);
            return (assets, transactions, budgets);
          });

      onProgress?.call('Migration complete!', 1.0);

      stopwatch.stop();

      talker.info(
        '[CurrencyMigrationService] Migration completed: '
        '$assetsUpdated assets, '
        '$transactionsUpdated transactions, '
        '$budgetsUpdated budgets '
        'in ${stopwatch.elapsed.inMilliseconds}ms',
      );

      return CurrencyMigrationResult(
        assetsUpdated: assetsUpdated,
        transactionsUpdated: transactionsUpdated,
        budgetsUpdated: budgetsUpdated,
        duration: stopwatch.elapsed,
        success: true,
      );
    } catch (e, s) {
      stopwatch.stop();
      talker.error('[CurrencyMigrationService] Migration failed', e, s);
      return CurrencyMigrationResult.failure(e.toString());
    }
  }

  /// Mata uang tempat nominal di database disimpan, atau null untuk
  /// instalasi lama yang belum memiliki penanda.
  CurrencyCode? readMarker() {
    final marker = _storage.box<CurrencyMarker>().getAll().firstOrNull;
    if (marker == null) return null;
    for (final code in CurrencyCode.values) {
      if (code.name == marker.currency) return code;
    }
    return null;
  }

  /// Menentukan mata uang aktif saat startup. Penanda DB menang; instalasi
  /// lama tanpa penanda mengadopsi [preferred] (nilai prefs) tanpa
  /// mengubah nominal apa pun.
  CurrencyCode resolveStoredCurrency(CurrencyCode preferred) {
    return _storage.store.runInTransaction(TxMode.write, () {
      final stored = readMarker();
      if (stored != null) return stored;
      _writeMarker(preferred);
      return preferred;
    });
  }

  /// Menandai ulang mata uang tanpa mengonversi nominal (display-only).
  void markStoredCurrency(CurrencyCode code) {
    _storage.store.runInTransaction(TxMode.write, () => _writeMarker(code));
  }

  void _writeMarker(CurrencyCode code) {
    final box = _storage.box<CurrencyMarker>();
    final existing = box.getAll();
    final marker = existing.isEmpty
        ? CurrencyMarker(currency: code.name)
        : (existing.first
            ..currency = code.name
            ..updatedAt = DateTime.now());
    if (existing.length > 1) {
      box.removeMany(existing.skip(1).map((m) => m.id).toList());
    }
    box.put(marker);
  }

  /// Migrate all assets to new currency
  int _migrateAssets(
    Currency from,
    Currency to,
    void Function(String status, double progress)? onProgress,
  ) {
    final box = _storage.box<Asset>();
    final assets = box.getAll();

    if (assets.isEmpty) return 0;

    final updatedAssets = <Asset>[];

    for (var i = 0; i < assets.length; i++) {
      final asset = assets[i];
      final convertedBalance = CurrencyConverter.convert(
        amount: asset.balance,
        from: from,
        to: to,
      );

      // * Round based on target currency decimal digits
      final roundedBalance = _roundToDecimalDigits(
        convertedBalance,
        to.decimalDigits,
      );

      asset.balance = roundedBalance;
      asset.updatedAt = DateTime.now();
      updatedAssets.add(asset);

      // * Report progress
      final progress = (i + 1) / assets.length;
      onProgress?.call(
        'Migrating asset ${i + 1}/${assets.length}',
        0.0 + (progress * 0.33),
      );
    }

    // * Batch update
    box.putMany(updatedAssets);

    return updatedAssets.length;
  }

  /// Migrate all transactions to new currency
  int _migrateTransactions(
    Currency from,
    Currency to,
    void Function(String status, double progress)? onProgress,
  ) {
    final box = _storage.box<Transaction>();
    final transactions = box.getAll();

    if (transactions.isEmpty) return 0;

    final updatedTransactions = <Transaction>[];

    for (var i = 0; i < transactions.length; i++) {
      final transaction = transactions[i];
      final convertedAmount = CurrencyConverter.convert(
        amount: transaction.amount,
        from: from,
        to: to,
      );

      final roundedAmount = _roundToDecimalDigits(
        convertedAmount,
        to.decimalDigits,
      );

      transaction.amount = roundedAmount;
      transaction.updatedAt = DateTime.now();
      updatedTransactions.add(transaction);

      // * Report progress
      final progress = (i + 1) / transactions.length;
      onProgress?.call(
        'Migrating transaction ${i + 1}/${transactions.length}',
        0.33 + (progress * 0.33),
      );
    }

    // * Batch update
    box.putMany(updatedTransactions);

    return updatedTransactions.length;
  }

  /// Migrate all budgets to new currency
  int _migrateBudgets(
    Currency from,
    Currency to,
    void Function(String status, double progress)? onProgress,
  ) {
    final box = _storage.box<Budget>();
    final budgets = box.getAll();

    if (budgets.isEmpty) return 0;

    final updatedBudgets = <Budget>[];

    for (var i = 0; i < budgets.length; i++) {
      final budget = budgets[i];
      final convertedLimit = CurrencyConverter.convert(
        amount: budget.amountLimit,
        from: from,
        to: to,
      );

      final roundedLimit = _roundToDecimalDigits(
        convertedLimit,
        to.decimalDigits,
      );

      budget.amountLimit = roundedLimit;
      budget.updatedAt = DateTime.now();
      updatedBudgets.add(budget);

      // * Report progress
      final progress = (i + 1) / budgets.length;
      onProgress?.call(
        'Migrating budget ${i + 1}/${budgets.length}',
        0.66 + (progress * 0.34),
      );
    }

    // * Batch update
    box.putMany(updatedBudgets);

    return updatedBudgets.length;
  }

  /// Round number to specific decimal digits
  double _roundToDecimalDigits(double value, int digits) {
    if (digits == 0) {
      return value.roundToDouble();
    }
    final mod = _pow10(digits);
    return (value * mod).roundToDouble() / mod;
  }

  double _pow10(int exp) {
    double result = 1;
    for (var i = 0; i < exp; i++) {
      result *= 10;
    }
    return result;
  }

  /// Get count of records that will be migrated
  Future<Map<String, int>> getRecordCounts() async {
    return {
      'assets': _storage.box<Asset>().count(),
      'transactions': _storage.box<Transaction>().count(),
      'budgets': _storage.box<Budget>().count(),
    };
  }
}
