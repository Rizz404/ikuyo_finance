import 'package:objectbox/objectbox.dart';
import 'package:ulid/ulid.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_schedule_frequency.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_item.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_log.dart';

@Entity()
class AutoTransactionGroup {
  @Id()
  int id;

  @Unique()
  String ulid;

  String name;
  String? description;

  // * Master toggle — false = tidak pernah jalan sama sekali
  bool isActive;

  // * Pause sementara
  bool isPaused;

  @Property(type: PropertyType.date)
  DateTime? pauseStartAt;

  // * null = pause manual (sampai di-resume manual)
  @Property(type: PropertyType.date)
  DateTime? pauseEndAt;

  // * Stored as int, mapped to AutoScheduleFrequency enum
  int frequency;

  int scheduleHour; // * 0-23
  int scheduleMinute; // * 0-59

  // * 1-7 (1=Mon, 7=Sun), hanya untuk weekly
  int? dayOfWeek;

  // * 1-28, untuk monthly & yearly
  int? dayOfMonth;

  // * 1-12, hanya untuk yearly
  int? monthOfYear;

  // * Interval hari untuk frequency everyNDays
  int intervalDays;

  // * Bitmask hari aktif untuk frequency daily (0=semua hari, bit0=Senin..bit6=Minggu)
  int activeDaysMask;

  @Property(type: PropertyType.date)
  DateTime startDate;

  // * null = unlimited
  @Property(type: PropertyType.date)
  DateTime? endDate;

  // * Kunci scheduler — eksekusi saat nextExecutedAt ≤ now
  @Property(type: PropertyType.date)
  DateTime? nextExecutedAt;

  @Property(type: PropertyType.date)
  DateTime? lastExecutedAt;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  @Property(type: PropertyType.date)
  DateTime updatedAt;

  // * Backlink — semua item yang dimiliki grup ini
  @Backlink('group')
  final items = ToMany<AutoTransactionItem>();

  // * Backlink — semua log eksekusi grup ini
  @Backlink('group')
  final logs = ToMany<AutoTransactionLog>();

  AutoTransactionGroup({
    this.id = 0,
    String? ulid,
    required this.name,
    this.description,
    this.isActive = true,
    this.isPaused = false,
    this.pauseStartAt,
    this.pauseEndAt,
    this.frequency = 0, // * Default: daily
    this.scheduleHour = 8,
    this.scheduleMinute = 0,
    this.dayOfWeek,
    this.dayOfMonth,
    this.monthOfYear,
    this.intervalDays = 1,
    this.activeDaysMask = 0,
    required this.startDate,
    this.endDate,
    this.nextExecutedAt,
    this.lastExecutedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : ulid = ulid ?? Ulid().toString(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  AutoScheduleFrequency get scheduleFrequency =>
      AutoScheduleFrequency.values[frequency];
  set scheduleFrequency(AutoScheduleFrequency value) => frequency = value.index;

  // * true jika grup sedang dalam masa pause aktif
  bool isCurrentlyPaused() {
    if (!isPaused) return false;
    if (pauseEndAt == null) return true; // * Pause manual tanpa batas
    return pauseEndAt!.isAfter(DateTime.now());
  }
}
