import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/asset/models/create_asset_params.dart';
import 'package:ikuyo_finance/features/asset/repositories/asset_repository_impl.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/category/models/create_category_params.dart';
import 'package:ikuyo_finance/features/category/repositories/category_repository_impl.dart';
import 'package:ikuyo_finance/features/transaction/bloc/transaction_bloc.dart';
import 'package:ikuyo_finance/features/transaction/models/create_transaction_params.dart';
import 'package:ikuyo_finance/features/transaction/models/get_transactions_params.dart';
import 'package:ikuyo_finance/features/transaction/models/update_transaction_params.dart';
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

  group('TransactionFetched', () {
    blocTest<TransactionBloc, TransactionState>(
      'emits [loading, success] with transactions in the requested range',
      setUp: () async {
        final asset = await createAsset();
        await repository
            .createTransaction(
              CreateTransactionParams(
                assetUlid: asset.ulid,
                amount: 100,
                transactionDate: DateTime(2026, 1, 10),
              ),
            )
            .run();
      },
      build: () => TransactionBloc(repository),
      act: (bloc) => bloc.add(
        TransactionFetched(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31)),
      ),
      expect: () => [
        predicate<TransactionState>((s) => s.status == TransactionStatus.loading),
        predicate<TransactionState>(
          (s) => s.status == TransactionStatus.success && s.transactions.length == 1,
        ),
      ],
    );

    blocTest<TransactionBloc, TransactionState>(
      'emits an empty success state when nothing matches',
      build: () => TransactionBloc(repository),
      act: (bloc) => bloc.add(
        TransactionFetched(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31)),
      ),
      expect: () => [
        predicate<TransactionState>((s) => s.status == TransactionStatus.loading),
        predicate<TransactionState>(
          (s) => s.status == TransactionStatus.success && s.transactions.isEmpty,
        ),
      ],
    );

    blocTest<TransactionBloc, TransactionState>(
      'defaults to the current month when no explicit date range is given',
      setUp: () async {
        final asset = await createAsset();
        await repository
            .createTransaction(
              CreateTransactionParams(
                assetUlid: asset.ulid,
                amount: 100,
                transactionDate: DateTime.now(),
              ),
            )
            .run();
      },
      build: () => TransactionBloc(repository),
      act: (bloc) => bloc.add(const TransactionFetched()),
      expect: () => [
        predicate<TransactionState>((s) => s.status == TransactionStatus.loading),
        predicate<TransactionState>(
          (s) => s.status == TransactionStatus.success && s.transactions.length == 1,
        ),
      ],
    );
  });

  group('TransactionFetchedMore', () {
    blocTest<TransactionBloc, TransactionState>(
      'loads the next page and appends it to the existing list',
      setUp: () async {
        final asset = await createAsset();
        for (var i = 0; i < 25; i++) {
          await repository
              .createTransaction(
                CreateTransactionParams(
                  assetUlid: asset.ulid,
                  amount: (i + 1).toDouble(),
                  transactionDate: DateTime(2026, 1, 1 + i % 28),
                ),
              )
              .run();
        }
      },
      build: () => TransactionBloc(repository),
      act: (bloc) async {
        bloc.add(
          TransactionFetched(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31)),
        );
        await bloc.stream.firstWhere((s) => s.status == TransactionStatus.success);
        bloc.add(const TransactionFetchedMore());
      },
      skip: 2,
      expect: () => [
        predicate<TransactionState>((s) => s.status == TransactionStatus.loadingMore),
        predicate<TransactionState>(
          (s) =>
              s.status == TransactionStatus.success &&
              s.transactions.length == 25 &&
              s.hasReachedMax,
        ),
      ],
    );

    blocTest<TransactionBloc, TransactionState>(
      'does nothing when hasReachedMax is already true',
      seed: () => TransactionState(hasReachedMax: true),
      build: () => TransactionBloc(repository),
      act: (bloc) => bloc.add(const TransactionFetchedMore()),
      expect: () => [],
    );
  });

  group('TransactionRefreshed', () {
    blocTest<TransactionBloc, TransactionState>(
      'resets pagination and re-fetches with current filters',
      setUp: () async {
        final asset = await createAsset();
        await repository
            .createTransaction(
              CreateTransactionParams(
                assetUlid: asset.ulid,
                amount: 100,
                transactionDate: DateTime(2026, 1, 10),
              ),
            )
            .run();
      },
      build: () => TransactionBloc(repository),
      seed: () => TransactionState(
        currentStartDateFilter: DateTime(2026, 1, 1),
        currentEndDateFilter: DateTime(2026, 1, 31),
      ),
      act: (bloc) => bloc.add(const TransactionRefreshed()),
      expect: () => [
        predicate<TransactionState>((s) => s.status == TransactionStatus.loading),
        predicate<TransactionState>(
          (s) => s.status == TransactionStatus.success && s.transactions.length == 1,
        ),
      ],
    );
  });

  group('TransactionSearched', () {
    blocTest<TransactionBloc, TransactionState>(
      'debounces and filters by description',
      setUp: () async {
        final asset = await createAsset();
        await repository
            .createTransaction(
              CreateTransactionParams(
                assetUlid: asset.ulid,
                amount: 100,
                description: 'Groceries',
              ),
            )
            .run();
        await repository
            .createTransaction(
              CreateTransactionParams(
                assetUlid: asset.ulid,
                amount: 50,
                description: 'Fuel',
              ),
            )
            .run();
      },
      build: () => TransactionBloc(repository),
      act: (bloc) => bloc.add(const TransactionSearched(query: 'groc')),
      wait: const Duration(milliseconds: 350),
      expect: () => [
        predicate<TransactionState>((s) => s.status == TransactionStatus.loading),
        predicate<TransactionState>(
          (s) =>
              s.status == TransactionStatus.success &&
              s.transactions.length == 1 &&
              s.transactions.first.description == 'Groceries',
        ),
      ],
    );
  });

  group('TransactionFiltered', () {
    blocTest<TransactionBloc, TransactionState>(
      'applies asset/date/amount filters at once',
      setUp: () async {
        final assetA = await createAsset(name: 'Cash');
        final assetB = await createAsset(name: 'Bank');
        await repository
            .createTransaction(
              CreateTransactionParams(assetUlid: assetA.ulid, amount: 100),
            )
            .run();
        await repository
            .createTransaction(
              CreateTransactionParams(assetUlid: assetB.ulid, amount: 200),
            )
            .run();
      },
      build: () => TransactionBloc(repository),
      act: (bloc) async {
        final asset = (await repository.getTransactions(const GetTransactionsParams()).run())
            .getOrElse((_) => throw Exception())
            .data!
            .firstWhere((t) => t.amount == 100)
            .asset
            .target!;
        bloc.add(TransactionFiltered(assetUlid: asset.ulid));
      },
      expect: () => [
        predicate<TransactionState>((s) => s.status == TransactionStatus.loading),
        predicate<TransactionState>(
          (s) => s.status == TransactionStatus.success && s.transactions.length == 1,
        ),
      ],
    );

    blocTest<TransactionBloc, TransactionState>(
      'filters by categoryUlid',
      build: () => TransactionBloc(repository),
      act: (bloc) async {
        final asset = await createAsset();
        final food = await createCategory(name: 'Food', type: CategoryType.expense);
        final salary = await createCategory(name: 'Salary', type: CategoryType.income);
        await repository
            .createTransaction(
              CreateTransactionParams(
                assetUlid: asset.ulid,
                categoryUlid: food.ulid,
                amount: 30,
              ),
            )
            .run();
        await repository
            .createTransaction(
              CreateTransactionParams(
                assetUlid: asset.ulid,
                categoryUlid: salary.ulid,
                amount: 500,
              ),
            )
            .run();
        bloc.add(TransactionFiltered(categoryUlid: food.ulid));
      },
      expect: () => [
        predicate<TransactionState>((s) => s.status == TransactionStatus.loading),
        predicate<TransactionState>(
          (s) =>
              s.status == TransactionStatus.success &&
              s.transactions.length == 1 &&
              s.transactions.single.amount == 30,
        ),
      ],
    );
  });

  group('TransactionSorted', () {
    blocTest<TransactionBloc, TransactionState>(
      'sorts by amount ascending',
      setUp: () async {
        final asset = await createAsset();
        await repository
            .createTransaction(CreateTransactionParams(assetUlid: asset.ulid, amount: 300))
            .run();
        await repository
            .createTransaction(CreateTransactionParams(assetUlid: asset.ulid, amount: 100))
            .run();
      },
      build: () => TransactionBloc(repository),
      act: (bloc) => bloc.add(
        const TransactionSorted(sortBy: TransactionSortBy.amount, sortOrder: SortOrder.ascending),
      ),
      expect: () => [
        predicate<TransactionState>((s) => s.status == TransactionStatus.loading),
        predicate<TransactionState>(
          (s) =>
              s.status == TransactionStatus.success &&
              s.transactions.map((t) => t.amount).toList().first == 100,
        ),
      ],
    );
  });

  group('TransactionFilterCleared', () {
    blocTest<TransactionBloc, TransactionState>(
      'resets filters and sort back to defaults',
      build: () => TransactionBloc(repository),
      seed: () => TransactionState(
        currentAssetFilter: 'some-asset',
        currentSearchQuery: 'foo',
        currentSortBy: TransactionSortBy.amount,
        currentSortOrder: SortOrder.ascending,
      ),
      act: (bloc) => bloc.add(const TransactionFilterCleared()),
      expect: () => [
        predicate<TransactionState>((s) => s.status == TransactionStatus.loading),
        predicate<TransactionState>(
          (s) =>
              s.status == TransactionStatus.success &&
              s.currentAssetFilter == null &&
              s.currentSearchQuery == null &&
              s.currentSortBy == TransactionSortBy.transactionDate &&
              s.currentSortOrder == SortOrder.descending,
        ),
      ],
    );
  });

  group('TransactionMonthChanged', () {
    blocTest<TransactionBloc, TransactionState>(
      'fetches transactions for the newly selected month',
      setUp: () async {
        final asset = await createAsset();
        await repository
            .createTransaction(
              CreateTransactionParams(
                assetUlid: asset.ulid,
                amount: 100,
                transactionDate: DateTime(2025, 3, 15),
              ),
            )
            .run();
      },
      build: () => TransactionBloc(repository),
      act: (bloc) => bloc.add(TransactionMonthChanged(month: DateTime(2025, 3))),
      expect: () => [
        predicate<TransactionState>((s) => s.status == TransactionStatus.loading),
        predicate<TransactionState>(
          (s) =>
              s.status == TransactionStatus.success &&
              s.transactions.length == 1 &&
              s.currentMonth.month == 3,
        ),
      ],
    );
  });

  group('TransactionYearChanged', () {
    blocTest<TransactionBloc, TransactionState>(
      'fetches transactions for the newly selected year',
      setUp: () async {
        final asset = await createAsset();
        await repository
            .createTransaction(
              CreateTransactionParams(
                assetUlid: asset.ulid,
                amount: 100,
                transactionDate: DateTime(2024, 6, 1),
              ),
            )
            .run();
      },
      build: () => TransactionBloc(repository),
      act: (bloc) => bloc.add(const TransactionYearChanged(year: 2024)),
      expect: () => [
        predicate<TransactionState>((s) => s.status == TransactionStatus.loading),
        predicate<TransactionState>(
          (s) =>
              s.status == TransactionStatus.success &&
              s.transactions.length == 1 &&
              s.currentYear == 2024,
        ),
      ],
    );
  });

  group('TransactionCreated', () {
    blocTest<TransactionBloc, TransactionState>(
      'emits [writeLoading, writeSuccess] and prepends the new transaction',
      build: () => TransactionBloc(repository),
      act: (bloc) async {
        final asset = await createAsset();
        bloc.add(
          TransactionCreated(
            params: CreateTransactionParams(assetUlid: asset.ulid, amount: 42),
          ),
        );
      },
      expect: () => [
        predicate<TransactionState>((s) => s.writeStatus == TransactionWriteStatus.loading),
        predicate<TransactionState>(
          (s) =>
              s.writeStatus == TransactionWriteStatus.success &&
              s.transactions.length == 1 &&
              s.transactions.first.amount == 42,
        ),
      ],
    );

    blocTest<TransactionBloc, TransactionState>(
      'emits [writeLoading, writeFailure] when the asset does not exist',
      build: () => TransactionBloc(repository),
      act: (bloc) => bloc.add(
        const TransactionCreated(
          params: CreateTransactionParams(assetUlid: 'unknown', amount: 42),
        ),
      ),
      expect: () => [
        predicate<TransactionState>((s) => s.writeStatus == TransactionWriteStatus.loading),
        predicate<TransactionState>((s) => s.writeStatus == TransactionWriteStatus.failure),
      ],
    );
  });

  group('TransactionBulkCreated', () {
    blocTest<TransactionBloc, TransactionState>(
      'emits [writeLoading, writeSuccess] and prepends all created transactions',
      build: () => TransactionBloc(repository),
      act: (bloc) async {
        final asset = await createAsset();
        bloc.add(
          TransactionBulkCreated(
            paramsList: [
              CreateTransactionParams(assetUlid: asset.ulid, amount: 10),
              CreateTransactionParams(assetUlid: asset.ulid, amount: 20),
            ],
          ),
        );
      },
      expect: () => [
        predicate<TransactionState>((s) => s.writeStatus == TransactionWriteStatus.loading),
        predicate<TransactionState>(
          (s) =>
              s.writeStatus == TransactionWriteStatus.success &&
              s.transactions.length == 2 &&
              s.bulkCreateResult?.allSucceeded == true,
        ),
      ],
    );

    blocTest<TransactionBloc, TransactionState>(
      'still reports writeSuccess with a partial bulkCreateResult when some items fail',
      build: () => TransactionBloc(repository),
      act: (bloc) async {
        final asset = await createAsset();
        bloc.add(
          TransactionBulkCreated(
            paramsList: [
              const CreateTransactionParams(assetUlid: 'unknown-asset', amount: 10),
              CreateTransactionParams(assetUlid: asset.ulid, amount: 20),
            ],
          ),
        );
      },
      expect: () => [
        predicate<TransactionState>((s) => s.writeStatus == TransactionWriteStatus.loading),
        predicate<TransactionState>(
          (s) =>
              s.writeStatus == TransactionWriteStatus.success &&
              s.transactions.length == 1 &&
              s.bulkCreateResult?.hasFailures == true &&
              s.bulkCreateResult?.successCount == 1 &&
              s.bulkCreateResult?.failureCount == 1,
        ),
      ],
    );
  });

  group('TransactionUpdated', () {
    blocTest<TransactionBloc, TransactionState>(
      'replaces the matching transaction in the list on success',
      setUp: () async {
        final asset = await createAsset();
        await repository
            .createTransaction(
              CreateTransactionParams(
                assetUlid: asset.ulid,
                amount: 100,
                transactionDate: DateTime.now(),
              ),
            )
            .run();
      },
      build: () => TransactionBloc(repository),
      act: (bloc) async {
        bloc.add(const TransactionFetched());
        await bloc.stream.firstWhere((s) => s.status == TransactionStatus.success);
        final ulid = bloc.state.transactions.single.ulid;
        bloc.add(TransactionUpdated(params: UpdateTransactionParams(ulid: ulid, amount: 250)));
      },
      skip: 2,
      expect: () => [
        predicate<TransactionState>((s) => s.writeStatus == TransactionWriteStatus.loading),
        predicate<TransactionState>(
          (s) =>
              s.writeStatus == TransactionWriteStatus.success &&
              s.transactions.single.amount == 250,
        ),
      ],
    );

    blocTest<TransactionBloc, TransactionState>(
      'emits writeFailure for an unknown ulid',
      build: () => TransactionBloc(repository),
      act: (bloc) => bloc.add(
        const TransactionUpdated(params: UpdateTransactionParams(ulid: 'unknown', amount: 10)),
      ),
      expect: () => [
        predicate<TransactionState>((s) => s.writeStatus == TransactionWriteStatus.loading),
        predicate<TransactionState>((s) => s.writeStatus == TransactionWriteStatus.failure),
      ],
    );
  });

  group('TransactionDeleted', () {
    blocTest<TransactionBloc, TransactionState>(
      'removes the transaction from the list on success',
      setUp: () async {
        final asset = await createAsset();
        await repository
            .createTransaction(
              CreateTransactionParams(
                assetUlid: asset.ulid,
                amount: 100,
                transactionDate: DateTime.now(),
              ),
            )
            .run();
      },
      build: () => TransactionBloc(repository),
      act: (bloc) async {
        bloc.add(const TransactionFetched());
        await bloc.stream.firstWhere((s) => s.status == TransactionStatus.success);
        final ulid = bloc.state.transactions.single.ulid;
        bloc.add(TransactionDeleted(ulid: ulid));
      },
      skip: 2,
      expect: () => [
        predicate<TransactionState>((s) => s.writeStatus == TransactionWriteStatus.loading),
        predicate<TransactionState>(
          (s) => s.writeStatus == TransactionWriteStatus.success && s.transactions.isEmpty,
        ),
      ],
    );

    blocTest<TransactionBloc, TransactionState>(
      'emits writeFailure for an unknown ulid',
      build: () => TransactionBloc(repository),
      act: (bloc) => bloc.add(const TransactionDeleted(ulid: 'unknown')),
      expect: () => [
        predicate<TransactionState>((s) => s.writeStatus == TransactionWriteStatus.loading),
        predicate<TransactionState>((s) => s.writeStatus == TransactionWriteStatus.failure),
      ],
    );
  });

  group('TransactionBatchDeleted', () {
    blocTest<TransactionBloc, TransactionState>(
      'removes all transactions and reports writeSuccess when every id is valid',
      build: () => TransactionBloc(repository),
      act: (bloc) async {
        final asset = await createAsset();
        final first = (await repository
                .createTransaction(CreateTransactionParams(assetUlid: asset.ulid, amount: 10))
                .run())
            .getOrElse((_) => throw Exception())
            .data!;
        final second = (await repository
                .createTransaction(CreateTransactionParams(assetUlid: asset.ulid, amount: 20))
                .run())
            .getOrElse((_) => throw Exception())
            .data!;
        bloc.add(const TransactionFetched());
        await bloc.stream.firstWhere((s) => s.status == TransactionStatus.success);
        bloc.add(TransactionBatchDeleted(ulids: [first.ulid, second.ulid]));
      },
      skip: 2,
      expect: () => [
        predicate<TransactionState>((s) => s.writeStatus == TransactionWriteStatus.loading),
        predicate<TransactionState>(
          (s) => s.writeStatus == TransactionWriteStatus.success && s.transactions.isEmpty,
        ),
      ],
    );

    blocTest<TransactionBloc, TransactionState>(
      'reports writeFailure but still drops the ids that were deleted successfully',
      build: () => TransactionBloc(repository),
      act: (bloc) async {
        final asset = await createAsset();
        final created = (await repository
                .createTransaction(CreateTransactionParams(assetUlid: asset.ulid, amount: 10))
                .run())
            .getOrElse((_) => throw Exception())
            .data!;
        bloc.add(const TransactionFetched());
        await bloc.stream.firstWhere((s) => s.status == TransactionStatus.success);
        bloc.add(TransactionBatchDeleted(ulids: [created.ulid, 'unknown-ulid']));
      },
      skip: 2,
      expect: () => [
        predicate<TransactionState>((s) => s.writeStatus == TransactionWriteStatus.loading),
        predicate<TransactionState>(
          (s) => s.writeStatus == TransactionWriteStatus.failure && s.transactions.isEmpty,
        ),
      ],
    );
  });

  group('TransactionWriteStatusReset', () {
    blocTest<TransactionBloc, TransactionState>(
      'clears write status and messages back to initial',
      build: () => TransactionBloc(repository),
      seed: () => TransactionState(
        writeStatus: TransactionWriteStatus.success,
        writeAction: TransactionWriteAction.create,
        writeSuccessMessage: 'done',
      ),
      act: (bloc) => bloc.add(const TransactionWriteStatusReset()),
      expect: () => [
        predicate<TransactionState>(
          (s) =>
              s.writeStatus == TransactionWriteStatus.initial &&
              s.writeAction == TransactionWriteAction.none &&
              s.writeSuccessMessage == null &&
              s.lastCreatedTransaction == null,
        ),
      ],
    );
  });

  group('searchTransactionsForDropdown', () {
    test('returns matching transactions without touching bloc state', () async {
      final asset = await createAsset();
      await repository
          .createTransaction(
            CreateTransactionParams(
              assetUlid: asset.ulid,
              amount: 10,
              description: 'Coffee',
            ),
          )
          .run();
      await repository
          .createTransaction(
            CreateTransactionParams(
              assetUlid: asset.ulid,
              amount: 20,
              description: 'Taxi',
            ),
          )
          .run();

      final bloc = TransactionBloc(repository);
      final results = await bloc.searchTransactionsForDropdown(query: 'coff');

      expect(results, hasLength(1));
      expect(results.single.description, 'Coffee');
      // * currentMonth defaults to DateTime.now() per-instance, so compare
      // * the fields that matter instead of full-state equality against a
      // * freshly constructed TransactionState().
      expect(bloc.state.status, TransactionStatus.initial);
      expect(bloc.state.transactions, isEmpty);
      expect(bloc.state.writeStatus, TransactionWriteStatus.initial);
      await bloc.close();
    });
  });
}
