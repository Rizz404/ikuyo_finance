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

/// Mematikan auto backup (juga menghapus kunci tersimpan). Menyalakan
/// selalu lewat [BackupAutoEnableRequested] karena butuh passphrase.
class BackupScheduleToggled extends BackupEvent {
  final bool isEnabled;

  BackupScheduleToggled(this.isEnabled);
}

/// Menyalakan auto backup terenkripsi: kunci diturunkan dari passphrase,
/// disimpan, baru jadwal didaftarkan.
/// * toString disamarkan: TalkerBlocObserver mencetak event di debug
class BackupAutoEnableRequested extends BackupEvent {
  final String passphrase;

  BackupAutoEnableRequested(this.passphrase);

  @override
  String toString() => 'BackupAutoEnableRequested(redacted)';
}

/// Setup ulang/ganti passphrase auto backup tanpa mengubah jadwal.
class BackupAutoKeySetupRequested extends BackupEvent {
  final String passphrase;

  BackupAutoKeySetupRequested(this.passphrase);

  @override
  String toString() => 'BackupAutoKeySetupRequested(redacted)';
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
