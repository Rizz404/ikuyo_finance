import 'dart:io';

import 'package:excel_community/excel_community.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ikuyo_finance/core/extensions/logger_extension.dart';
import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/core/wrapper/failure.dart';
import 'package:ikuyo_finance/core/wrapper/success.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/export/models/export_params.dart';
import 'package:ikuyo_finance/features/export/repositories/export_repository.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/objectbox.g.dart';
import 'package:intl/intl.dart';

class ExportRepositoryImpl implements ExportRepository {
  final ObjectBoxStorage _storage;

  const ExportRepositoryImpl(this._storage);

  Box<Asset> get _assetBox => _storage.box<Asset>();
  Box<Category> get _categoryBox => _storage.box<Category>();
  Box<Transaction> get _transactionBox => _storage.box<Transaction>();

  @override
  TaskEither<Failure, Success<List<Asset>>> getAssetsForFilter() {
    return TaskEither.tryCatch(
      () async {
        final assets = _assetBox.getAll();
        return Success(message: 'Assets loaded', data: assets);
      },
      (error, stackTrace) {
        logError('Gagal memuat aset untuk filter', error, stackTrace);
        return Failure(message: 'Gagal memuat aset: ${error.toString()}');
      },
    );
  }

  @override
  TaskEither<Failure, Success<List<Category>>> getCategoriesForFilter() {
    return TaskEither.tryCatch(
      () async {
        final categories = _categoryBox.getAll();
        return Success(message: 'Categories loaded', data: categories);
      },
      (error, stackTrace) {
        logError('Gagal memuat kategori untuk filter', error, stackTrace);
        return Failure(message: 'Gagal memuat kategori: ${error.toString()}');
      },
    );
  }

  @override
  TaskEither<Failure, Success<String>> exportToExcel({
    required ExportParams params,
    required String exportDirectory,
    required Map<String, String> labels,
    required String currencySymbol,
  }) {
    return TaskEither.tryCatch(
      () async {
        logService('Export Excel', 'Memulai proses ekspor');

        // * Query data
        final allAssets = _assetBox.getAll();
        final allCategories = _categoryBox.getAll();
        final allTransactions = _transactionBox.getAll();

        // * Terapkan filter exclusion
        final assets = allAssets
            .where((a) => !params.excludedAssetUlids.contains(a.ulid))
            .toList();

        final categories = allCategories
            .where((c) => !params.excludedCategoryUlids.contains(c.ulid))
            .toList();

        // * Kumpulkan ULID asset dan category yang lolos filter
        final includedAssetUlids = assets.map((a) => a.ulid).toSet();
        final includedCategoryUlids = categories.map((c) => c.ulid).toSet();

        // * Filter transaksi: sesuai date range + asset/category yang dipilih
        var transactions = allTransactions
            .where((t) => t.asset.target != null)
            .where((t) => includedAssetUlids.contains(t.asset.target!.ulid))
            .toList();

        if (params.startDate != null) {
          final start = DateTime(
            params.startDate!.year,
            params.startDate!.month,
            params.startDate!.day,
          );
          transactions = transactions
              .where(
                (t) =>
                    t.transactionDate != null &&
                    !t.transactionDate!.isBefore(start),
              )
              .toList();
        }

        if (params.endDate != null) {
          final end = DateTime(
            params.endDate!.year,
            params.endDate!.month,
            params.endDate!.day,
            23,
            59,
            59,
          );
          transactions = transactions
              .where(
                (t) =>
                    t.transactionDate != null &&
                    !t.transactionDate!.isAfter(end),
              )
              .toList();
        }

        // * Filter transaksi: category yang dikecualikan tetap tampil sebagai '-'
        // * kecuali jika kita ingin exclude transaksinya juga — sesuai spec: category difilter
        transactions = transactions.where((t) {
          final cat = t.category.target;
          if (cat == null) return true; // transaksi tanpa category tetap masuk
          return includedCategoryUlids.contains(cat.ulid);
        }).toList();

        logInfo(
          'Data siap: ${transactions.length} transaksi, '
          '${assets.length} aset, ${categories.length} kategori',
        );

        // * Buat workbook
        final excel = Excel.createExcel();

        // * Hapus default sheet
        excel.delete('Sheet1');

        _buildTransactionSheet(
          excel,
          transactions,
          labels,
          currencySymbol,
        );
        _buildAssetSheet(excel, assets, labels, currencySymbol);
        _buildCategorySheet(excel, categories, labels);

        // * Simpan file
        final dir = Directory(exportDirectory);
        if (!await dir.exists()) await dir.create(recursive: true);

        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final filePath = '$exportDirectory/ikuyo_export_$timestamp.xlsx';

        final bytes = excel.save();
        if (bytes == null) {
          throw Exception('Gagal mengenkode file Excel');
        }

        await File(filePath).writeAsBytes(bytes);
        logInfo('File Excel disimpan: $filePath');

        return Success(message: 'Ekspor berhasil', data: filePath);
      },
      (error, stackTrace) {
        logError('Gagal mengekspor ke Excel', error, stackTrace);
        return Failure(message: 'Gagal mengekspor: ${error.toString()}');
      },
    );
  }

