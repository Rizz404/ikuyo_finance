import 'package:ikuyo_finance/features/auto_transaction/models/auto_schedule_frequency.dart';

class CreateAutoGroupParams {
  final String name;
  final String? description;
  final AutoScheduleFrequency frequency;
  final int scheduleHour;
  final int scheduleMinute;
  final int? dayOfWeek;
  final int? dayOfMonth;
  final int? monthOfYear;
  final int intervalDays;
  final int activeDaysMask;
  final DateTime startDate;
  final DateTime? endDate;

  const CreateAutoGroupParams({
    required this.name,
    this.description,
    required this.frequency,
    required this.scheduleHour,
    required this.scheduleMinute,
    this.dayOfWeek,
    this.dayOfMonth,
    this.monthOfYear,
    this.intervalDays = 1,
    this.activeDaysMask = 0,
    required this.startDate,
    this.endDate,
  });
}
