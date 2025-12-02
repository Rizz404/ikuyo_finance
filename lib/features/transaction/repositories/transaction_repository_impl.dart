import 'package:fpdart/fpdart.dart' hide Order;
import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';
import 'package:ikuyo_finance/core/wrapper/failure.dart';
import 'package:ikuyo_finance/core/wrapper/success.dart';
import 'package:ikuyo_finance/features/statistic/models/category_summary.dart';
import 'package:ikuyo_finance/features/statistic/models/get_statistic_params.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/features/transaction/models/create_transaction_params.dart';
import 'package:ikuyo_finance/features/transaction/models/get_transactions_params.dart';
import 'package:ikuyo_finance/features/transaction/models/update_transaction_params.dart';
import 'package:ikuyo_finance/features/transaction/repositories/transaction_repository.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/objectbox.g.dart';

// * Helper untuk menghitung balance adjustment berdasarkan category type
double _getBalanceAdjustment(double amount, Category? category) {
  if (category == null) return amount; // * Default: treat as income
  return category.categoryType == CategoryType.expense ? -amount : amount;
}

class TransactionRepositoryImpl implements TransactionRepository {
  final ObjectBoxStorage _storage;

  const TransactionRepositoryImpl(this._storage);

  Box<Transaction> get _box => _storage.box<Transaction>();
  Box<Asset> get _assetBox => _storage.box<Asset>();
  Box<Category> get _categoryBox => _storage.box<Category>();

