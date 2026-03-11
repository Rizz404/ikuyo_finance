import 'package:flutter/widgets.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_schedule_frequency.dart';

class UpdateAutoGroupParams {
  final String ulid;
  final String? name;
  final ValueGetter<String?>? description;
  final AutoScheduleFrequency? frequency;
  final int? scheduleHour;
  final int? scheduleMinute;
  final ValueGetter<int?>? dayOfWeek;
  final ValueGetter<int?>? dayOfMonth;
  final ValueGetter<int?>? monthOfYear;
  final DateTime? startDate;
  final ValueGetter<DateTime?>? endDate;
  final bool? isActive;

  const UpdateAutoGroupParams({
    required this.ulid,
    this.name,
    this.description,
    this.frequency,
    this.scheduleHour,
    this.scheduleMinute,
    this.dayOfWeek,
    this.dayOfMonth,
    this.monthOfYear,
    this.startDate,
    this.endDate,
    this.isActive,
  });
}
