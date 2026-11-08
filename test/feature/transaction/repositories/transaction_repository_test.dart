import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/asset/models/create_asset_params.dart';
import 'package:ikuyo_finance/features/asset/repositories/asset_repository_impl.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/category/models/create_category_params.dart';
import 'package:ikuyo_finance/features/category/repositories/category_repository_impl.dart';
import 'package:ikuyo_finance/features/statistic/models/get_statistic_params.dart';
import 'package:ikuyo_finance/features/transaction/models/create_transaction_params.dart';
import 'package:ikuyo_finance/features/transaction/models/get_transactions_params.dart';
import 'package:ikuyo_finance/features/transaction/models/update_transaction_params.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/features/transaction/repositories/transaction_repository_impl.dart';

import '../../../support/fake_app_file_storage.dart';
import '../../../support/locale_test_helper.dart';
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

  // * Helpers to set up real Asset/Category fixtures through their own
  // * real repository impls (Transaction has ToOne relations to both).
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

  group('createTransaction', () {
    test('persists a transaction linked to the asset and assigns a ulid', () async {
      final asset = await createAsset();

      final result = await repository
          .createTransaction(
            CreateTransactionParams(assetUlid: asset.ulid, amount: 100),
          )
          .run();

      expect(result.isRight(), isTrue);
      final transaction = result.getOrElse((_) => throw Exception()).data!;
      expect(transaction.ulid, isNotEmpty);
      expect(transaction.amount, 100);
      expect(transaction.asset.target?.ulid, asset.ulid);
      expect(transaction.category.target, isNull);
    });

    test(
      'F6 a save without a chosen date records its own creation instant',
      () async {
        final asset = await createAsset();

        final created =
            (await repository
                    .createTransaction(
                      CreateTransactionParams(assetUlid: asset.ulid, amount: 5),
                    )
                    .run())
                .getOrElse((_) => throw Exception())
                .data!;

        final stored = testStore.storage.box<Transaction>().get(created.id)!;
        expect(stored.transactionDate, isNotNull);
        expect(stored.transactionDate, stored.createdAt);
      },
    );

    test('F6 a chosen date is stored unchanged', () async {
      final asset = await createAsset();
      final chosen = DateTime(2025, 3, 4, 5, 6);

      final created =
          (await repository
                  .createTransaction(
                    CreateTransactionParams(
                      assetUlid: asset.ulid,
                      amount: 5,
                      transactionDate: chosen,
                    ),
                  )
                  .run())
              .getOrElse((_) => throw Exception())
              .data!;

      final stored = testStore.storage.box<Transaction>().get(created.id)!;
      expect(stored.transactionDate, chosen);
      expect(stored.createdAt, isNot(chosen));
    });

    test(
      'F6 bulk saves without a date also record their creation instant',
      () async {
        final asset = await createAsset();

        final bulk = (await repository.createManyTransactions([
          CreateTransactionParams(assetUlid: asset.ulid, amount: 1),
          CreateTransactionParams(assetUlid: asset.ulid, amount: 2),
        ]).run()).getOrElse((_) => throw Exception()).data!;

        for (final t in bulk.successfulTransactions) {
          final stored = testStore.storage.box<Transaction>().get(t.id)!;
          expect(stored.transactionDate, stored.createdAt);
        }
      },
    );

    test(
      'F6 updating without a date leaves an existing undated record alone',
      () async {
        final asset = await createAsset();
        final legacy = Transaction(
          amount: 9,
          createdAt: DateTime(2024, 6, 1),
          updatedAt: DateTime(2024, 6, 1),
        )..asset.target = asset;
        testStore.storage.box<Transaction>().put(legacy);

        await repository
            .updateTransaction(
              UpdateTransactionParams(ulid: legacy.ulid, description: 'x'),
            )
            .run();

        final stored = testStore.storage.box<Transaction>().get(legacy.id)!;
        expect(stored.transactionDate, isNull);
        expect(stored.createdAt, DateTime(2024, 6, 1));
      },
    );

    test('fails when the asset does not exist', () async {
      final result = await repository
          .createTransaction(
            const CreateTransactionParams(assetUlid: 'unknown-ulid', amount: 100),
          )
          .run();

      expect(result.isLeft(), isTrue);
    });

    test('links the category when categoryUlid is provided', () async {
      final asset = await createAsset();
      final category = await createCategory(name: 'Food', type: CategoryType.expense);

      final result = await repository
          .createTransaction(
            CreateTransactionParams(
              assetUlid: asset.ulid,
              categoryUlid: category.ulid,
              amount: 50,
            ),
          )
          .run();

      final transaction = result.getOrElse((_) => throw Exception()).data!;
      expect(transaction.category.target?.ulid, category.ulid);
    });

    test('fails when the category does not exist', () async {
      final asset = await createAsset();

      final result = await repository
          .createTransaction(
            CreateTransactionParams(
              assetUlid: asset.ulid,
              categoryUlid: 'unknown-category',
              amount: 50,
            ),
          )
          .run();

      expect(result.isLeft(), isTrue);
    });

    test('increases asset balance when there is no category (treated as income)', () async {
      final asset = await createAsset(balance: 0);

      await repository
          .createTransaction(
            CreateTransactionParams(assetUlid: asset.ulid, amount: 100),
          )
          .run();

      final updatedAsset = (await assetRepository.getAssetById(ulid: asset.ulid).run())
          .getOrElse((_) => throw Exception())
          .data!;
      expect(updatedAsset.balance, 100);
    });

    test('increases asset balance for an income category', () async {
      final asset = await createAsset(balance: 0);
      final category = await createCategory(name: 'Salary', type: CategoryType.income);

      await repository
          .createTransaction(
            CreateTransactionParams(
              assetUlid: asset.ulid,
              categoryUlid: category.ulid,
              amount: 200,
            ),
          )
          .run();

      final updatedAsset = (await assetRepository.getAssetById(ulid: asset.ulid).run())
          .getOrElse((_) => throw Exception())
          .data!;
      expect(updatedAsset.balance, 200);
    });

    test('decreases asset balance for an expense category', () async {
      final asset = await createAsset(balance: 100);
      final category = await createCategory(name: 'Food', type: CategoryType.expense);

      await repository
          .createTransaction(
            CreateTransactionParams(
              assetUlid: asset.ulid,
              categoryUlid: category.ulid,
              amount: 40,
            ),
          )
          .run();

      final updatedAsset = (await assetRepository.getAssetById(ulid: asset.ulid).run())
          .getOrElse((_) => throw Exception())
          .data!;
      expect(updatedAsset.balance, 60);
    });
  });

  group('createManyTransactions', () {
    test('creates all transactions and reports no failures', () async {
      final asset = await createAsset(balance: 0);
      final income = await createCategory(name: 'Salary', type: CategoryType.income);
      final expense = await createCategory(name: 'Food', type: CategoryType.expense);

      final result = await repository
          .createManyTransactions([
            CreateTransactionParams(
              assetUlid: asset.ulid,
              categoryUlid: income.ulid,
              amount: 100,
            ),
            CreateTransactionParams(
              assetUlid: asset.ulid,
              categoryUlid: expense.ulid,
              amount: 30,
            ),
          ])
          .run();

      expect(result.isRight(), isTrue);
      final bulkResult = result.getOrElse((_) => throw Exception()).data!;
      expect(bulkResult.successfulTransactions, hasLength(2));
      expect(bulkResult.failedTransactions, isEmpty);
      expect(bulkResult.allSucceeded, isTrue);
      expect(bulkResult.hasFailures, isFalse);
      expect(bulkResult.totalAttempted, 2);

      final updatedAsset = (await assetRepository.getAssetById(ulid: asset.ulid).run())
          .getOrElse((_) => throw Exception())
          .data!;
      expect(updatedAsset.balance, 70);
    });

    test('records a per-item failure when an asset is missing, without aborting the batch', () async {
      final asset = await createAsset(balance: 0);

      final result = await repository
          .createManyTransactions([
            CreateTransactionParams(assetUlid: 'unknown-asset', amount: 10),
            CreateTransactionParams(assetUlid: asset.ulid, amount: 20),
          ])
          .run();

      final bulkResult = result.getOrElse((_) => throw Exception()).data!;
      expect(bulkResult.successfulTransactions, hasLength(1));
      expect(bulkResult.failedTransactions, hasLength(1));
      expect(bulkResult.failedTransactions.single.index, 0);
      expect(bulkResult.failedTransactions.single.errorMessage, contains('tidak ditemukan'));
      expect(bulkResult.hasFailures, isTrue);
      expect(bulkResult.allSucceeded, isFalse);
      expect(bulkResult.totalAttempted, 2);
    });

    test('records a per-item failure when a category is missing', () async {
      final asset = await createAsset();

      final result = await repository
          .createManyTransactions([
            CreateTransactionParams(
              assetUlid: asset.ulid,
              categoryUlid: 'unknown-category',
              amount: 10,
            ),
          ])
          .run();

      final bulkResult = result.getOrElse((_) => throw Exception()).data!;
      expect(bulkResult.successfulTransactions, isEmpty);
      expect(bulkResult.failedTransactions, hasLength(1));
      expect(bulkResult.failedTransactions.single.errorMessage, contains('Kategori tidak ditemukan'));
    });

    test('accumulates balance for repeated use of the same asset within one batch', () async {
      final asset = await createAsset(balance: 0);

      await repository
          .createManyTransactions([
            CreateTransactionParams(assetUlid: asset.ulid, amount: 10),
            CreateTransactionParams(assetUlid: asset.ulid, amount: 15),
            CreateTransactionParams(assetUlid: asset.ulid, amount: 5),
          ])
          .run();

      final updatedAsset = (await assetRepository.getAssetById(ulid: asset.ulid).run())
          .getOrElse((_) => throw Exception())
          .data!;
      expect(updatedAsset.balance, 30);
    });
  });

  group('getTransactions', () {
    late Asset assetA;
    late Asset assetB;
    late Category income;
    late Category expense;

    setUp(() async {
      assetA = await createAsset(name: 'Cash');
      assetB = await createAsset(name: 'Bank');
      income = await createCategory(name: 'Salary', type: CategoryType.income);
      expense = await createCategory(name: 'Food', type: CategoryType.expense);

      await repository
          .createTransaction(
            CreateTransactionParams(
              assetUlid: assetA.ulid,
              categoryUlid: income.ulid,
              amount: 100,
              transactionDate: DateTime(2026, 1, 5),
              description: 'Monthly salary',
            ),
          )
          .run();
      await repository
          .createTransaction(
            CreateTransactionParams(
              assetUlid: assetA.ulid,
              categoryUlid: expense.ulid,
              amount: 20,
              transactionDate: DateTime(2026, 1, 10),
              description: 'Groceries shopping',
            ),
          )
          .run();
      await repository
          .createTransaction(
            CreateTransactionParams(
              assetUlid: assetB.ulid,
              amount: 50,
              transactionDate: DateTime(2026, 1, 15),
              description: 'Misc',
            ),
          )
          .run();
    });

    test('returns all transactions with no filters', () async {
      final result = await repository.getTransactions(const GetTransactionsParams()).run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data, hasLength(3));
    });

    test('filters by assetUlid', () async {
      final result = await repository
          .getTransactions(GetTransactionsParams(assetUlid: assetA.ulid))
          .run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data, hasLength(2));
      expect(success.data!.every((t) => t.asset.target?.ulid == assetA.ulid), isTrue);
    });

    test('filters by categoryUlid', () async {
      final result = await repository
          .getTransactions(GetTransactionsParams(categoryUlid: expense.ulid))
          .run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data, hasLength(1));
      expect(success.data!.single.description, 'Groceries shopping');
    });

    test('filters by date range (both bounds)', () async {
      final result = await repository
          .getTransactions(
            GetTransactionsParams(
              startDate: DateTime(2026, 1, 6),
              endDate: DateTime(2026, 1, 12),
            ),
          )
          .run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data, hasLength(1));
      expect(success.data!.single.description, 'Groceries shopping');
    });

    test('filters by date range (start only)', () async {
      final result = await repository
          .getTransactions(GetTransactionsParams(startDate: DateTime(2026, 1, 11)))
          .run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data, hasLength(1));
      expect(success.data!.single.description, 'Misc');
    });

    test('filters by date range (end only)', () async {
      final result = await repository
          .getTransactions(GetTransactionsParams(endDate: DateTime(2026, 1, 9)))
          .run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data, hasLength(1));
      expect(success.data!.single.description, 'Monthly salary');
    });

    test('filters by amount range', () async {
      final result = await repository
          .getTransactions(GetTransactionsParams(minAmount: 30, maxAmount: 60))
          .run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data, hasLength(1));
      expect(success.data!.single.amount, 50);
    });

    test('searches case-insensitively by description', () async {
      final result = await repository
          .getTransactions(const GetTransactionsParams(searchQuery: 'GROCE'))
          .run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data, hasLength(1));
      expect(success.data!.single.description, 'Groceries shopping');
    });

    test('returns an empty result set when nothing matches', () async {
      final result = await repository
          .getTransactions(const GetTransactionsParams(searchQuery: 'nonexistent'))
          .run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data, isEmpty);
      expect(success.cursor.hasNextPage, isFalse);
    });

    test('sorts by amount ascending', () async {
      final result = await repository
          .getTransactions(
            const GetTransactionsParams(
              sortBy: TransactionSortBy.amount,
              sortOrder: SortOrder.ascending,
            ),
          )
          .run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data!.map((t) => t.amount), [20, 50, 100]);
    });

    test('sorts by amount descending', () async {
      final result = await repository
          .getTransactions(
            const GetTransactionsParams(
              sortBy: TransactionSortBy.amount,
              sortOrder: SortOrder.descending,
            ),
          )
          .run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data!.map((t) => t.amount), [100, 50, 20]);
    });

    test('sorts by transactionDate descending by default', () async {
      final result = await repository.getTransactions(const GetTransactionsParams()).run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data!.map((t) => t.description), [
        'Misc',
        'Groceries shopping',
        'Monthly salary',
      ]);
    });

    test('paginates using cursor and reports hasNextPage', () async {
      final firstPage = (await repository
              .getTransactions(const GetTransactionsParams(limit: 2))
              .run())
          .getOrElse((_) => throw Exception());

      expect(firstPage.data, hasLength(2));
      expect(firstPage.cursor.hasNextPage, isTrue);

      final secondPage = (await repository
              .getTransactions(
                GetTransactionsParams(limit: 2, cursor: firstPage.cursor.nextCursor),
              )
              .run())
          .getOrElse((_) => throw Exception());

      expect(secondPage.data, hasLength(1));
      expect(secondPage.cursor.hasNextPage, isFalse);
    });
  });

  group('getTransactionById', () {
    test('returns the matching transaction', () async {
      final asset = await createAsset();
      final created = (await repository
              .createTransaction(
                CreateTransactionParams(assetUlid: asset.ulid, amount: 100),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;

      final result = await repository.getTransactionById(ulid: created.ulid).run();

      expect(result.isRight(), isTrue);
      expect(result.getOrElse((_) => throw Exception()).data!.amount, 100);
    });

    test('fails for an unknown ulid', () async {
      final result = await repository.getTransactionById(ulid: 'unknown').run();

      expect(result.isLeft(), isTrue);
    });
  });

  group('updateTransaction', () {
    test('updates amount, description and imagePath', () async {
      final asset = await createAsset();
      final created = (await repository
              .createTransaction(
                CreateTransactionParams(assetUlid: asset.ulid, amount: 100),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;

      final result = await repository
          .updateTransaction(
            UpdateTransactionParams(
              ulid: created.ulid,
              amount: 150,
              description: 'Updated note',
              imagePath: '/tmp/receipt.png',
            ),
          )
          .run();

      final updated = result.getOrElse((_) => throw Exception()).data!;
      expect(updated.amount, 150);
      expect(updated.description, 'Updated note');
      expect(updated.imagePath, '/tmp/receipt.png');
    });

    test('fails for an unknown ulid', () async {
      final result = await repository
          .updateTransaction(const UpdateTransactionParams(ulid: 'unknown', amount: 10))
          .run();

      expect(result.isLeft(), isTrue);
    });

    test('fails when the new assetUlid does not exist', () async {
      final asset = await createAsset();
      final created = (await repository
              .createTransaction(
                CreateTransactionParams(assetUlid: asset.ulid, amount: 100),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;

      final result = await repository
          .updateTransaction(
            UpdateTransactionParams(ulid: created.ulid, assetUlid: 'unknown-asset'),
          )
          .run();

      expect(result.isLeft(), isTrue);
    });

    test('fails when the new categoryUlid does not exist', () async {
      final asset = await createAsset();
      final created = (await repository
              .createTransaction(
                CreateTransactionParams(assetUlid: asset.ulid, amount: 100),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;

      final result = await repository
          .updateTransaction(
            UpdateTransactionParams(ulid: created.ulid, categoryUlid: 'unknown-category'),
          )
          .run();

      expect(result.isLeft(), isTrue);
    });

    test('adjusts asset balance by the difference when only the amount changes', () async {
      final asset = await createAsset(balance: 0);
      final created = (await repository
              .createTransaction(
                CreateTransactionParams(assetUlid: asset.ulid, amount: 100),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;
      // * balance is now 100 (no category => treated as income)

      await repository
          .updateTransaction(UpdateTransactionParams(ulid: created.ulid, amount: 150))
          .run();

      final updatedAsset = (await assetRepository.getAssetById(ulid: asset.ulid).run())
          .getOrElse((_) => throw Exception())
          .data!;
      expect(updatedAsset.balance, 150);
    });

    test('reverts the old asset and applies to the new asset when the asset changes', () async {
      final oldAsset = await createAsset(name: 'Cash', balance: 0);
      final newAsset = await createAsset(name: 'Bank', balance: 0);
      final created = (await repository
              .createTransaction(
                CreateTransactionParams(assetUlid: oldAsset.ulid, amount: 100),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;

      await repository
          .updateTransaction(
            UpdateTransactionParams(ulid: created.ulid, assetUlid: newAsset.ulid),
          )
          .run();

      final refreshedOld = (await assetRepository.getAssetById(ulid: oldAsset.ulid).run())
          .getOrElse((_) => throw Exception())
          .data!;
      final refreshedNew = (await assetRepository.getAssetById(ulid: newAsset.ulid).run())
          .getOrElse((_) => throw Exception())
          .data!;
      expect(refreshedOld.balance, 0);
      expect(refreshedNew.balance, 100);
    });

    test('flips the balance direction when moving from no category to an expense category', () async {
      final asset = await createAsset(balance: 0);
      final expense = await createCategory(name: 'Food', type: CategoryType.expense);
      final created = (await repository
              .createTransaction(
                CreateTransactionParams(assetUlid: asset.ulid, amount: 100),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;
      // * balance is now 100

      await repository
          .updateTransaction(
            UpdateTransactionParams(ulid: created.ulid, categoryUlid: expense.ulid),
          )
          .run();

      final updatedAsset = (await assetRepository.getAssetById(ulid: asset.ulid).run())
          .getOrElse((_) => throw Exception())
          .data!;
      expect(updatedAsset.balance, -100);
    });
  });

  group('deleteTransaction', () {
    test('removes the transaction and reverts the asset balance', () async {
      final asset = await createAsset(balance: 0);
      final expense = await createCategory(name: 'Food', type: CategoryType.expense);
      final created = (await repository
              .createTransaction(
                CreateTransactionParams(
                  assetUlid: asset.ulid,
                  categoryUlid: expense.ulid,
                  amount: 50,
                ),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;
      // * balance is now -50

      final result = await repository.deleteTransaction(ulid: created.ulid).run();

      expect(result.isRight(), isTrue);
      final getResult = await repository.getTransactionById(ulid: created.ulid).run();
      expect(getResult.isLeft(), isTrue);

      final updatedAsset = (await assetRepository.getAssetById(ulid: asset.ulid).run())
          .getOrElse((_) => throw Exception())
          .data!;
      expect(updatedAsset.balance, 0);
    });

    test('fails for an unknown ulid', () async {
      final result = await repository.deleteTransaction(ulid: 'unknown').run();

      expect(result.isLeft(), isTrue);
    });
  });

  group('getStatisticSummary', () {
    test('splits totals and per-category summaries between income and expense', () async {
      final asset = await createAsset();
      final salary = await createCategory(name: 'Salary', type: CategoryType.income);
      final food = await createCategory(name: 'Food', type: CategoryType.expense);
      final transport = await createCategory(name: 'Transport', type: CategoryType.expense);

      await repository
          .createTransaction(
            CreateTransactionParams(
              assetUlid: asset.ulid,
              categoryUlid: salary.ulid,
              amount: 1000,
              transactionDate: DateTime(2026, 1, 5),
            ),
          )
          .run();
      await repository
          .createTransaction(
            CreateTransactionParams(
              assetUlid: asset.ulid,
              categoryUlid: food.ulid,
              amount: 300,
              transactionDate: DateTime(2026, 1, 10),
            ),
          )
          .run();
      await repository
          .createTransaction(
            CreateTransactionParams(
              assetUlid: asset.ulid,
              categoryUlid: transport.ulid,
              amount: 100,
              transactionDate: DateTime(2026, 1, 12),
            ),
          )
          .run();

      final result = await repository
          .getStatisticSummary(
            GetStatisticParams(
              startDate: DateTime(2026, 1, 1),
              endDate: DateTime(2026, 1, 31, 23, 59, 59),
            ),
          )
          .run();

      final summary = result.getOrElse((_) => throw Exception()).data!;
      expect(summary.totalIncome, 1000);
      expect(summary.totalExpense, 400);
      expect(summary.balance, 600);
      expect(summary.isSurplus, isTrue);
      expect(summary.isDeficit, isFalse);

      expect(summary.incomeSummaries, hasLength(1));
      expect(summary.incomeSummaries.single.category?.ulid, salary.ulid);
      expect(summary.incomeSummaries.single.percentage, 100);

      expect(summary.expenseSummaries, hasLength(2));
      // * Sorted descending by totalAmount: Food (300) before Transport (100)
      expect(summary.expenseSummaries.first.category?.ulid, food.ulid);
      expect(summary.expenseSummaries.first.percentage, closeTo(75, 0.001));
      expect(summary.expenseSummaries.last.category?.ulid, transport.ulid);
      expect(summary.expenseSummaries.last.percentage, closeTo(25, 0.001));
    });

    test('groups uncategorized expense transactions under the "no category" expense bucket', () async {
      // * Arah transaksi sekarang eksplisit (A04): transaksi tanpa kategori
      // * dengan type expense masuk bucket expense, konsisten dengan saldo.
      final asset = await createAsset();

      await repository
          .createTransaction(
            CreateTransactionParams(
              assetUlid: asset.ulid,
              amount: 75,
              transactionDate: DateTime(2026, 1, 5),
              type: CategoryType.expense,
            ),
          )
          .run();

      final result = await repository
          .getStatisticSummary(
            GetStatisticParams(
              startDate: DateTime(2026, 1, 1),
              endDate: DateTime(2026, 1, 31, 23, 59, 59),
            ),
          )
          .run();

      final summary = result.getOrElse((_) => throw Exception()).data!;
      expect(summary.totalIncome, 0);
      expect(summary.totalExpense, 75);
      expect(summary.expenseSummaries.single.category, isNull);
      // * A21/R09: label berasal dari bundle terjemahan aktif, bukan teks
      // * hardcode. Dibandingkan dengan literal tiap locale (bukan .tr())
      // * agar tidak tautologis.
      final bucket = summary.expenseSummaries.single;
      expect(LocaleKeys.transactionNoCategory, 'transaction.common.noCategory');
      loadAssetTranslations('en-US');
      expect(bucket.categoryName, 'No Category');
      loadAssetTranslations('id-ID');
      expect(bucket.categoryName, 'Tanpa Kategori');
      loadAssetTranslations('en-US');
    });

    test('excludes transactions outside the requested date range', () async {
      final asset = await createAsset();
      final salary = await createCategory(name: 'Salary', type: CategoryType.income);

      await repository
          .createTransaction(
            CreateTransactionParams(
              assetUlid: asset.ulid,
              categoryUlid: salary.ulid,
              amount: 500,
              transactionDate: DateTime(2025, 12, 31),
            ),
          )
          .run();
      await repository
          .createTransaction(
            CreateTransactionParams(
              assetUlid: asset.ulid,
              categoryUlid: salary.ulid,
              amount: 200,
              transactionDate: DateTime(2026, 1, 15),
            ),
          )
          .run();

      final result = await repository
          .getStatisticSummary(
            GetStatisticParams(
              startDate: DateTime(2026, 1, 1),
              endDate: DateTime(2026, 1, 31, 23, 59, 59),
            ),
          )
          .run();

      final summary = result.getOrElse((_) => throw Exception()).data!;
      expect(summary.totalIncome, 200);
    });

    test('returns an empty summary when there is no data in range', () async {
      final result = await repository
          .getStatisticSummary(
            GetStatisticParams(
              startDate: DateTime(2026, 1, 1),
              endDate: DateTime(2026, 1, 31, 23, 59, 59),
            ),
          )
          .run();

      final summary = result.getOrElse((_) => throw Exception()).data!;
      expect(summary.totalIncome, 0);
      expect(summary.totalExpense, 0);
      expect(summary.balance, 0);
      expect(summary.incomeSummaries, isEmpty);
      expect(summary.expenseSummaries, isEmpty);
    });
  });
}