  @override
  TaskEither<Failure, Success<Transaction>> createTransaction(
    CreateTransactionParams params,
  ) {
    return TaskEither.tryCatch(
      () async {
        logService('Buat transaksi', 'aset: ${params.assetUlid}');

        // * Get asset (required)
        final asset = _assetBox
            .query(Asset_.ulid.equals(params.assetUlid))
            .build()
            .findFirst();

        if (asset == null) {
          throw Exception('Aset tidak ditemukan');
        }

        final transaction = Transaction(
          amount: params.amount,
          transactionDate: params.transactionDate,
          description: params.description,
          imagePath: params.imagePath,
        );

        transaction.asset.target = asset;

        // * Set category jika ada
        if (params.categoryUlid != null) {
          final category = _categoryBox
              .query(Category_.ulid.equals(params.categoryUlid!))
              .build()
              .findFirst();

          if (category == null) {
            throw Exception('Kategori tidak ditemukan');
          }

          transaction.category.target = category;
        }

        _box.put(transaction);

        // * Update asset balance berdasarkan category type
        // * Income: +amount, Expense: -amount
        final balanceAdjustment = _getBalanceAdjustment(
          params.amount,
          transaction.category.target,
        );
        asset.balance += balanceAdjustment;
        asset.updatedAt = DateTime.now();
        _assetBox.put(asset);

        logInfo('Transaksi berhasil dibuat, saldo aset diperbarui');

        return Success(message: 'Transaksi berhasil dibuat', data: transaction);
      },
      (error, stackTrace) {
        logError('Gagal membuat transaksi', error, stackTrace);
        return Failure(
          message: error.toString().contains('tidak ditemukan')
              ? error.toString()
              : 'Gagal membuat transaksi. Silakan coba lagi.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, SuccessCursor<Transaction>> getTransactions(
    GetTransactionsParams params,
  ) {
    return TaskEither.tryCatch(
      () async {
        logService(
          'Ambil transaksi',
          'cursor: ${params.cursor}, limit: ${params.limit}, cari: ${params.searchQuery}, urutkan: ${params.sortBy}',
        );

        // * Build conditions list
        final List<Condition<Transaction>> conditions = [];

        // * Date range filter
        if (params.startDate != null && params.endDate != null) {
          conditions.add(
            Transaction_.transactionDate.betweenDate(
              params.startDate!,
              params.endDate!,
            ),
          );
        } else if (params.startDate != null) {
          conditions.add(
            Transaction_.transactionDate.greaterOrEqualDate(params.startDate!),
          );
        } else if (params.endDate != null) {
          conditions.add(
            Transaction_.transactionDate.lessOrEqualDate(params.endDate!),
          );
        }

        // * Amount range filter
        if (params.minAmount != null && params.maxAmount != null) {
          conditions.add(
            Transaction_.amount.between(params.minAmount!, params.maxAmount!),
          );
        } else if (params.minAmount != null) {
          conditions.add(Transaction_.amount.greaterOrEqual(params.minAmount!));
        } else if (params.maxAmount != null) {
          conditions.add(Transaction_.amount.lessOrEqual(params.maxAmount!));
        }

        // * Case-insensitive search by description
        if (params.searchQuery != null && params.searchQuery!.isNotEmpty) {
          conditions.add(
            Transaction_.description.contains(
              params.searchQuery!,
              caseSensitive: false,
            ),
          );
        }

        // * Build query with conditions
        QueryBuilder<Transaction> queryBuilder;
        if (conditions.isNotEmpty) {
          Condition<Transaction> combinedCondition = conditions.first;
          for (int i = 1; i < conditions.length; i++) {
            combinedCondition = combinedCondition.and(conditions[i]);
          }
          queryBuilder = _box.query(combinedCondition);
        } else {
          queryBuilder = _box.query();
        }

        // * Apply sorting based on sortBy parameter
        final orderFlags = params.sortOrder == SortOrder.descending
            ? Order.descending
            : 0;

        switch (params.sortBy) {
          case TransactionSortBy.amount:
            queryBuilder.order(Transaction_.amount, flags: orderFlags);
            break;
          case TransactionSortBy.createdAt:
            queryBuilder.order(Transaction_.createdAt, flags: orderFlags);
            break;
          case TransactionSortBy.transactionDate:
            // * Secondary sort by createdAt for transactions on same date
            queryBuilder.order(Transaction_.transactionDate, flags: orderFlags);
            queryBuilder.order(Transaction_.createdAt, flags: Order.descending);
            break;
        }

        final builtQuery = queryBuilder.build();
        final allResults = builtQuery.find();
        builtQuery.close();

        // * Filter by asset (ObjectBox doesn't support ToOne query directly)
        var filteredResults = allResults;
        if (params.assetUlid != null) {
          filteredResults = filteredResults
              .where((t) => t.asset.target?.ulid == params.assetUlid)
              .toList();
        }

        // * Filter by category
        if (params.categoryUlid != null) {
          filteredResults = filteredResults
              .where((t) => t.category.target?.ulid == params.categoryUlid)
              .toList();
        }

        // * Cursor-based pagination (offset-based internally)
        final offset = params.cursor != null
            ? int.tryParse(params.cursor!) ?? 0
            : 0;

        final startIndex = offset < filteredResults.length
            ? offset
            : filteredResults.length;
        final endIndex =
            (startIndex + params.limit + 1) < filteredResults.length
            ? startIndex + params.limit + 1
            : filteredResults.length;
        final results = filteredResults.sublist(startIndex, endIndex);

        final hasMore = results.length > params.limit;
        final transactions = hasMore
            ? results.sublist(0, params.limit)
            : results;

        final cursorInfo = CursorInfo(
          nextCursor: hasMore ? (offset + params.limit).toString() : '',
          hasNextPage: hasMore,
          perPage: params.limit,
        );

        logInfo('Transaksi diambil: ${transactions.length}, adaLagi: $hasMore');

        return SuccessCursor(
          message: 'Transaksi berhasil diambil',
          data: transactions,
          cursor: cursorInfo,
        );
      },
      (error, stackTrace) {
        logError('Gagal mengambil transaksi', error, stackTrace);
        return Failure(
          message: 'Gagal mengambil transaksi. Silakan coba lagi.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, Success<Transaction>> getTransactionById({
    required String ulid,
  }) {
    return TaskEither.tryCatch(
      () async {
        logService('Ambil transaksi berdasarkan id', ulid);

        final transaction = _box
            .query(Transaction_.ulid.equals(ulid))
            .build()
            .findFirst();

        if (transaction == null) {
          throw Exception('Transaksi tidak ditemukan');
        }

        logInfo('Transaksi berhasil diambil');
        return Success(
          message: 'Transaksi berhasil diambil',
          data: transaction,
        );
      },
      (error, stackTrace) {
        logError('Gagal mengambil transaksi berdasarkan id', error, stackTrace);
        return Failure(
          message: error.toString().contains('tidak ditemukan')
              ? 'Transaksi tidak ditemukan'
              : 'Gagal mengambil transaksi. Silakan coba lagi.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, Success<Transaction>> updateTransaction(
    UpdateTransactionParams params,
  ) {
    return TaskEither.tryCatch(
      () async {
        logService('Perbarui transaksi', params.ulid);

        final transaction = _box
            .query(Transaction_.ulid.equals(params.ulid))
            .build()
            .findFirst();

        if (transaction == null) {
          throw Exception('Transaksi tidak ditemukan');
        }

        final oldAmount = transaction.amount;
        final oldAsset = transaction.asset.target;
        final oldCategory = transaction.category.target;

        // * Update fields jika ada
        if (params.amount != null) transaction.amount = params.amount!;
        if (params.transactionDate != null) {
          transaction.transactionDate = params.transactionDate;
        }
        if (params.description != null) {
          transaction.description = params.description;
        }
        if (params.imagePath != null) transaction.imagePath = params.imagePath;

        // * Update asset jika ada
        Asset? newAsset;
        if (params.assetUlid != null) {
          newAsset = _assetBox
              .query(Asset_.ulid.equals(params.assetUlid!))
              .build()
              .findFirst();

          if (newAsset == null) {
            throw Exception('Aset tidak ditemukan');
          }

          transaction.asset.target = newAsset;
        }

        // * Update category jika ada
        if (params.categoryUlid != null) {
          final category = _categoryBox
              .query(Category_.ulid.equals(params.categoryUlid!))
              .build()
              .findFirst();

          if (category == null) {
            throw Exception('Kategori tidak ditemukan');
          }

          transaction.category.target = category;
        }

        // * Handle balance updates
        final amountChanged =
            params.amount != null && params.amount != oldAmount;
        final assetChanged =
            newAsset != null && newAsset.ulid != oldAsset?.ulid;
        final categoryChanged =
            params.categoryUlid != null &&
            transaction.category.target?.ulid != oldCategory?.ulid;

        // * Calculate old and new balance adjustments
        final oldBalanceAdjustment = _getBalanceAdjustment(
          oldAmount,
          oldCategory,
        );
        final newBalanceAdjustment = _getBalanceAdjustment(
          transaction.amount,
          transaction.category.target,
        );

        if (assetChanged && oldAsset != null) {
          // * Revert old asset balance (undo old adjustment)
          oldAsset.balance -= oldBalanceAdjustment;
          oldAsset.updatedAt = DateTime.now();
          _assetBox.put(oldAsset);

          // * Apply to new asset
          newAsset.balance += newBalanceAdjustment;
          newAsset.updatedAt = DateTime.now();
          _assetBox.put(newAsset);
        } else if ((amountChanged || categoryChanged) && oldAsset != null) {
          // * Same asset, different amount or category: adjust by difference
          final difference = newBalanceAdjustment - oldBalanceAdjustment;
          oldAsset.balance += difference;
          oldAsset.updatedAt = DateTime.now();
          _assetBox.put(oldAsset);
        }

        transaction.updatedAt = DateTime.now();
        _box.put(transaction);

        logInfo('Transaksi berhasil diperbarui, saldo aset diperbarui');
        return Success(
          message: 'Transaksi berhasil diperbarui',
          data: transaction,
        );
      },
      (error, stackTrace) {
        logError('Gagal memperbarui transaksi', error, stackTrace);
        return Failure(
          message: error.toString().contains('tidak ditemukan')
              ? error.toString()
              : 'Gagal memperbarui transaksi. Silakan coba lagi.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, ActionSuccess> deleteTransaction({required String ulid}) {
    return TaskEither.tryCatch(
      () async {
        logService('Hapus transaksi', ulid);

        final transaction = _box
            .query(Transaction_.ulid.equals(ulid))
            .build()
            .findFirst();

        if (transaction == null) {
          throw Exception('Transaksi tidak ditemukan');
        }

        // * Revert asset balance (undo the original adjustment)
        final asset = transaction.asset.target;
        if (asset != null) {
          final balanceAdjustment = _getBalanceAdjustment(
            transaction.amount,
            transaction.category.target,
          );
          asset.balance -= balanceAdjustment;
          asset.updatedAt = DateTime.now();
          _assetBox.put(asset);
        }

        _box.remove(transaction.id);
        logInfo('Transaksi berhasil dihapus, saldo aset dikembalikan');

        return const ActionSuccess(message: 'Transaksi berhasil dihapus');
      },
      (error, stackTrace) {
        logError('Gagal menghapus transaksi', error, stackTrace);
        return Failure(
          message: error.toString().contains('tidak ditemukan')
              ? 'Transaksi tidak ditemukan'
              : 'Gagal menghapus transaksi. Silakan coba lagi.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, Success<StatisticSummary>> getStatisticSummary(
    GetStatisticParams params,
  ) {
    return TaskEither.tryCatch(
      () async {
        logService(
          'Ambil ringkasan statistik',
          'mulai: ${params.startDate}, akhir: ${params.endDate}',
        );

        // * Query transactions within date range
        final queryBuilder = _box.query(
          Transaction_.transactionDate.betweenDate(
            params.startDate,
            params.endDate,
          ),
        );

        final builtQuery = queryBuilder.build();
        final transactions = builtQuery.find();
        builtQuery.close();

        // * Group transactions by category and type
        final Map<String?, List<Transaction>> incomeByCategory = {};
        final Map<String?, List<Transaction>> expenseByCategory = {};

        for (final transaction in transactions) {
          final category = transaction.category.target;
          final categoryUlid = category?.ulid;
          final categoryType = category?.categoryType;

          if (categoryType == CategoryType.income) {
            incomeByCategory.putIfAbsent(categoryUlid, () => []);
            incomeByCategory[categoryUlid]!.add(transaction);
          } else if (categoryType == CategoryType.expense) {
            expenseByCategory.putIfAbsent(categoryUlid, () => []);
            expenseByCategory[categoryUlid]!.add(transaction);
          } else {
            // * Transaksi tanpa kategori - treat as expense
            expenseByCategory.putIfAbsent(null, () => []);
            expenseByCategory[null]!.add(transaction);
          }
        }

        // * Calculate totals
        double totalIncome = 0;
        double totalExpense = 0;

        // * Build income summaries
        final incomeSummaries = <CategorySummary>[];
        for (final entry in incomeByCategory.entries) {
          final categoryTransactions = entry.value;
          final total = categoryTransactions.fold<double>(
            0,
            (sum, t) => sum + t.amount,
          );
          totalIncome += total;

          incomeSummaries.add(
            CategorySummary(
              category: categoryTransactions.first.category.target,
              totalAmount: total,
              transactionCount: categoryTransactions.length,
            ),
          );
        }

        // * Build expense summaries
        final expenseSummaries = <CategorySummary>[];
        for (final entry in expenseByCategory.entries) {
          final categoryTransactions = entry.value;
          final total = categoryTransactions.fold<double>(
            0,
            (sum, t) => sum + t.amount,
          );
          totalExpense += total;

          expenseSummaries.add(
            CategorySummary(
              category: categoryTransactions.first.category.target,
              totalAmount: total,
              transactionCount: categoryTransactions.length,
            ),
          );
        }

        // * Calculate percentages and sort by amount descending
        final incomeWithPercentage = incomeSummaries.map((summary) {
          final percentage = totalIncome > 0
              ? (summary.totalAmount / totalIncome) * 100
              : 0.0;
          return summary.copyWithPercentage(percentage);
        }).toList()..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

        final expenseWithPercentage = expenseSummaries.map((summary) {
          final percentage = totalExpense > 0
              ? (summary.totalAmount / totalExpense) * 100
              : 0.0;
          return summary.copyWithPercentage(percentage);
        }).toList()..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

        final summary = StatisticSummary(
          totalIncome: totalIncome,
          totalExpense: totalExpense,
          incomeSummaries: incomeWithPercentage,
          expenseSummaries: expenseWithPercentage,
        );

        logInfo(
          'Ringkasan statistik diambil: pemasukan=${summary.totalIncome}, pengeluaran=${summary.totalExpense}',
        );

        return Success(
          message: 'Ringkasan statistik berhasil diambil',
          data: summary,
        );
      },
      (error, stackTrace) {
        logError('Gagal mengambil ringkasan statistik', error, stackTrace);
        return Failure(
          message: 'Gagal mengambil ringkasan statistik. Silakan coba lagi.',
        );
      },
    );
  }
}
