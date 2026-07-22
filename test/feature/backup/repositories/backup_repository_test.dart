import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_group.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_item.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_log.dart';
import 'package:ikuyo_finance/features/backup/models/backup_data.dart';
import 'package:ikuyo_finance/features/backup/repositories/backup_repository_impl.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';

import '../../../support/objectbox_test_store.dart';
import '../../../support/test_logger.dart';

void main() {
  setUpAll(bootstrapTestLogger);

  late ObjectBoxTestStore testStore;
  late BackupRepositoryImpl repository;

  setUp(() async {
    testStore = await ObjectBoxTestStore.open();
    repository = BackupRepositoryImpl(testStore.storage);
  });

  tearDown(() => testStore.close());

  group('exportData', () {
    test('returns an empty backup when the store has no data', () async {
      final result = await repository.exportData().run();

      final data = result.getOrElse((_) => throw Exception()).data!;
      expect(data.categories, isEmpty);
      expect(data.assets, isEmpty);
      expect(data.transactions, isEmpty);
      expect(data.budgets, isEmpty);
      expect(data.autoGroups, isEmpty);
      expect(data.autoItems, isEmpty);
      expect(data.autoLogs, isEmpty);
      expect(data.totalItems, 0);
      expect(data.appName, 'Ikuyo Finance');
      expect(data.version, isNotEmpty);
    });

    test('exports categories and resolves parent relations to parentUlid', () async {
      final parent = Category(name: 'Food', type: CategoryType.expense.index);
      testStore.storage.box<Category>().put(parent);
      final child = Category(name: 'Snacks', type: CategoryType.expense.index)
        ..parent.target = parent;
      testStore.storage.box<Category>().put(child);

      final result = await repository.exportData().run();
      final data = result.getOrElse((_) => throw Exception()).data!;

      expect(data.categories, hasLength(2));
      final childBackup = data.categories.firstWhere((c) => c.ulid == child.ulid);
      expect(childBackup.parentUlid, parent.ulid);
      final parentBackup = data.categories.firstWhere((c) => c.ulid == parent.ulid);
      expect(parentBackup.parentUlid, isNull);
    });

    test('exports assets, transactions and budgets with relation ulids resolved', () async {
      final asset = Asset(name: 'Cash', type: AssetType.cash.index, balance: 500);
      testStore.storage.box<Asset>().put(asset);
      final category = Category(name: 'Salary', type: CategoryType.income.index);
      testStore.storage.box<Category>().put(category);

      final transaction = Transaction(amount: 1000, transactionDate: DateTime(2026, 1, 1))
        ..asset.target = asset
        ..category.target = category;
      testStore.storage.box<Transaction>().put(transaction);

      final budget = Budget(amountLimit: 2000)..category.target = category;
      testStore.storage.box<Budget>().put(budget);

      final result = await repository.exportData().run();
      final data = result.getOrElse((_) => throw Exception()).data!;

      expect(data.assets, hasLength(1));
      expect(data.assets.single.ulid, asset.ulid);
      expect(data.transactions, hasLength(1));
      expect(data.transactions.single.assetUlid, asset.ulid);
      expect(data.transactions.single.categoryUlid, category.ulid);
      expect(data.budgets, hasLength(1));
      expect(data.budgets.single.categoryUlid, category.ulid);
    });

    test('filters out transactions whose asset relation is null', () async {
      final transaction = Transaction(amount: 500);
      testStore.storage.box<Transaction>().put(transaction);

      final result = await repository.exportData().run();
      final data = result.getOrElse((_) => throw Exception()).data!;

      expect(data.transactions, isEmpty);
    });

    test('filters out budgets whose category relation is null', () async {
      final budget = Budget(amountLimit: 100);
      testStore.storage.box<Budget>().put(budget);

      final result = await repository.exportData().run();
      final data = result.getOrElse((_) => throw Exception()).data!;

      expect(data.budgets, isEmpty);
    });

    test('filters out auto items whose group or transaction relation is null', () async {
      final group = AutoTransactionGroup(name: 'Rent', startDate: DateTime(2026, 1, 1));
      testStore.storage.box<AutoTransactionGroup>().put(group);

      final itemWithoutTransaction = AutoTransactionItem()..group.target = group;
      testStore.storage.box<AutoTransactionItem>().put(itemWithoutTransaction);

      final asset = Asset(name: 'Cash', type: AssetType.cash.index);
      testStore.storage.box<Asset>().put(asset);
      final transaction = Transaction(amount: 10)..asset.target = asset;
      testStore.storage.box<Transaction>().put(transaction);
      final itemWithoutGroup = AutoTransactionItem()..transaction.target = transaction;
      testStore.storage.box<AutoTransactionItem>().put(itemWithoutGroup);

      final result = await repository.exportData().run();
      final data = result.getOrElse((_) => throw Exception()).data!;

      expect(data.autoItems, isEmpty);
    });

    test('filters out auto logs whose group relation is null', () async {
      final log = AutoTransactionLog(
        scheduledAt: DateTime(2026, 1, 1),
        executedAt: DateTime(2026, 1, 1),
      );
      testStore.storage.box<AutoTransactionLog>().put(log);

      final result = await repository.exportData().run();
      final data = result.getOrElse((_) => throw Exception()).data!;

      expect(data.autoLogs, isEmpty);
    });

    test('fails when the store is already closed', () async {
      testStore.close();

      final result = await repository.exportData().run();

      expect(result.isLeft(), isTrue);
    });
  });

  group('importData', () {
    test('wipes existing data before importing the new snapshot', () async {
      testStore.storage.box<Category>().put(
        Category(name: 'Stale', type: CategoryType.expense.index),
      );
      final now = DateTime.now();

      final backupData = BackupData(
        version: '1.0.0',
        createdAt: now,
        appName: 'Ikuyo Finance',
        categories: [
          CategoryBackup(
            ulid: 'cat-1',
            name: 'Food',
            type: CategoryType.expense.index,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        assets: const [],
        transactions: const [],
        budgets: const [],
      );

      final result = await repository.importData(backupData).run();

      expect(result.isRight(), isTrue);
      final categories = testStore.storage.box<Category>().getAll();
      expect(categories, hasLength(1));
      expect(categories.single.ulid, 'cat-1');
    });

    test('reconstructs category parent relations from parentUlid (two-pass)', () async {
      final now = DateTime.now();
      final backupData = BackupData(
        version: '1.0.0',
        createdAt: now,
        appName: 'Ikuyo Finance',
        categories: [
          CategoryBackup(
            ulid: 'root',
            name: 'Food',
            type: CategoryType.expense.index,
            createdAt: now,
            updatedAt: now,
          ),
          CategoryBackup(
            ulid: 'child',
            parentUlid: 'root',
            name: 'Snacks',
            type: CategoryType.expense.index,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        assets: const [],
        transactions: const [],
        budgets: const [],
      );

      final result = await repository.importData(backupData).run();

      expect(result.isRight(), isTrue);
      final categories = testStore.storage.box<Category>().getAll();
      final child = categories.firstWhere((c) => c.ulid == 'child');
      expect(child.parent.target?.ulid, 'root');
    });

    test('imports assets, transactions and budgets and rewires relations', () async {
      final now = DateTime.now();
      final backupData = BackupData(
        version: '1.0.0',
        createdAt: now,
        appName: 'Ikuyo Finance',
        categories: [
          CategoryBackup(
            ulid: 'cat-1',
            name: 'Salary',
            type: CategoryType.income.index,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        assets: [
          AssetBackup(
            ulid: 'asset-1',
            name: 'Cash',
            type: AssetType.cash.index,
            balance: 100,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        transactions: [
          TransactionBackup(
            ulid: 'txn-1',
            assetUlid: 'asset-1',
            categoryUlid: 'cat-1',
            amount: 50,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        budgets: [
          BudgetBackup(
            ulid: 'budget-1',
            categoryUlid: 'cat-1',
            amountLimit: 200,
            period: 0,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      final result = await repository.importData(backupData).run();

      expect(result.isRight(), isTrue);
      final transaction = testStore.storage
          .box<Transaction>()
          .getAll()
          .firstWhere((t) => t.ulid == 'txn-1');
      expect(transaction.asset.target?.ulid, 'asset-1');
      expect(transaction.category.target?.ulid, 'cat-1');
      final budget = testStore.storage
          .box<Budget>()
          .getAll()
          .firstWhere((b) => b.ulid == 'budget-1');
      expect(budget.category.target?.ulid, 'cat-1');
    });

    test('skips transactions referencing an asset ulid absent from the backup', () async {
      final now = DateTime.now();
      final backupData = BackupData(
        version: '1.0.0',
        createdAt: now,
        appName: 'Ikuyo Finance',
        categories: const [],
        assets: const [],
        transactions: [
          TransactionBackup(
            ulid: 'txn-1',
            assetUlid: 'missing-asset',
            amount: 10,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        budgets: const [],
      );

      final result = await repository.importData(backupData).run();

      expect(result.isRight(), isTrue);
      expect(testStore.storage.box<Transaction>().getAll(), isEmpty);
    });

    test('skips budgets referencing a category ulid absent from the backup', () async {
      final now = DateTime.now();
      final backupData = BackupData(
        version: '1.0.0',
        createdAt: now,
        appName: 'Ikuyo Finance',
        categories: const [],
        assets: const [],
        transactions: const [],
        budgets: [
          BudgetBackup(
            ulid: 'budget-1',
            categoryUlid: 'missing-category',
            amountLimit: 100,
            period: 0,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      final result = await repository.importData(backupData).run();

      expect(result.isRight(), isTrue);
      expect(testStore.storage.box<Budget>().getAll(), isEmpty);
    });

    test('skips auto items referencing a group or transaction ulid absent from the backup', () async {
      final now = DateTime.now();
      final backupData = BackupData(
        version: '1.0.0',
        createdAt: now,
        appName: 'Ikuyo Finance',
        categories: const [],
        assets: const [],
        transactions: const [],
        budgets: const [],
        autoGroups: [
          AutoGroupBackup(
            ulid: 'group-1',
            name: 'Rent',
            isActive: true,
            isPaused: false,
            frequency: 0,
            scheduleHour: 8,
            scheduleMinute: 0,
            intervalDays: 1,
            activeDaysMask: 0,
            startDate: now,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        autoItems: [
          AutoItemBackup(
            ulid: 'item-1',
            groupUlid: 'group-1',
            transactionUlid: 'missing-txn',
            isActive: true,
            sortOrder: 0,
            createdAt: now,
            updatedAt: now,
          ),
          AutoItemBackup(
            ulid: 'item-2',
            groupUlid: 'missing-group',
            transactionUlid: 'missing-txn',
            isActive: true,
            sortOrder: 0,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      final result = await repository.importData(backupData).run();

      expect(result.isRight(), isTrue);
      expect(testStore.storage.box<AutoTransactionItem>().getAll(), isEmpty);
      expect(testStore.storage.box<AutoTransactionGroup>().getAll(), hasLength(1));
    });

    test('skips auto logs referencing a group ulid absent from the backup', () async {
      final now = DateTime.now();
      final backupData = BackupData(
        version: '1.0.0',
        createdAt: now,
        appName: 'Ikuyo Finance',
        categories: const [],
        assets: const [],
        transactions: const [],
        budgets: const [],
        autoLogs: [
          AutoLogBackup(
            ulid: 'log-1',
            groupUlid: 'missing-group',
            scheduledAt: now,
            executedAt: now,
            status: 0,
            successCount: 0,
            failureCount: 0,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      final result = await repository.importData(backupData).run();

      expect(result.isRight(), isTrue);
      expect(testStore.storage.box<AutoTransactionLog>().getAll(), isEmpty);
    });

    test('fails when the backup data contains duplicate category ulids', () async {
      final now = DateTime.now();
      final backupData = BackupData(
        version: '1.0.0',
        createdAt: now,
        appName: 'Ikuyo Finance',
        categories: [
          CategoryBackup(
            ulid: 'dup',
            name: 'A',
            type: CategoryType.expense.index,
            createdAt: now,
            updatedAt: now,
          ),
          CategoryBackup(
            ulid: 'dup',
            name: 'B',
            type: CategoryType.expense.index,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        assets: const [],
        transactions: const [],
        budgets: const [],
      );

      final result = await repository.importData(backupData).run();

      expect(result.isLeft(), isTrue);
    });

    test('fails when the store is already closed', () async {
      testStore.close();

      final result = await repository
          .importData(
            BackupData(
              version: '1.0.0',
              createdAt: DateTime.now(),
              appName: 'Ikuyo Finance',
              categories: const [],
              assets: const [],
              transactions: const [],
              budgets: const [],
            ),
          )
          .run();

      expect(result.isLeft(), isTrue);
    });
  });

  group('getDataSummary', () {
    test('returns zero counts for every entity when the store is empty', () async {
      final result = await repository.getDataSummary().run();

      final summary = result.getOrElse((_) => throw Exception()).data!;
      expect(summary['categories'], 0);
      expect(summary['assets'], 0);
      expect(summary['transactions'], 0);
      expect(summary['budgets'], 0);
      expect(summary['autoGroups'], 0);
      expect(summary['autoItems'], 0);
      expect(summary['autoLogs'], 0);
    });

    test('returns the correct count per entity type after seeding data', () async {
      final asset = Asset(name: 'Cash', type: AssetType.cash.index);
      testStore.storage.box<Asset>().put(asset);
      final category = Category(name: 'Food', type: CategoryType.expense.index);
      testStore.storage.box<Category>().put(category);
      testStore.storage.box<Category>().put(
        Category(name: 'Transport', type: CategoryType.expense.index),
      );
      testStore.storage.box<Transaction>().put(
        Transaction(amount: 10)..asset.target = asset,
      );

      final result = await repository.getDataSummary().run();

      final summary = result.getOrElse((_) => throw Exception()).data!;
      expect(summary['categories'], 2);
      expect(summary['assets'], 1);
      expect(summary['transactions'], 1);
      expect(summary['budgets'], 0);
    });

    test('fails when the store is already closed', () async {
      testStore.close();

      final result = await repository.getDataSummary().run();

      expect(result.isLeft(), isTrue);
    });
  });

  group('export -> import round trip', () {
    test('reproduces equivalent data on a fresh store', () async {
      final parent = Category(name: 'Food', type: CategoryType.expense.index);
      testStore.storage.box<Category>().put(parent);
      final child = Category(name: 'Snacks', type: CategoryType.expense.index)
        ..parent.target = parent;
      testStore.storage.box<Category>().put(child);

      final asset = Asset(name: 'Cash', type: AssetType.cash.index, balance: 250);
      testStore.storage.box<Asset>().put(asset);

      final transaction = Transaction(amount: 75, transactionDate: DateTime(2026, 2, 1))
        ..asset.target = asset
        ..category.target = child;
      testStore.storage.box<Transaction>().put(transaction);

      final budget = Budget(amountLimit: 300)..category.target = child;
      testStore.storage.box<Budget>().put(budget);

      final group = AutoTransactionGroup(name: 'Rent', startDate: DateTime(2026, 1, 1));
      testStore.storage.box<AutoTransactionGroup>().put(group);

      final item = AutoTransactionItem()
        ..group.target = group
        ..transaction.target = transaction;
      testStore.storage.box<AutoTransactionItem>().put(item);

      final log = AutoTransactionLog(
        scheduledAt: DateTime(2026, 2, 1),
        executedAt: DateTime(2026, 2, 1),
      )..group.target = group;
      testStore.storage.box<AutoTransactionLog>().put(log);

      final exportResult = await repository.exportData().run();
      final backupData = exportResult.getOrElse((_) => throw Exception()).data!;

      final targetStore = await ObjectBoxTestStore.open();
      try {
        final targetRepository = BackupRepositoryImpl(targetStore.storage);
        final importResult = await targetRepository.importData(backupData).run();
        expect(importResult.isRight(), isTrue);

        final reExportResult = await targetRepository.exportData().run();
        final reExported = reExportResult.getOrElse((_) => throw Exception()).data!;

        expect(
          reExported.categories.map((c) => c.ulid).toSet(),
          backupData.categories.map((c) => c.ulid).toSet(),
        );
        expect(
          reExported.assets.map((a) => a.ulid).toSet(),
          backupData.assets.map((a) => a.ulid).toSet(),
        );
        expect(reExported.transactions, hasLength(1));
        expect(reExported.transactions.single.assetUlid, asset.ulid);
        expect(reExported.transactions.single.categoryUlid, child.ulid);
        expect(reExported.budgets, hasLength(1));
        expect(reExported.budgets.single.categoryUlid, child.ulid);
        expect(reExported.autoGroups, hasLength(1));
        expect(reExported.autoGroups.single.name, 'Rent');
        expect(reExported.autoItems, hasLength(1));
        expect(reExported.autoItems.single.groupUlid, group.ulid);
        expect(reExported.autoItems.single.transactionUlid, transaction.ulid);
        expect(reExported.autoLogs, hasLength(1));
        expect(reExported.autoLogs.single.groupUlid, group.ulid);

        final childCategory = targetStore.storage
            .box<Category>()
            .getAll()
            .firstWhere((c) => c.ulid == child.ulid);
        expect(childCategory.parent.target?.ulid, parent.ulid);
      } finally {
        targetStore.close();
      }
    });
  });
}
