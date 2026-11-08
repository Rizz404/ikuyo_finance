import 'package:fpdart/fpdart.dart' hide Order;
import 'package:ikuyo_finance/core/currency/models/currency.dart';
import 'package:ikuyo_finance/core/currency/models/currency_marker.dart';
import 'package:ikuyo_finance/core/storage/query_extensions.dart';
import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/core/extensions/logger_extension.dart';
import 'package:ikuyo_finance/core/wrapper/failure.dart';
import 'package:ikuyo_finance/core/wrapper/success.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/budget/models/budget_progress.dart';
import 'package:ikuyo_finance/features/budget/models/create_budget_params.dart';
import 'package:ikuyo_finance/features/budget/models/get_budgets_params.dart';
import 'package:ikuyo_finance/features/budget/models/update_budget_params.dart';
import 'package:ikuyo_finance/features/budget/repositories/budget_repository.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/objectbox.g.dart';

class BudgetRepositoryImpl implements BudgetRepository {
  final ObjectBoxStorage _storage;

  const BudgetRepositoryImpl(this._storage);

  Box<Budget> get _box => _storage.box<Budget>();
  Box<Category> get _categoryBox => _storage.box<Category>();

  // * Periode kustom wajib punya tanggal mulai & akhir berurutan (AAOB-8)
  void _ensureValidRange(BudgetPeriod period, DateTime? start, DateTime? end) {
    if (period != BudgetPeriod.custom) return;
    if (start == null || end == null) {
      throw Exception('Periode kustom membutuhkan tanggal mulai dan akhir');
    }
    if (end.isBefore(start)) {
      throw Exception('Tanggal akhir harus sama atau setelah tanggal mulai');
    }
  }

  // * Limit wajib positif & finite agar progres tidak membagi nol (AAOB-5)
  void _ensureValidLimit(double limit) {
    if (!limit.isFinite || limit <= 0) {
      throw Exception('Batas anggaran harus lebih dari 0');
    }
  }

