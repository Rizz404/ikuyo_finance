// Regression: CSE-9 / CSE-10 (period boundaries). A transaction in the last
// second of a period (23:59:59.500) must be included; weekly start must be
// computed on calendar days. Real ObjectBox + real repository.
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/statistic/models/get_statistic_params.dart';
import 'package:ikuyo_finance/features/statistic/models/statistic_period.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/features/transaction/repositories/transaction_repository_impl.dart';

import '../support/objectbox_test_store.dart';
import '../support/test_logger.dart';

void main() {
  setUpAll(bootstrapTestLogger);

  late ObjectBoxTestStore store;
  setUp(() async => store = await ObjectBoxTestStore.open());
  tearDown(() => store.close());

  test('monthly statistics include a transaction in the final second',
      () async {
    final asset = Asset(name: 'Cash', type: 0, balance: 0);
    store.storage.box<Asset>().put(asset);
    final cat = Category(name: 'Food', type: CategoryType.expense.index);
    store.storage.box<Category>().put(cat);
    store.storage.box<Transaction>().put(
      Transaction(
        amount: 50,
        transactionDate: DateTime(2026, 1, 31, 23, 59, 59, 500),
      )
        ..asset.target = asset
        ..category.target = cat,
    );

    final period = StatisticPeriod.monthly(referenceDate: DateTime(2026, 1, 15));
    final result = await TransactionRepositoryImpl(store.storage)
        .getStatisticSummary(
          GetStatisticParams(
            startDate: period.startDate,
            endDate: period.endDate,
          ),
        )
        .run();
    expect(result.getOrElse((f) => throw f).data!.totalExpense, 50);
  });

  test('every period end is the last millisecond of its final day', () {
    final ref = DateTime(2026, 3, 18);
    for (final p in [
      StatisticPeriod.weekly(referenceDate: ref),
      StatisticPeriod.monthly(referenceDate: ref),
      StatisticPeriod.yearly(referenceDate: ref),
      StatisticPeriod.custom(startDate: ref, endDate: ref),
    ]) {
      final e = p.endDate;
      expect(
        e.add(const Duration(milliseconds: 1)),
        DateTime(e.year, e.month, e.day + 1),
        reason: '${p.type}',
      );
    }
  });
}