  // ── Sheet 1: Transactions ────────────────────────────────────────────────

  void _buildTransactionSheet(
    Excel excel,
    List<Transaction> transactions,
    Map<String, String> labels,
    String currencySymbol,
  ) {
    final sheetName = labels['sheet.transactions'] ?? 'Transactions';
    final sheet = excel[sheetName];

    // * Header row
    final headers = [
      labels['col.no'] ?? 'No',
      labels['col.date'] ?? 'Date',
      labels['col.asset'] ?? 'Asset',
      labels['col.assetType'] ?? 'Asset Type',
      labels['col.category'] ?? 'Category',
      labels['col.categoryType'] ?? 'Category Type',
      labels['col.parentCategory'] ?? 'Parent Category',
      labels['col.amount'] ?? 'Amount',
      labels['col.description'] ?? 'Description',
      labels['col.createdAt'] ?? 'Created At',
    ];

    _writeHeaderRow(sheet, headers);

    final dateFormat = DateFormat('dd MMM yyyy');
    final dateTimeFormat = DateFormat('dd MMM yyyy HH:mm');

    double totalIncome = 0;
    double totalExpense = 0;

    // * Data rows
    for (var i = 0; i < transactions.length; i++) {
      final t = transactions[i];
      final asset = t.asset.target;
      final category = t.category.target;
      final assetTypeName = asset != null
          ? _assetTypeLabel(asset.assetType, labels)
          : '-';
      final categoryTypeName = category != null
          ? _categoryTypeLabel(category.categoryType, labels)
          : '-';

      final isIncome =
          category?.categoryType == CategoryType.income;
      if (isIncome) {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
      }

      final row = [
        (i + 1).toString(),
        t.transactionDate != null
            ? dateFormat.format(t.transactionDate!)
            : '-',
        asset?.name ?? '-',
        assetTypeName,
        category?.name ?? '-',
        categoryTypeName,
        category?.parent.target?.name ?? '-',
        '$currencySymbol ${_formatNumber(t.amount)}',
        t.description ?? '-',
        dateTimeFormat.format(t.createdAt),
      ];

      _writeDataRow(sheet, i + 1, row);
    }

    // * Summary rows (kosong satu baris dulu)
    final summaryStartRow = transactions.length + 2;
    _writeSummaryRow(
      sheet,
      summaryStartRow,
      labels['summary.totalIncome'] ?? 'Total Income',
      '$currencySymbol ${_formatNumber(totalIncome)}',
    );
    _writeSummaryRow(
      sheet,
      summaryStartRow + 1,
      labels['summary.totalExpense'] ?? 'Total Expense',
      '$currencySymbol ${_formatNumber(totalExpense)}',
    );
    _writeSummaryRow(
      sheet,
      summaryStartRow + 2,
      labels['summary.net'] ?? 'Net',
      '$currencySymbol ${_formatNumber(totalIncome - totalExpense)}',
    );
  }

  // ── Sheet 2: Assets ──────────────────────────────────────────────────────

