import 'package:objectbox/objectbox.dart';
import 'package:ulid/ulid.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_group.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_log_status.dart';

@Entity()
class AutoTransactionLog {
  @Id()
  int id;

  @Unique()
  String ulid;

  final group = ToOne<AutoTransactionGroup>();

  // * Waktu yang seharusnya dieksekusi (jadwal)
  @Property(type: PropertyType.date)
  DateTime scheduledAt;

  // * Waktu eksekusi sebenarnya
  @Property(type: PropertyType.date)
  DateTime executedAt;

  // * Stored as int, mapped to AutoTransactionLogStatus enum
  int status;

  int successCount;
  int failureCount;

  // * Detail error jika status = failed / partial / skipped
  String? errorMessage;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  @Property(type: PropertyType.date)
  DateTime updatedAt;

  AutoTransactionLog({
    this.id = 0,
    String? ulid,
    required this.scheduledAt,
    required this.executedAt,
    this.status = 0, // * Default: success
    this.successCount = 0,
    this.failureCount = 0,
    this.errorMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : ulid = ulid ?? Ulid().toString(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  AutoTransactionLogStatus get logStatus =>
      AutoTransactionLogStatus.values[status];
  set logStatus(AutoTransactionLogStatus value) => status = value.index;
}
