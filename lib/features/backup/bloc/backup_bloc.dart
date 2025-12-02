import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';
import 'package:ikuyo_finance/features/backup/models/backup_data.dart';
import 'package:ikuyo_finance/features/backup/repositories/backup_repository.dart';

part 'backup_event.dart';
part 'backup_state.dart';

class BackupBloc extends Bloc<BackupEvent, BackupState> {
  final BackupRepository _repository;

  BackupBloc(this._repository) : super(const BackupState()) {
    on<BackupExportRequested>(_onExportRequested);
    on<BackupImportRequested>(_onImportRequested);
    on<BackupSummaryRequested>(_onSummaryRequested);
  }

  Future<void> _onExportRequested(
    BackupExportRequested event,
    Emitter<BackupState> emit,
  ) async {
    emit(state.copyWith(status: BackupStatus.loading));

    final result = await _repository.exportData().run();

    result.fold(
      (failure) {
        logError('Export failed', failure.message, StackTrace.current);
        emit(
          state.copyWith(
            status: BackupStatus.failure,
            message: failure.message,
          ),
        );
      },
      (success) {
        logInfo('Export success: ${success.data?.totalItems} items');
        emit(
          state.copyWith(
            status: BackupStatus.success,
            exportedData: success.data,
            message: success.message,
          ),
        );
      },
    );
  }

  Future<void> _onImportRequested(
    BackupImportRequested event,
    Emitter<BackupState> emit,
  ) async {
    emit(state.copyWith(status: BackupStatus.loading));

    final result = await _repository.importData(event.backupData).run();

    result.fold(
      (failure) {
        logError('Import failed', failure.message, StackTrace.current);
        emit(
          state.copyWith(
            status: BackupStatus.failure,
            message: failure.message,
          ),
        );
      },
      (success) {
        logInfo('Import success');
        emit(
          state.copyWith(
            status: BackupStatus.success,
            message: success.message,
          ),
        );
      },
    );
  }

  Future<void> _onSummaryRequested(
    BackupSummaryRequested event,
    Emitter<BackupState> emit,
  ) async {
    final result = await _repository.getDataSummary().run();

    result.fold(
      (failure) => emit(state.copyWith(message: failure.message)),
      (success) => emit(state.copyWith(summary: success.data)),
    );
  }
}