  void _buildAssetSheet(
    Excel excel,
    List<Asset> assets,
    Map<String, String> labels,
    String currencySymbol,
  ) {
    final sheetName = labels['sheet.assets'] ?? 'Assets';
    final sheet = excel[sheetName];

    final headers = [
      labels['col.no'] ?? 'No',
      labels['col.name'] ?? 'Name',
      labels['col.type'] ?? 'Type',
      labels['col.balance'] ?? 'Balance',
      labels['col.createdAt'] ?? 'Created At',
    ];

    _writeHeaderRow(sheet, headers);

    final dateTimeFormat = DateFormat('dd MMM yyyy HH:mm');
    double totalBalance = 0;

    for (var i = 0; i < assets.length; i++) {
      final a = assets[i];
      totalBalance += a.balance;

      final row = [
        (i + 1).toString(),
        a.name,
        _assetTypeLabel(a.assetType, labels),
        '$currencySymbol ${_formatNumber(a.balance)}',
        dateTimeFormat.format(a.createdAt),
      ];

      _writeDataRow(sheet, i + 1, row);
    }

    final summaryRow = assets.length + 2;
    _writeSummaryRow(
      sheet,
      summaryRow,
      labels['summary.totalBalance'] ?? 'Total Balance',
      '$currencySymbol ${_formatNumber(totalBalance)}',
    );
  }

  // ── Sheet 3: Categories ──────────────────────────────────────────────────

  void _buildCategorySheet(
    Excel excel,
    List<Category> categories,
    Map<String, String> labels,
  ) {
    final sheetName = labels['sheet.categories'] ?? 'Categories';
    final sheet = excel[sheetName];

    final headers = [
      labels['col.no'] ?? 'No',
      labels['col.name'] ?? 'Name',
      labels['col.type'] ?? 'Type',
      labels['col.parentCategory'] ?? 'Parent Category',
      labels['col.icon'] ?? 'Icon',
      labels['col.color'] ?? 'Color',
      labels['col.createdAt'] ?? 'Created At',
    ];

    _writeHeaderRow(sheet, headers);

    final dateTimeFormat = DateFormat('dd MMM yyyy HH:mm');

    for (var i = 0; i < categories.length; i++) {
      final c = categories[i];

      final row = [
        (i + 1).toString(),
        c.name,
        _categoryTypeLabel(c.categoryType, labels),
        c.parent.target?.name ?? '-',
        c.icon ?? '-',
        c.color ?? '-',
        dateTimeFormat.format(c.createdAt),
      ];

      _writeDataRow(sheet, i + 1, row);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _writeHeaderRow(Sheet sheet, List<String> headers) {
    for (var col = 0; col < headers.length; col++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#4A90D9'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }
  }

  void _writeDataRow(Sheet sheet, int rowIndex, List<String> values) {
    for (var col = 0; col < values.length; col++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex),
      );
      cell.value = TextCellValue(values[col]);
    }
  }

  void _writeSummaryRow(
    Sheet sheet,
    int rowIndex,
    String label,
    String value,
  ) {
    final labelCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
    );
    labelCell.value = TextCellValue(label);
    labelCell.cellStyle = CellStyle(bold: true, italic: true);

    final valueCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
    );
    valueCell.value = TextCellValue(value);
    valueCell.cellStyle = CellStyle(bold: true, italic: true);
  }

  String _assetTypeLabel(AssetType type, Map<String, String> labels) {
    return switch (type) {
      AssetType.cash => labels['assetType.cash'] ?? 'Cash',
      AssetType.bank => labels['assetType.bank'] ?? 'Bank',
      AssetType.eWallet => labels['assetType.eWallet'] ?? 'E-Wallet',
      AssetType.stock => labels['assetType.stock'] ?? 'Stock',
      AssetType.crypto => labels['assetType.crypto'] ?? 'Crypto',
    };
  }

  String _categoryTypeLabel(CategoryType type, Map<String, String> labels) {
    return switch (type) {
      CategoryType.income => labels['categoryType.income'] ?? 'Income',
      CategoryType.expense => labels['categoryType.expense'] ?? 'Expense',
    };
  }

  String _formatNumber(double value) {
    return NumberFormat('#,##0.##').format(value);
  }
}
