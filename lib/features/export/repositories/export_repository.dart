import 'package:fpdart/fpdart.dart';
import 'package:ikuyo_finance/core/wrapper/failure.dart';
import 'package:ikuyo_finance/core/wrapper/success.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/export/models/export_params.dart';

abstract class ExportRepository {
  /// Ambil semua asset untuk filter checklist
  TaskEither<Failure, Success<List<Asset>>> getAssetsForFilter();

  /// Ambil semua category untuk filter checklist
  TaskEither<Failure, Success<List<Category>>> getCategoriesForFilter();

  /// Generate file Excel dan simpan ke [exportDirectory]
  TaskEither<Failure, Success<String>> exportToExcel({
    required ExportParams params,
    required String exportDirectory,
    required Map<String, String> labels,
    required String currencySymbol,
  });
}
