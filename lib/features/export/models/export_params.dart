class ExportParams {
  final DateTime? startDate;
  final DateTime? endDate;

  // * ULID dari asset/category yang DIKELUARKAN dari ekspor
  final List<String> excludedAssetUlids;
  final List<String> excludedCategoryUlids;

  const ExportParams({
    this.startDate,
    this.endDate,
    this.excludedAssetUlids = const [],
    this.excludedCategoryUlids = const [],
  });
}
