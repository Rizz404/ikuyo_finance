// Regression: NEW-3 (budgets count a legacy undated transaction on its
// createdAt day - effective date = transactionDate ?? createdAt, F6 - while
// statistics, the date-filtered transaction list and the date-filtered export
// skipped it, so the same expense was in the budget but missing elsewhere).
// One effective-date rule everywhere: an explicit transactionDate wins, and
// createdAt is used only when transactionDate is null. Stored data is never
// rewritten. Period ends keep each caller's existing inclusive last
// millisecond. Real ObjectBox + real repositories.
import 'dart:io';

import 'package:excel_community/excel_community.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/budget/repositories/budget_repository_impl.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/export/models/export_params.dart';
import 'package:ikuyo_finance/features/export/repositories/export_repository_impl.dart';
import 'package:ikuyo_finance/features/statistic/models/get_statistic_params.dart';
import 'package:ikuyo_finance/features/statistic/models/statistic_period.dart';
import 'package:ikuyo_finance/features/transaction/models/get_transactions_params.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/features/transaction/repositories/transaction_repository_impl.dart';

import '../support/objectbox_test_store.dart';
import '../support/test_logger.dart';

void main() {
  setUpAll(bootstrapTestLogger);

  late ObjectBoxTestStore store;
  late Asset cash;
  late Category food;

  setUp(() async {
    store = await ObjectBoxTestStore.open();
    cash = Asset(name: 'Cash', type: 0, balance: 0);
    store.storage.box<Asset>().put(cash);
    food = Category(name: 'Food', type: CategoryType.expense.index);
    store.storage.box<Category>().put(food);
  });
  tearDown(() => store.close());

  // * Legacy row: no transactionDate, only createdAt (pre-F6 data)
  Transaction put(double amount, {DateTime? date, required DateTime created}) {
    final t =
        Transaction(
            amount: amount,
            type: CategoryType.expense.index,
            transactionDate: date,
            createdAt: created,
            updatedAt: created,
          )
          ..asset.target = cash
          ..category.target = food;
    store.storage.box<Transaction>().put(t);
    return t;
  }

  final jan = StatisticPeriod.monthly(referenceDate: DateTime(2026, 1, 15));

  /// Seeds the shared January fixture; returns expected January total (11).
  void seedJanuary() {
    // * undated legacy rows: first and last millisecond of January count
    put(1, created: DateTime(2026, 1, 1));
    put(2, created: DateTime(2026, 1, 31, 23, 59, 59, 999));
    // * undated legacy rows just outside January do not
    put(100, created: DateTime(2025, 12, 31, 23, 59, 59, 999));
    put(200, created: DateTime(2026, 2, 1));
    // * explicit date wins over createdAt in both directions
    put(8, date: DateTime(2026, 1, 20), created: DateTime(2026, 2, 3));
    put(400, date: DateTime(2026, 2, 3), created: DateTime(2026, 1, 20));
  }

  Future<double> statisticExpense(StatisticPeriod p) async {
    final r = await TransactionRepositoryImpl(store.storage)
        .getStatisticSummary(
          GetStatisticParams(startDate: p.startDate, endDate: p.endDate),
        )
        .run();
    return r.getOrElse((f) => throw Exception(f.message)).data!.totalExpense;
  }

  Future<List<double>> listed({DateTime? start, DateTime? end}) async {
    final r = await TransactionRepositoryImpl(store.storage)
        .getTransactions(
          GetTransactionsParams(startDate: start, endDate: end, limit: 100),
        )
        .run();
    return r
        .getOrElse((f) => throw Exception(f.message))
        .data!
        .map((t) => t.amount)
        .toList()
      ..sort();
  }

  test(
    'NEW-3 statistics use the budget effective date for undated rows',
    () async {
      seedJanuary();
      expect(await statisticExpense(jan), 11);
      expect(
        await statisticExpense(
          StatisticPeriod.monthly(referenceDate: DateTime(2026, 2, 10)),
        ),
        600,
      );
    },
  );

  test(
    'NEW-3 statistics agree with the budget progress for the same month',
    () async {
      seedJanuary();
      final budget = Budget(amountLimit: 1000)..category.target = food;
      store.storage.box<Budget>().put(budget);
      final progress = await BudgetRepositoryImpl(
        store.storage,
      ).getBudgetProgress(ulid: budget.ulid, now: DateTime(2026, 1, 15)).run();
      final spent = progress.getOrElse((f) => throw Exception(f.message)).data!;
      expect(spent.spent, 11);
      expect(await statisticExpense(jan), spent.spent);
    },
  );

  test('NEW-3 the date-filtered transaction list includes undated rows by '
      'createdAt, explicit date first', () async {
    seedJanuary();
    expect(await listed(start: jan.startDate, end: jan.endDate), [1, 2, 8]);
    // * open-ended ranges follow the same rule
    expect(await listed(start: DateTime(2026, 2, 1)), [200, 400]);
    expect(await listed(end: DateTime(2025, 12, 31, 23, 59, 59, 999)), [100]);
    // * no date filter still lists everything
    expect(await listed(), [1, 2, 8, 100, 200, 400]);
  });

  test(
    'NEW-3 stored transactionDate stays null (no historical rewrite)',
    () async {
      seedJanuary();
      await statisticExpense(jan);
      await listed(start: jan.startDate, end: jan.endDate);
      final undated = store.storage
          .box<Transaction>()
          .getAll()
          .where((t) => t.transactionDate == null)
          .length;
      expect(undated, 4);
    },
  );

  test(
    'NEW-3 the date-filtered export includes undated rows by createdAt',
    () async {
      seedJanuary();
      final dir = Directory.systemTemp.createTempSync('ikuyo_new3_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final r = await ExportRepositoryImpl(store.storage)
          .exportToExcel(
            params: ExportParams(
              startDate: DateTime(2026, 1, 1),
              endDate: DateTime(2026, 1, 31),
            ),
            exportDirectory: dir.path,
            labels: const {},
            currencySymbol: 'Rp',
          )
          .run();
      final path = r.getOrElse((f) => throw Exception(f.message)).data!;
      final sheet = Excel.decodeBytes(
        File(path).readAsBytesSync(),
      ).tables['Transactions']!;
      // * data rows: column 0 is the row number (blank row ends the data)
      final amounts = <String>[];
      for (final row in sheet.rows.skip(1)) {
        if (row.isEmpty || row[0]?.value == null) break;
        if (int.tryParse(row[0]!.value.toString()) == null) break;
        amounts.add(row[7]!.value.toString());
      }
      expect(amounts..sort(), ['Rp 1', 'Rp 2', 'Rp 8']);
    },
  );
}
