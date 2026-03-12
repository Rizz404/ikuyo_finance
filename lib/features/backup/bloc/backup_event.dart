part of 'backup_bloc.dart';

abstract class BackupEvent {}

class BackupExportRequested extends BackupEvent {}

class BackupImportRequested extends BackupEvent {
  final BackupData backupData;

  BackupImportRequested(this.backupData);
}

class BackupSummaryRequested extends BackupEvent {}

// * Auto backup schedule events
class BackupScheduleLoaded extends BackupEvent {}

class BackupScheduleToggled extends BackupEvent {
  final bool isEnabled;

  BackupScheduleToggled(this.isEnabled);
}

class BackupScheduleTimeChanged extends BackupEvent {
  final int hour;
  final int minute;

  BackupScheduleTimeChanged({required this.hour, required this.minute});
}

class BackupScheduleFrequencyChanged extends BackupEvent {
  final BackupFrequency frequency;

  BackupScheduleFrequencyChanged(this.frequency);
}
