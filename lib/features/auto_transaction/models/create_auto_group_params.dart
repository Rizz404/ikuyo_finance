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
    required this.startDate,
    this.endDate,
  });
}