  @override
  TaskEither<Failure, Success<Budget>> createBudget(CreateBudgetParams params) {
    return TaskEither.tryCatch(
      () async {
        logService('Buat anggaran', 'kategori: ${params.categoryUlid}');

        // * Get category
        final category = _categoryBox
            .query(Category_.ulid.equals(params.categoryUlid))
            .findFirstAndClose();

        if (category == null) {
          throw Exception('Kategori tidak ditemukan');
        }

        _ensureValidRange(params.period, params.startDate, params.endDate);
        _ensureValidLimit(params.amountLimit);

        final budget = Budget(
          amountLimit: params.amountLimit,
          period: params.period.index,
          startDate: params.startDate,
          endDate: params.endDate,
        );

        budget.category.target = category;

        _box.put(budget);
        logInfo('Anggaran berhasil dibuat');

        return Success(message: 'Anggaran berhasil dibuat', data: budget);
      },
      (error, stackTrace) {
        logError('Gagal membuat anggaran', error, stackTrace);
        return Failure(
          message:
              error.toString().contains('tidak ditemukan') ||
                  error.toString().contains('Batas anggaran')
              ? error.toString()
              : 'Gagal membuat anggaran. Silakan coba lagi.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, SuccessCursor<Budget>> getBudgets(
    GetBudgetsParams params,
  ) {
    return TaskEither.tryCatch(
      () async {
        logService(
          'Ambil anggaran',
          'cursor: ${params.cursor}, limit: ${params.limit}, cari: ${params.searchQuery}, urutkan: ${params.sortBy}',
        );

        // * Build conditions list
        final List<Condition<Budget>> conditions = [];

        // * Filter by period
        if (params.period != null) {
          conditions.add(Budget_.period.equals(params.period!.index));
        }

        // * Amount limit range filter
        if (params.minAmountLimit != null && params.maxAmountLimit != null) {
          conditions.add(
            Budget_.amountLimit.between(
              params.minAmountLimit!,
              params.maxAmountLimit!,
            ),
          );
        } else if (params.minAmountLimit != null) {
          conditions.add(
            Budget_.amountLimit.greaterOrEqual(params.minAmountLimit!),
          );
        } else if (params.maxAmountLimit != null) {
          conditions.add(
            Budget_.amountLimit.lessOrEqual(params.maxAmountLimit!),
          );
        }

        // * Start date range filter
        if (params.startDateFrom != null && params.startDateTo != null) {
          conditions.add(
            Budget_.startDate.betweenDate(
              params.startDateFrom!,
              params.startDateTo!,
            ),
          );
        } else if (params.startDateFrom != null) {
          conditions.add(
            Budget_.startDate.greaterOrEqualDate(params.startDateFrom!),
          );
        } else if (params.startDateTo != null) {
          conditions.add(
            Budget_.startDate.lessOrEqualDate(params.startDateTo!),
          );
        }

        // * End date range filter
        if (params.endDateFrom != null && params.endDateTo != null) {
          conditions.add(
            Budget_.endDate.betweenDate(params.endDateFrom!, params.endDateTo!),
          );
        } else if (params.endDateFrom != null) {
          conditions.add(
            Budget_.endDate.greaterOrEqualDate(params.endDateFrom!),
          );
        } else if (params.endDateTo != null) {
          conditions.add(Budget_.endDate.lessOrEqualDate(params.endDateTo!));
        }

        // * Build query with conditions
        QueryBuilder<Budget> queryBuilder;
        if (conditions.isNotEmpty) {
          Condition<Budget> combinedCondition = conditions.first;
          for (int i = 1; i < conditions.length; i++) {
            combinedCondition = combinedCondition.and(conditions[i]);
          }
          queryBuilder = _box.query(combinedCondition);
        } else {
          queryBuilder = _box.query();
        }

        // * Apply sorting based on sortBy parameter
        final orderFlags = params.sortOrder == BudgetSortOrder.descending
            ? Order.descending
            : 0;

        switch (params.sortBy) {
          case BudgetSortBy.amountLimit:
            queryBuilder.order(Budget_.amountLimit, flags: orderFlags);
            break;
          case BudgetSortBy.startDate:
            queryBuilder.order(Budget_.startDate, flags: orderFlags);
            break;
          case BudgetSortBy.endDate:
            queryBuilder.order(Budget_.endDate, flags: orderFlags);
            break;
          case BudgetSortBy.createdAt:
            queryBuilder.order(Budget_.createdAt, flags: orderFlags);
            break;
        }

        final builtQuery = queryBuilder.build();
        final allResults = builtQuery.find();
        builtQuery.close();

        // * Filter by category (ObjectBox doesn't support ToOne query directly)
        var filteredResults = allResults;
        if (params.categoryUlid != null) {
          filteredResults = filteredResults
              .where((b) => b.category.target?.ulid == params.categoryUlid)
              .toList();
        }

        // * Filter by search query (search by category name)
        if (params.searchQuery != null && params.searchQuery!.isNotEmpty) {
          final searchLower = params.searchQuery!.toLowerCase();
          filteredResults = filteredResults
              .where(
                (b) =>
                    b.category.target?.name.toLowerCase().contains(
                      searchLower,
                    ) ??
                    false,
              )
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
        final budgets = hasMore ? results.sublist(0, params.limit) : results;

        final cursorInfo = CursorInfo(
          nextCursor: hasMore ? (offset + params.limit).toString() : '',
          hasNextPage: hasMore,
          perPage: params.limit,
        );

        logInfo('Anggaran diambil: ${budgets.length}, adaLagi: $hasMore');

        return SuccessCursor(
          message: 'Anggaran berhasil diambil',
          data: budgets,
          cursor: cursorInfo,
        );
      },
      (error, stackTrace) {
        logError('Gagal mengambil anggaran', error, stackTrace);
        return Failure(message: 'Gagal mengambil anggaran. Silakan coba lagi.');
      },
    );
  }

  @override
  TaskEither<Failure, Success<Budget>> getBudgetById({required String ulid}) {
    return TaskEither.tryCatch(
      () async {
        logService('Ambil anggaran berdasarkan id', ulid);

        final budget = _box
            .query(Budget_.ulid.equals(ulid))
            .findFirstAndClose();

        if (budget == null) {
          throw Exception('Anggaran tidak ditemukan');
        }

        logInfo('Anggaran berhasil diambil');
        return Success(message: 'Anggaran berhasil diambil', data: budget);
      },
      (error, stackTrace) {
        logError('Gagal mengambil anggaran berdasarkan id', error, stackTrace);
        return Failure(
          message: error.toString().contains('tidak ditemukan')
              ? 'Anggaran tidak ditemukan'
              : 'Gagal mengambil anggaran. Silakan coba lagi.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, Success<Budget>> updateBudget(UpdateBudgetParams params) {
    return TaskEither.tryCatch(
      () async {
        logService('Perbarui anggaran', params.ulid);

        final budget = _box
            .query(Budget_.ulid.equals(params.ulid))
            .findFirstAndClose();

        if (budget == null) {
          throw Exception('Anggaran tidak ditemukan');
        }

        // * Update fields jika ada
        if (params.amountLimit != null) {
          _ensureValidLimit(params.amountLimit!);
          budget.amountLimit = params.amountLimit!;
        }
        if (params.period != null) budget.period = params.period!.index;
        if (params.startDate != null) budget.startDate = params.startDate;
        if (params.endDate != null) budget.endDate = params.endDate;
        // * Pindah dari kustom tanpa tanggal baru: buang rentang lama (AAOB-8)
        if (params.period != null &&
            params.period != BudgetPeriod.custom &&
            params.startDate == null &&
            params.endDate == null) {
          budget.startDate = null;
          budget.endDate = null;
        }
        _ensureValidRange(
          budget.budgetPeriod,
          budget.startDate,
          budget.endDate,
        );

        // * Update category jika ada
        if (params.categoryUlid != null) {
          final category = _categoryBox
              .query(Category_.ulid.equals(params.categoryUlid!))
              .findFirstAndClose();

          if (category == null) {
            throw Exception('Kategori tidak ditemukan');
          }

          budget.category.target = category;
        }

        budget.updatedAt = DateTime.now();
        _box.put(budget);

        logInfo('Anggaran berhasil diperbarui');
        return Success(message: 'Anggaran berhasil diperbarui', data: budget);
      },
      (error, stackTrace) {
        logError('Gagal memperbarui anggaran', error, stackTrace);
        return Failure(
          message:
              error.toString().contains('tidak ditemukan') ||
                  error.toString().contains('Batas anggaran')
              ? error.toString()
              : 'Gagal memperbarui anggaran. Silakan coba lagi.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, ActionSuccess> deleteBudget({required String ulid}) {
    return TaskEither.tryCatch(
      () async {
        logService('Hapus anggaran', ulid);

        final budget = _box
            .query(Budget_.ulid.equals(ulid))
            .findFirstAndClose();

        if (budget == null) {
          throw Exception('Anggaran tidak ditemukan');
        }

        _box.remove(budget.id);
        logInfo('Anggaran berhasil dihapus');

        return const ActionSuccess(message: 'Anggaran berhasil dihapus');
      },
      (error, stackTrace) {
        logError('Gagal menghapus anggaran', error, stackTrace);
        return Failure(
          message: error.toString().contains('tidak ditemukan')
              ? 'Anggaran tidak ditemukan'
              : 'Gagal menghapus anggaran. Silakan coba lagi.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, Success<BudgetProgress>> getBudgetProgress({
    required String ulid,
    DateTime? now,
  }) {
    return TaskEither.tryCatch(
      () async {
        final budget = _box
            .query(Budget_.ulid.equals(ulid))
            .findFirstAndClose();
        if (budget == null) {
          throw Exception('Anggaran tidak ditemukan');
        }
        return Success(data: _computeProgress(budget, now ?? DateTime.now()));
      },
      (error, stackTrace) {
        logError('Gagal menghitung realisasi anggaran', error, stackTrace);
        return Failure(
          message: error.toString().contains('tidak ditemukan')
              ? error.toString()
              : 'Gagal menghitung realisasi anggaran.',
        );
      },
    );
  }

  /// * spent = transaksi arah expense di [start, end) atas kategori anggaran
  ///   beserta seluruh turunannya; tanpa kategori = semua expense.
  /// * Tanggal efektif = transactionDate ?? createdAt (F6).
  /// * Nominal sudah tersimpan dalam mata uang penanda DB (CurrencyMarker),
  ///   jadi tidak ada konversi; dijumlah dalam satuan minor mata uang itu.
  BudgetProgress _computeProgress(Budget budget, DateTime now) {
    final range = BudgetPeriodRange.of(budget, now: now);
    final digits = _storedCurrency().decimalDigits;

    final root = budget.category.target;
    final Set<int>? categoryIds = root == null ? null : _descendantIds(root.id);

    final transactions = _storage
        .box<Transaction>()
        .query(
          // * Tanggal efektif = transactionDate ?? createdAt (F6)
          Transaction_.transactionDate
              .greaterOrEqualDate(range.start)
              .and(Transaction_.transactionDate.lessThanDate(range.end))
              .or(
                Transaction_.transactionDate.isNull().and(
                  Transaction_.createdAt
                      .greaterOrEqualDate(range.start)
                      .and(Transaction_.createdAt.lessThanDate(range.end)),
                ),
              ),
        )
        .findAndClose();

    var spentMinor = 0;
    for (final t in transactions) {
      if (!t.isExpense) continue;
      if (categoryIds != null && !categoryIds.contains(t.category.targetId)) {
        continue;
      }
      spentMinor += BudgetProgress.toMinor(t.amount, digits);
    }

    return BudgetProgress(
      spentMinor: spentMinor,
      limitMinor: BudgetProgress.toMinor(budget.amountLimit, digits),
      decimalDigits: digits,
      period: range,
    );
  }

  /// Kategori akar + semua turunan (lewat parent), aman terhadap siklus
  Set<int> _descendantIds(int rootId) {
    final all = _categoryBox.getAll();
    final result = <int>{rootId};
    for (final c in all) {
      final visited = <int>{};
      var cur = c;
      while (visited.add(cur.id)) {
        if (cur.id == rootId) {
          result.add(c.id);
          break;
        }
        final parent = cur.parent.target;
        if (parent == null) break;
        cur = parent;
      }
    }
    return result;
  }

  Currency _storedCurrency() {
    final marker = _storage.box<CurrencyMarker>().getAll().firstOrNull;
    for (final code in CurrencyCode.values) {
      if (code.name == marker?.currency) return Currency.getByCode(code);
    }
    return Currency.getByCode(CurrencyCode.idr);
  }
}
