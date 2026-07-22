import 'dart:io';

import 'package:excel_community/excel_community.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/export/models/export_params.dart';
import 'package:ikuyo_finance/features/export/repositories/export_repository_impl.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';

import '../../../support/objectbox_test_store.dart';
import '../../../support/test_logger.dart';

void main() {
  setUpAll(bootstrapTestLogger);

  late ObjectBoxTestStore testStore;
  late ExportRepositoryImpl repository;
  late Directory tempExportDir;

  setUp(() async {
    testStore = await ObjectBoxTestStore.open();
    repository = ExportRepositoryImpl(testStore.storage);
    tempExportDir = Directory.systemTemp.createTempSync('ikuyo_export_test_');
  });

  tearDown(() {
    testStore.close();
    if (tempExportDir.existsSync()) {
      tempExportDir.deleteSync(recursive: true);
    }
  });

  Asset putAsset({String name = 'Cash', AssetType type = AssetType.cash, double balance = 0}) {
    final asset = Asset(name: name, type: type.index, balance: balance);
    testStore.storage.box<Asset>().put(asset);
    return asset;
  }

  Category putCategory({
    required String name,
    required CategoryType type,
    Category? parent,
  }) {
    final category = Category(name: name, type: type.index);
    if (parent != null) category.parent.target = parent;
    testStore.storage.box<Category>().put(category);
    return category;
  }

  Transaction putTransaction({
    required Asset asset,
    Category? category,
    required double amount,
    DateTime? transactionDate,
    String? description,
  }) {
    final tx = Transaction(
      amount: amount,
      transactionDate: transactionDate,
      description: description,
    );
    tx.asset.target = asset;
    if (category != null) tx.category.target = category;
    testStore.storage.box<Transaction>().put(tx);
    return tx;
  }

  group('getAssetsForFilter', () {
    test('returns all assets', () async {
      putAsset(name: 'Cash');
      putAsset(name: 'Bank', type: AssetType.bank);

      final result = await repository.getAssetsForFilter().run();

      final assets = result.getOrElse((_) => throw Exception()).data!;
      expect(assets, hasLength(2));
    });

    test('returns an empty list when there are no assets', () async {
      final result = await repository.getAssetsForFilter().run();

      expect(result.getOrElse((_) => throw Exception()).data, isEmpty);
    });
  });

  group('getCategoriesForFilter', () {
    test('returns all categories', () async {
      putCategory(name: 'Food', type: CategoryType.expense);
      putCategory(name: 'Salary', type: CategoryType.income);

      final result = await repository.getCategoriesForFilter().run();

      expect(result.getOrElse((_) => throw Exception()).data, hasLength(2));
    });
  });

  group('exportToExcel', () {
    const labels = <String, String>{};
    const currencySymbol = 'Rp';

    test('creates a real .xlsx file on disk with transaction/asset/category sheets', () async {
      final asset = putAsset(name: 'Cash');
      final category = putCategory(name: 'Food', type: CategoryType.expense);
      putTransaction(
        asset: asset,
        category: category,
        amount: 15000,
        transactionDate: DateTime(2026, 6, 15),
        description: 'Lunch',
      );

      final result = await repository
          .exportToExcel(
            params: const ExportParams(),
            exportDirectory: tempExportDir.path,
            labels: labels,
            currencySymbol: currencySymbol,
          )
          .run();

      expect(result.isRight(), isTrue);
      final path = result.getOrElse((_) => throw Exception()).data!;
      final file = File(path);
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(0));

      final excel = Excel.decodeBytes(file.readAsBytesSync());
      expect(excel.tables.keys, containsAll(['Transactions', 'Assets', 'Categories']));

      final txSheet = excel.tables['Transactions']!;
      // * header row + 1 data row + 3 summary rows
      expect(txSheet.maxRows, greaterThanOrEqualTo(2));
      final dataRow = txSheet.rows[1];
      expect(dataRow.map((c) => c?.value.toString()).join('|'), contains('Cash'));
      expect(dataRow.map((c) => c?.value.toString()).join('|'), contains('Food'));
      expect(dataRow.map((c) => c?.value.toString()).join('|'), contains('Lunch'));
    });

    test('excludes assets/categories listed in excludedAssetUlids/excludedCategoryUlids', () async {
      final keptAsset = putAsset(name: 'Cash');
      final excludedAsset = putAsset(name: 'Bank', type: AssetType.bank);
      final category = putCategory(name: 'Food', type: CategoryType.expense);
      putTransaction(asset: keptAsset, category: category, amount: 1000, transactionDate: DateTime(2026, 1, 1));
      putTransaction(asset: excludedAsset, category: category, amount: 2000, transactionDate: DateTime(2026, 1, 1));

      final result = await repository
          .exportToExcel(
            params: ExportParams(excludedAssetUlids: [excludedAsset.ulid]),
            exportDirectory: tempExportDir.path,
            labels: labels,
            currencySymbol: currencySymbol,
          )
          .run();

      final path = result.getOrElse((_) => throw Exception()).data!;
      final excel = Excel.decodeBytes(File(path).readAsBytesSync());
      final txSheet = excel.tables['Transactions']!;
      // * Only the kept-asset transaction should appear as a data row.
      final bodyText = txSheet.rows
          .skip(1)
          .map((row) => row.map((c) => c?.value.toString()).join('|'))
          .join('\n');
      expect(bodyText, contains('Cash'));
      expect(bodyText, isNot(contains('Bank')));

      final assetSheet = excel.tables['Assets']!;
      final assetNames = assetSheet.rows.skip(1).map((row) => row[1]?.value.toString()).toList();
      expect(assetNames, contains('Cash'));
      expect(assetNames, isNot(contains('Bank')));
    });

    test('filters transactions by startDate/endDate range (inclusive boundaries)', () async {
      final asset = putAsset();
      putTransaction(asset: asset, amount: 100, transactionDate: DateTime(2026, 5, 31));
      putTransaction(asset: asset, amount: 200, transactionDate: DateTime(2026, 6, 1));
      putTransaction(asset: asset, amount: 300, transactionDate: DateTime(2026, 6, 30));
      putTransaction(asset: asset, amount: 400, transactionDate: DateTime(2026, 7, 1));

      final result = await repository
          .exportToExcel(
            params: ExportParams(
              startDate: DateTime(2026, 6, 1),
              endDate: DateTime(2026, 6, 30),
            ),
            exportDirectory: tempExportDir.path,
            labels: labels,
            currencySymbol: currencySymbol,
          )
          .run();

      final path = result.getOrElse((_) => throw Exception()).data!;
      final excel = Excel.decodeBytes(File(path).readAsBytesSync());
      final txSheet = excel.tables['Transactions']!;
      final bodyText = txSheet.rows
          .skip(1)
          .map((row) => row.map((c) => c?.value.toString()).join('|'))
          .join('\n');
      expect(bodyText, contains('200'));
      expect(bodyText, contains('300'));
      expect(bodyText, isNot(contains('100')));
      expect(bodyText, isNot(contains('400')));
    });

    test('a transaction with no category still appears in the export', () async {
      final asset = putAsset();
      putTransaction(asset: asset, amount: 500, transactionDate: DateTime(2026, 1, 1));

      final result = await repository
          .exportToExcel(
            params: const ExportParams(),
            exportDirectory: tempExportDir.path,
            labels: labels,
            currencySymbol: currencySymbol,
          )
          .run();

      final path = result.getOrElse((_) => throw Exception()).data!;
      final excel = Excel.decodeBytes(File(path).readAsBytesSync());
      final dataRow = excel.tables['Transactions']!.rows[1];
      expect(dataRow.map((c) => c?.value.toString()).join('|'), contains('500'));
    });

    test('a transaction whose category was excluded is dropped from the export', () async {
      final asset = putAsset();
      final excludedCategory = putCategory(name: 'Snacks', type: CategoryType.expense);
      putTransaction(
        asset: asset,
        category: excludedCategory,
        amount: 777,
        transactionDate: DateTime(2026, 1, 1),
      );

      final result = await repository
          .exportToExcel(
            params: ExportParams(excludedCategoryUlids: [excludedCategory.ulid]),
            exportDirectory: tempExportDir.path,
            labels: labels,
            currencySymbol: currencySymbol,
          )
          .run();

      final path = result.getOrElse((_) => throw Exception()).data!;
      final excel = Excel.decodeBytes(File(path).readAsBytesSync());
      final txSheet = excel.tables['Transactions']!;
      final bodyText = txSheet.rows
          .skip(1)
          .map((row) => row.map((c) => c?.value.toString()).join('|'))
          .join('\n');
      expect(bodyText, isNot(contains('777')));
    });

    test('creates the export directory if it does not already exist', () async {
      putAsset();
      final nestedDir = Directory('${tempExportDir.path}/nested/sub');

      final result = await repository
          .exportToExcel(
            params: const ExportParams(),
            exportDirectory: nestedDir.path,
            labels: labels,
            currencySymbol: currencySymbol,
          )
          .run();

      expect(result.isRight(), isTrue);
      expect(nestedDir.existsSync(), isTrue);
    });
  });
}
