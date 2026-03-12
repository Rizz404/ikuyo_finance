part of 'backup_bloc.dart';

enum BackupStatus { initial, loading, success, failure }

class BackupState {
  final BackupStatus status;
  final BackupData? exportedData;
  final Map<String, int>? summary;
  final String? message;
  final BackupScheduleSettings schedule;

  const BackupState({
    this.status = BackupStatus.initial,
    this.exportedData,
    this.summary,
    this.message,
    this.schedule = BackupScheduleSettings.defaultSettings,
  });

  BackupState copyWith({
    BackupStatus? status,
    BackupData? exportedData,
    Map<String, int>? summary,
    String? message,
    BackupScheduleSettings? schedule,
  }) {
    return BackupState(
      status: status ?? this.status,
      exportedData: exportedData ?? this.exportedData,
      summary: summary ?? this.summary,
      message: message ?? this.message,
      schedule: schedule ?? this.schedule,
    );
  }

  int get totalItems => summary?.values.fold(0, (a, b) => a! + b) ?? 0;
}
