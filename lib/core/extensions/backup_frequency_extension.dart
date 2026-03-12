import 'package:ikuyo_finance/features/backup/models/backup_schedule_settings.dart';

extension BackupFrequencyExtension on BackupFrequency {
  String get label => switch (this) {
    BackupFrequency.daily => 'Daily',
    BackupFrequency.weekly => 'Weekly',
    BackupFrequency.monthly => 'Monthly',
  };

  String get labelId => switch (this) {
    BackupFrequency.daily => 'Setiap Hari',
    BackupFrequency.weekly => 'Setiap Minggu',
    BackupFrequency.monthly => 'Setiap Bulan',
  };
}
