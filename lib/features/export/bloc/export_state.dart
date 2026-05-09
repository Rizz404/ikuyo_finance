part of 'export_bloc.dart';

enum ExportStatus { initial, loading, success, failure }

class ExportState {
  final ExportStatus status;
  final String? message;

  // * Path file yang berhasil disimpan
  final String? savedPath;

  // * Data untuk filter checklist
  final List<Asset> assets;
  final List<Category> categories;

  const ExportState({
    this.status = ExportStatus.initial,
    this.message,
    this.savedPath,
    this.assets = const [],
    this.categories = const [],
  });

  ExportState copyWith({
    ExportStatus? status,
    String? message,
    String? savedPath,
    List<Asset>? assets,
    List<Category>? categories,
  }) {
    return ExportState(
      status: status ?? this.status,
      message: message ?? this.message,
      savedPath: savedPath ?? this.savedPath,
      assets: assets ?? this.assets,
      categories: categories ?? this.categories,
    );
  }
}
