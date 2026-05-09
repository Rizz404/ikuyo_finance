import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/extensions/logger_extension.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/export/models/export_params.dart';
import 'package:ikuyo_finance/features/export/repositories/export_repository.dart';

part 'export_event.dart';
part 'export_state.dart';

class ExportBloc extends Bloc<ExportEvent, ExportState> {
  final ExportRepository _repository;

  ExportBloc(this._repository) : super(const ExportState()) {
    on<ExportAssetsLoaded>(_onAssetsLoaded);
    on<ExportCategoriesLoaded>(_onCategoriesLoaded);
    on<ExportExcelRequested>(_onExcelRequested);
  }

  Future<void> _onAssetsLoaded(
    ExportAssetsLoaded event,
    Emitter<ExportState> emit,
  ) async {
    final result = await _repository.getAssetsForFilter().run();
    result.fold(
      (failure) => logError('Gagal memuat aset', failure.message, StackTrace.current),
      (success) => emit(state.copyWith(assets: success.data ?? [])),
    );
  }

  Future<void> _onCategoriesLoaded(
    ExportCategoriesLoaded event,
    Emitter<ExportState> emit,
  ) async {
    final result = await _repository.getCategoriesForFilter().run();
    result.fold(
      (failure) => logError(
        'Gagal memuat kategori',
        failure.message,
        StackTrace.current,
      ),
      (success) => emit(state.copyWith(categories: success.data ?? [])),
    );
  }

  Future<void> _onExcelRequested(
    ExportExcelRequested event,
    Emitter<ExportState> emit,
  ) async {
    emit(state.copyWith(status: ExportStatus.loading));

    final result = await _repository.exportToExcel(
      params: event.params,
      exportDirectory: event.exportDirectory,
      labels: event.labels,
      currencySymbol: event.currencySymbol,
    ).run();

    result.fold(
      (failure) {
        logError('Export Excel gagal', failure.message, StackTrace.current);
        emit(
          state.copyWith(
            status: ExportStatus.failure,
            message: failure.message,
          ),
        );
      },
      (success) {
        logInfo('Export Excel berhasil: ${success.data}');
        emit(
          state.copyWith(
            status: ExportStatus.success,
            savedPath: success.data,
            message: success.message,
          ),
        );
      },
    );
  }
}
