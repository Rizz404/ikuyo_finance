part of 'backup_bloc.dart';

abstract class BackupEvent {}

class BackupExportRequested extends BackupEvent {}

class BackupImportRequested extends BackupEvent {
  final BackupData backupData;

  BackupImportRequested(this.backupData);
}

class BackupSummaryRequested extends BackupEvent {}
