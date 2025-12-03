import 'package:ikuyo_finance/core/currency/currency.dart';
import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';

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

      // * Step 1: Migrate Assets
      onProgress?.call('Migrating assets...', 0.0);
      final assetsUpdated = await _migrateAssets(from, to, onProgress);

      // * Step 2: Migrate Transactions
      onProgress?.call('Migrating transactions...', 0.33);
      final transactionsUpdated = await _migrateTransactions(
        from,
        to,
        onProgress,
      );

      // * Step 3: Migrate Budgets
      onProgress?.call('Migrating budgets...', 0.66);
      final budgetsUpdated = await _migrateBudgets(from, to, onProgress);

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

  /// Migrate all assets to new currency
  Future<int> _migrateAssets(
    Currency from,
    Currency to,
    void Function(String status, double progress)? onProgress,
  ) async {
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
  Future<int> _migrateTransactions(
    Currency from,
    Currency to,
    void Function(String status, double progress)? onProgress,
  ) async {
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
  Future<int> _migrateBudgets(
    Currency from,
    Currency to,
    void Function(String status, double progress)? onProgress,
  ) async {
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
