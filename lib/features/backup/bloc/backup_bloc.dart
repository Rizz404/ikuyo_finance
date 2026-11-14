import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/extensions/logger_extension.dart';
import 'package:ikuyo_finance/features/backup/models/backup_data.dart';
import 'package:ikuyo_finance/features/backup/models/backup_schedule_settings.dart';
import 'package:ikuyo_finance/features/backup/repositories/backup_repository.dart';
import 'package:ikuyo_finance/features/backup/services/auto_backup_key_store.dart';
import 'package:ikuyo_finance/features/backup/services/auto_backup_service.dart';

part 'backup_event.dart';
part 'backup_state.dart';

class BackupBloc extends Bloc<BackupEvent, BackupState> {
  final BackupRepository _repository;
  final AutoBackupService _autoBackupService;

  BackupBloc(this._repository, this._autoBackupService)
    : super(const BackupState()) {
    on<BackupExportRequested>(_onExportRequested);
    on<BackupImportRequested>(_onImportRequested);
    on<BackupSummaryRequested>(_onSummaryRequested);
    on<BackupScheduleLoaded>(_onScheduleLoaded);
    on<BackupScheduleToggled>(_onScheduleToggled);
    on<BackupAutoEnableRequested>(_onAutoEnableRequested);
    on<BackupAutoKeySetupRequested>(_onAutoKeySetupRequested);
    on<BackupScheduleTimeChanged>(_onScheduleTimeChanged);
    on<BackupScheduleFrequencyChanged>(_onScheduleFrequencyChanged);
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
            isImport: true,
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

  Future<void> _onScheduleLoaded(
    BackupScheduleLoaded event,
    Emitter<BackupState> emit,
  ) async {
    final settings = _autoBackupService.loadSettings();
    emit(state.copyWith(schedule: settings));
    logInfo('BackupBloc: schedule loaded — ${settings.toJsonString()}');
    await _refreshKeyState(emit);
  }

  Future<void> _refreshKeyState(Emitter<BackupState> emit) async {
    try {
      final keyState = await _autoBackupService.keyState();
      emit(state.copyWith(autoKeyState: keyState));
    } catch (e, s) {
      logError('BackupBloc: gagal membaca status kunci auto backup', e, s);
      emit(state.copyWith(autoKeyState: AutoBackupKeyState.unreadable));
    }
  }

  /// Hanya mematikan; menyalakan wajib lewat [BackupAutoEnableRequested]
  /// agar tidak pernah ada jadwal aktif baru tanpa kunci enkripsi.
  Future<void> _onScheduleToggled(
    BackupScheduleToggled event,
    Emitter<BackupState> emit,
  ) async {
    if (event.isEnabled) {
      logWarning('BackupBloc: enable tanpa passphrase ditolak');
      return;
    }
    final updated = state.schedule.copyWith(isEnabled: false);
    final applied = await _applySchedule(updated, emit, reschedule: true);
    if (applied) {
      // * Jadwal sudah mati: kunci tersimpan dibuang bersama jadwalnya
      try {
        await _autoBackupService.clearKey();
      } catch (e, s) {
        logError('BackupBloc: gagal menghapus kunci auto backup', e, s);
        _emitFailure(emit, LocaleKeys.backupAutoKeyClearFailed.tr());
      }
      await _refreshKeyState(emit);
    }
    logInfo('BackupBloc: schedule toggled — enabled=false');
  }

  Future<void> _onAutoEnableRequested(
    BackupAutoEnableRequested event,
    Emitter<BackupState> emit,
  ) async {
    emit(state.copyWith(autoKeyBusy: true));
    try {
      await _autoBackupService.setupKey(event.passphrase);
    } catch (e) {
      logError('BackupBloc: setup kunci auto backup gagal (${e.runtimeType})');
      emit(state.copyWith(autoKeyBusy: false));
      await _refreshKeyState(emit);
      _emitFailure(emit, LocaleKeys.backupAutoKeySetupFailed.tr());
      return;
    }
    final updated = state.schedule.copyWith(isEnabled: true);
    final applied = await _applySchedule(updated, emit, reschedule: true);
    if (!applied) {
      // * Jadwal gagal didaftarkan: jangan tinggalkan kunci tanpa jadwal
      try {
        await _autoBackupService.clearKey();
      } catch (e, s) {
        logError('BackupBloc: rollback kunci auto backup gagal', e, s);
      }
    }
    emit(state.copyWith(autoKeyBusy: false));
    await _refreshKeyState(emit);
    logInfo('BackupBloc: auto backup terenkripsi enabled=$applied');
  }

  Future<void> _onAutoKeySetupRequested(
    BackupAutoKeySetupRequested event,
    Emitter<BackupState> emit,
  ) async {
    emit(state.copyWith(autoKeyBusy: true));
    try {
      await _autoBackupService.setupKey(event.passphrase);
      emit(state.copyWith(autoKeyBusy: false));
      await _refreshKeyState(emit);
      logInfo('BackupBloc: kunci auto backup diperbarui');
    } catch (e) {
      logError('BackupBloc: setup kunci auto backup gagal (${e.runtimeType})');
      emit(state.copyWith(autoKeyBusy: false));
      await _refreshKeyState(emit);
      _emitFailure(emit, LocaleKeys.backupAutoKeySetupFailed.tr());
    }
  }

  void _emitFailure(Emitter<BackupState> emit, String message) {
    // * Pastikan listener melihat transisi status ke failure
    if (state.status == BackupStatus.failure) {
      emit(state.copyWith(status: BackupStatus.initial));
    }
    emit(state.copyWith(status: BackupStatus.failure, message: message));
  }

  Future<void> _onScheduleTimeChanged(
    BackupScheduleTimeChanged event,
    Emitter<BackupState> emit,
  ) async {
    final updated = state.schedule.copyWith(
      hour: event.hour,
      minute: event.minute,
    );
    await _applySchedule(updated, emit, reschedule: updated.isEnabled);
    logInfo('BackupBloc: schedule time changed — ${updated.formattedTime}');
  }

  Future<void> _onScheduleFrequencyChanged(
    BackupScheduleFrequencyChanged event,
    Emitter<BackupState> emit,
  ) async {
    final updated = state.schedule.copyWith(frequency: event.frequency);
    await _applySchedule(updated, emit, reschedule: updated.isEnabled);
    logInfo('BackupBloc: schedule frequency changed — ${event.frequency.name}');
  }

  /// Jadwalkan dulu, baru simpan & emit — agar settings tersimpan, state bloc,
  /// dan task WorkManager selalu konsisten (A06b).
  Future<bool> _applySchedule(
    BackupScheduleSettings updated,
    Emitter<BackupState> emit, {
    required bool reschedule,
  }) async {
    try {
      if (reschedule) await _autoBackupService.schedule(updated);
      await _autoBackupService.saveSettings(updated);
      emit(state.copyWith(schedule: updated));
      return true;
    } catch (e, s) {
      logError('BackupBloc: gagal menerapkan jadwal auto backup', e, s);
      emit(state.copyWith(schedule: _autoBackupService.loadSettings()));
      _emitFailure(emit, LocaleKeys.backupScreenAutoScheduleFailed.tr());
      return false;
    }
  }
}
