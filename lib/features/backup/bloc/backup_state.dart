part of 'backup_bloc.dart';

enum BackupStatus { initial, loading, success, failure }

class BackupState {
  final BackupStatus status;
  final BackupData? exportedData;
  final Map<String, int>? summary;
  final String? message;
  final BackupScheduleSettings schedule;
  final bool isImport;

  const BackupState({
    this.status = BackupStatus.initial,
    this.exportedData,
    this.summary,
    this.message,
    this.schedule = BackupScheduleSettings.defaultSettings,
    this.isImport = false,
  });

  BackupState copyWith({
    BackupStatus? status,
    BackupData? exportedData,
    Map<String, int>? summary,
    String? message,
    BackupScheduleSettings? schedule,
    bool? isImport,
  }) {
    return BackupState(
      status: status ?? this.status,
      // * exportedData & isImport bersifat one-shot: tidak dibawa ke state
      // * berikutnya agar listener tidak memproses ulang hasil lama (BKSEC-5)
      exportedData: exportedData,
      summary: summary ?? this.summary,
      message: message ?? this.message,
      schedule: schedule ?? this.schedule,
      isImport: isImport ?? false,
    );
  }

  int get totalItems => summary?.values.fold(0, (a, b) => a! + b) ?? 0;
}
