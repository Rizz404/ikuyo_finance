import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/asset/models/create_asset_params.dart';
import 'package:ikuyo_finance/features/asset/repositories/asset_repository_impl.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/category/models/create_category_params.dart';
import 'package:ikuyo_finance/features/category/repositories/category_repository_impl.dart';
import 'package:ikuyo_finance/features/statistic/bloc/statistic_bloc.dart';
import 'package:ikuyo_finance/features/statistic/models/statistic_period.dart';
import 'package:ikuyo_finance/features/transaction/models/create_transaction_params.dart';
import 'package:ikuyo_finance/features/transaction/repositories/transaction_repository_impl.dart';

import '../../../support/fake_app_file_storage.dart';
import '../../../support/objectbox_test_store.dart';
import '../../../support/test_logger.dart';

void main() {
  setUpAll(bootstrapTestLogger);

  late ObjectBoxTestStore testStore;
  late FakeAppFileStorage fileStorage;
  late AssetRepositoryImpl assetRepository;
  late CategoryRepositoryImpl categoryRepository;
  late TransactionRepositoryImpl repository;

  setUp(() async {
    testStore = await ObjectBoxTestStore.open();
    fileStorage = FakeAppFileStorage();
    assetRepository = AssetRepositoryImpl(testStore.storage, fileStorage);
    categoryRepository = CategoryRepositoryImpl(testStore.storage, fileStorage);
    repository = TransactionRepositoryImpl(testStore.storage);
  });

  tearDown(() => testStore.close());

  Future<Asset> createAsset({
    String name = 'Cash',
    AssetType type = AssetType.cash,
    double balance = 0,
  }) async {
    final result = await assetRepository
        .createAsset(CreateAssetParams(name: name, type: type, balance: balance))
        .run();
    return result.getOrElse((_) => throw Exception()).data!;
  }

  Future<Category> createCategory({
    required String name,
    required CategoryType type,
  }) async {
    final result = await categoryRepository
        .createCategory(CreateCategoryParams(name: name, type: type))
        .run();
    return result.getOrElse((_) => throw Exception()).data!;
  }

  group('StatisticFetched', () {
    blocTest<StatisticBloc, StatisticState>(
      'emits [loading, success] with the aggregated summary for the current period',
      setUp: () async {
        final asset = await createAsset();
        final salary = await createCategory(name: 'Salary', type: CategoryType.income);
        await repository
            .createTransaction(
              CreateTransactionParams(
                assetUlid: asset.ulid,
                categoryUlid: salary.ulid,
                amount: 1000,
                transactionDate: DateTime.now(),
              ),
            )
            .run();
      },
      build: () => StatisticBloc(repository),
      act: (bloc) => bloc.add(const StatisticFetched()),
      expect: () => [
        predicate<StatisticState>((s) => s.status == StatisticStatus.loading),
        predicate<StatisticState>(
          (s) =>
              s.status == StatisticStatus.success &&
              s.summary.totalIncome == 1000 &&
              s.hasData,
        ),
      ],
    );

    blocTest<StatisticBloc, StatisticState>(
      'emits an empty success state when there is no data in range',
      build: () => StatisticBloc(repository),
      act: (bloc) => bloc.add(const StatisticFetched()),
      expect: () => [
        predicate<StatisticState>((s) => s.status == StatisticStatus.loading),
        predicate<StatisticState>(
          (s) => s.status == StatisticStatus.success && !s.hasData,
        ),
      ],
    );

    blocTest<StatisticBloc, StatisticState>(
      'fetches with an explicit period overriding the current one',
      setUp: () async {
        final asset = await createAsset();
        final salary = await createCategory(name: 'Salary', type: CategoryType.income);
        await repository
            .createTransaction(
              CreateTransactionParams(
                assetUlid: asset.ulid,
                categoryUlid: salary.ulid,
                amount: 700,
                transactionDate: DateTime(2025, 6, 15),
              ),
            )
            .run();
      },
      build: () => StatisticBloc(repository),
      act: (bloc) => bloc.add(
        StatisticFetched(period: StatisticPeriod.monthly(referenceDate: DateTime(2025, 6, 1))),
      ),
      expect: () => [
        predicate<StatisticState>((s) => s.status == StatisticStatus.loading),
        predicate<StatisticState>(
          (s) =>
              s.status == StatisticStatus.success &&
              s.summary.totalIncome == 700 &&
              s.currentPeriod.type == StatisticPeriodType.monthly &&
              s.currentPeriod.startDate == DateTime(2025, 6, 1),
        ),
      ],
    );
  });

  group('StatisticPeriodChanged', () {
    blocTest<StatisticBloc, StatisticState>(
      'navigates to the previous month and fetches its data',
      setUp: () async {
        final asset = await createAsset();
        final food = await createCategory(name: 'Food', type: CategoryType.expense);
        await repository
            .createTransaction(
              CreateTransactionParams(
                assetUlid: asset.ulid,
                categoryUlid: food.ulid,
                amount: 250,
                transactionDate: DateTime(2026, 2, 10),
              ),
            )
            .run();
      },
      build: () => StatisticBloc(repository),
      seed: () =>
          StatisticState(currentPeriod: StatisticPeriod.monthly(referenceDate: DateTime(2026, 3, 1))),
      act: (bloc) => bloc.add(const StatisticPeriodChanged(isNext: false)),
      expect: () => [
        predicate<StatisticState>((s) => s.status == StatisticStatus.loading),
        predicate<StatisticState>(
          (s) =>
              s.status == StatisticStatus.success &&
              s.summary.totalExpense == 250 &&
              s.currentPeriod.startDate == DateTime(2026, 2, 1),
        ),
      ],
    );

    blocTest<StatisticBloc, StatisticState>(
      'navigates to the next month and fetches its data',
      setUp: () async {
        final asset = await createAsset();
        final food = await createCategory(name: 'Food', type: CategoryType.expense);
        await repository
            .createTransaction(
              CreateTransactionParams(
                assetUlid: asset.ulid,
                categoryUlid: food.ulid,
                amount: 90,
                transactionDate: DateTime(2026, 4, 5),
              ),
            )
            .run();
      },
      build: () => StatisticBloc(repository),
      seed: () =>
          StatisticState(currentPeriod: StatisticPeriod.monthly(referenceDate: DateTime(2026, 3, 1))),
      act: (bloc) => bloc.add(const StatisticPeriodChanged(isNext: true)),
      expect: () => [
        predicate<StatisticState>((s) => s.status == StatisticStatus.loading),
        predicate<StatisticState>(
          (s) =>
              s.status == StatisticStatus.success &&
              s.summary.totalExpense == 90 &&
              s.currentPeriod.startDate == DateTime(2026, 4, 1),
        ),
      ],
    );
  });

  group('StatisticPeriodTypeChanged', () {
    blocTest<StatisticBloc, StatisticState>(
      'switches to a yearly period and re-fetches',
      build: () => StatisticBloc(repository),
      act: (bloc) => bloc.add(const StatisticPeriodTypeChanged(type: StatisticPeriodType.yearly)),
      expect: () => [
        predicate<StatisticState>((s) => s.status == StatisticStatus.loading),
        predicate<StatisticState>(
          (s) =>
              s.status == StatisticStatus.success &&
              s.currentPeriod.type == StatisticPeriodType.yearly,
        ),
      ],
    );
  });

  group('StatisticCustomPeriodSet', () {
    blocTest<StatisticBloc, StatisticState>(
      'fetches the summary for the given custom date range',
      setUp: () async {
        final asset = await createAsset();
        final salary = await createCategory(name: 'Salary', type: CategoryType.income);
        await repository
            .createTransaction(
              CreateTransactionParams(
                assetUlid: asset.ulid,
                categoryUlid: salary.ulid,
                amount: 400,
                transactionDate: DateTime(2026, 5, 10),
              ),
            )
            .run();
      },
      build: () => StatisticBloc(repository),
      act: (bloc) => bloc.add(
        StatisticCustomPeriodSet(startDate: DateTime(2026, 5, 1), endDate: DateTime(2026, 5, 31)),
      ),
      expect: () => [
        predicate<StatisticState>((s) => s.status == StatisticStatus.loading),
        predicate<StatisticState>(
          (s) =>
              s.status == StatisticStatus.success &&
              s.summary.totalIncome == 400 &&
              s.currentPeriod.type == StatisticPeriodType.custom,
        ),
      ],
    );
  });

  group('StatisticRefreshed', () {
    blocTest<StatisticBloc, StatisticState>(
      're-fetches the currently selected period',
      setUp: () async {
        final asset = await createAsset();
        final salary = await createCategory(name: 'Salary', type: CategoryType.income);
        await repository
            .createTransaction(
              CreateTransactionParams(
                assetUlid: asset.ulid,
                categoryUlid: salary.ulid,
                amount: 999,
                transactionDate: DateTime(2026, 1, 15),
              ),
            )
            .run();
      },
      build: () => StatisticBloc(repository),
      seed: () =>
          StatisticState(currentPeriod: StatisticPeriod.monthly(referenceDate: DateTime(2026, 1, 1))),
      act: (bloc) => bloc.add(const StatisticRefreshed()),
      expect: () => [
        predicate<StatisticState>((s) => s.status == StatisticStatus.loading),
        predicate<StatisticState>(
          (s) => s.status == StatisticStatus.success && s.summary.totalIncome == 999,
        ),
      ],
    );
  });

  group('StatisticChartTypeChanged', () {
    blocTest<StatisticBloc, StatisticState>(
      'updates the chart type synchronously',
      build: () => StatisticBloc(repository),
      act: (bloc) => bloc.add(const StatisticChartTypeChanged(chartType: StatisticChartType.bar)),
      expect: () => [
        predicate<StatisticState>((s) => s.chartType == StatisticChartType.bar),
      ],
    );
  });
}
