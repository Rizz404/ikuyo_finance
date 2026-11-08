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

        // * Filter kategori lewat id relasi di dalam query (P03)
        if (params.categoryUlid != null) {
          final categoryId = _categoryBox
              .query(Category_.ulid.equals(params.categoryUlid!))
              .findIdsAndClose()
              .firstOrNull;
          conditions.add(Budget_.category.equals(categoryId ?? -1));
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

        // * Cari nama kategori lewat link relasi (case-insensitive)
        if (params.searchQuery != null && params.searchQuery!.isNotEmpty) {
          queryBuilder.link(
            Budget_.category,
            Category_.name.contains(params.searchQuery!, caseSensitive: false),
          );
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

        // * Halaman langsung dari query + 1 baris look-ahead (P03)
        final offset = params.cursor != null
            ? int.tryParse(params.cursor!) ?? 0
            : 0;
        final results = queryBuilder.findPageAndClose(
          offset: offset,
          limit: params.limit + 1,
        );

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
        final progress = _computeProgressBatch([budget], now ?? DateTime.now());
        return Success(data: progress[budget.ulid]!);
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

  @override
  TaskEither<Failure, Success<Map<String, BudgetProgress>>> getBudgetsProgress({
    required List<Budget> budgets,
    DateTime? now,
  }) {
    return TaskEither.tryCatch(
      () async =>
          Success(data: _computeProgressBatch(budgets, now ?? DateTime.now())),
      (error, stackTrace) {
        logError('Gagal menghitung realisasi anggaran', error, stackTrace);
        return const Failure(message: 'Gagal menghitung realisasi anggaran.');
      },
    );
  }

  /// * spent = transaksi arah expense di [start, end) atas kategori anggaran
  ///   beserta seluruh turunannya; tanpa kategori = semua expense.
  /// * Tanggal efektif = transactionDate ?? createdAt (F6).
  /// * Nominal sudah tersimpan dalam mata uang penanda DB (CurrencyMarker),
  ///   jadi tidak ada konversi; dijumlah dalam satuan minor mata uang itu.
  /// * F7: satu panggilan berbagi kerja untuk semua anggaran — satu baca
  ///   mata uang, satu muat pohon kategori, satu query transaksi per rentang
  ///   periode berbeda. Tidak ada cache lintas panggilan, jadi setiap
  ///   refresh membaca ulang store (invalidasi deterministik).
  Map<String, BudgetProgress> _computeProgressBatch(
    List<Budget> budgets,
    DateTime now,
  ) {
    if (budgets.isEmpty) return const {};
    final digits = _storedCurrency().decimalDigits;

    // * Pohon kategori dimuat sekali, hanya bila ada anggaran berkategori
    final needsTree = budgets.any((b) => b.category.targetId != 0);
    final children = <int, List<int>>{};
    final known = <int>{};
    if (needsTree) {
      for (final c in _categoryBox.getAll()) {
        known.add(c.id);
        final parentId = c.parent.targetId;
        if (parentId != 0) (children[parentId] ??= []).add(c.id);
      }
    }
    final descendantsOf = <int, Set<int>>{};
    Set<int>? categoryIdsOf(Budget b) {
      final rootId = b.category.targetId;
      // * Relasi kosong/menggantung = tanpa kategori (perilaku sebelumnya)
      if (rootId == 0 || !known.contains(rootId)) return null;
      return descendantsOf[rootId] ??= _descendantIds(rootId, children);
    }

    // * Satu query transaksi per rentang periode yang berbeda
    final expensesByRange = <BudgetPeriodRange, List<Transaction>>{};
    final result = <String, BudgetProgress>{};
    for (final budget in budgets) {
      final range = BudgetPeriodRange.of(budget, now: now);
      final expenses = expensesByRange[range] ??= _expensesIn(range);
      final categoryIds = categoryIdsOf(budget);

      var spentMinor = 0;
      for (final t in expenses) {
        if (categoryIds != null && !categoryIds.contains(t.category.targetId)) {
          continue;
        }
        spentMinor += BudgetProgress.toMinor(t.amount, digits);
      }

      result[budget.ulid] = BudgetProgress(
        spentMinor: spentMinor,
        limitMinor: BudgetProgress.toMinor(budget.amountLimit, digits),
        decimalDigits: digits,
        period: range,
      );
    }
    return result;
  }

  /// Transaksi arah expense dengan tanggal efektif di [start, end)
  List<Transaction> _expensesIn(BudgetPeriodRange range) {
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
    return [
      for (final t in transactions)
        if (t.isExpense) t,
    ];
  }

  /// Kategori akar + semua turunan (lewat peta anak), aman terhadap siklus
  Set<int> _descendantIds(int rootId, Map<int, List<int>> children) {
    final result = <int>{rootId};
    final queue = <int>[rootId];
    while (queue.isNotEmpty) {
      for (final child in children[queue.removeLast()] ?? const <int>[]) {
        if (result.add(child)) queue.add(child);
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
