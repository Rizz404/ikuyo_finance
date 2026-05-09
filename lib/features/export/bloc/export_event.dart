part of 'export_bloc.dart';

sealed class ExportEvent {}

class ExportAssetsLoaded extends ExportEvent {}

class ExportCategoriesLoaded extends ExportEvent {}

class ExportExcelRequested extends ExportEvent {
  final ExportParams params;
  final String exportDirectory;

  // * Localized labels dikirim dari screen karena context tidak tersedia di repo
  final Map<String, String> labels;
  final String currencySymbol;

  ExportExcelRequested({
    required this.params,
    required this.exportDirectory,
    required this.labels,
    required this.currencySymbol,
  });
}
