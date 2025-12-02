import 'package:fpdart/fpdart.dart';
import 'package:ikuyo_finance/core/wrapper/failure.dart';
import 'package:ikuyo_finance/core/wrapper/success.dart';
import 'package:ikuyo_finance/features/backup/models/backup_data.dart';

abstract class BackupRepository {
  /// Export semua data ke BackupData
  TaskEither<Failure, Success<BackupData>> exportData();

  /// Import data dari BackupData (replace existing)
  TaskEither<Failure, Success<void>> importData(BackupData backupData);

  /// Get summary of current data count
  TaskEither<Failure, Success<Map<String, int>>> getDataSummary();
}
