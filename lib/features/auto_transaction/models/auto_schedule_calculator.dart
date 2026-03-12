import 'package:ikuyo_finance/features/auto_transaction/models/auto_schedule_frequency.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_group.dart';

/// * Pure date-math utility — no Flutter, no ObjectBox, no side effects
class AutoScheduleCalculator {
  const AutoScheduleCalculator._();

  /// * Hitung jadwal berikutnya dari [from]
  static DateTime calculateNext(AutoTransactionGroup group, DateTime from) {
    final h = group.scheduleHour;
    final m = group.scheduleMinute;

    switch (group.scheduleFrequency) {
      case AutoScheduleFrequency.daily:
        var next = DateTime(from.year, from.month, from.day + 1, h, m);
        if (group.activeDaysMask != 0) {
          while (!_isDayActive(next.weekday, group.activeDaysMask)) {
            next = next.add(const Duration(days: 1));
          }
        }
        return next;

      case AutoScheduleFrequency.everyNDays:
        final interval = group.intervalDays.clamp(1, 365);
        return DateTime(from.year, from.month, from.day + interval, h, m);

      case AutoScheduleFrequency.weekly:
        return DateTime(from.year, from.month, from.day + 7, h, m);

      case AutoScheduleFrequency.monthly:
        final targetDay = group.dayOfMonth ?? group.startDate.day;
        return _addMonths(from.year, from.month, 1, targetDay, h, m);

      case AutoScheduleFrequency.yearly:
        final targetMonth = group.monthOfYear ?? group.startDate.month;
        final targetDay = group.dayOfMonth ?? group.startDate.day;
        return _clampDate(from.year + 1, targetMonth, targetDay, h, m);
    }
  }

  /// * Hitung jadwal pertama saat grup dibuat
  static DateTime calculateFirst(AutoTransactionGroup group) {
    final now = DateTime.now();
    final ref = group.startDate.isAfter(now) ? group.startDate : now;
    final h = group.scheduleHour;
    final m = group.scheduleMinute;
    DateTime candidate;

    switch (group.scheduleFrequency) {
      case AutoScheduleFrequency.daily:
        if (group.activeDaysMask != 0) {
          // * Cari hari aktif pertama mulai dari ref (inklusif)
          final prev = ref.subtract(const Duration(days: 1));
          candidate = calculateNext(
            group,
            DateTime(prev.year, prev.month, prev.day, h, m),
          );
        } else {
          candidate = DateTime(ref.year, ref.month, ref.day, h, m);
        }

      case AutoScheduleFrequency.everyNDays:
        candidate = DateTime(ref.year, ref.month, ref.day, h, m);

      case AutoScheduleFrequency.weekly:
        final targetDow = group.dayOfWeek ?? 1;
        final daysUntil = (targetDow - ref.weekday + 7) % 7;
        candidate = DateTime(ref.year, ref.month, ref.day + daysUntil, h, m);

      case AutoScheduleFrequency.monthly:
        final targetDay = group.dayOfMonth ?? group.startDate.day;
        candidate = _clampDate(ref.year, ref.month, targetDay, h, m);

      case AutoScheduleFrequency.yearly:
        final targetMonth = group.monthOfYear ?? group.startDate.month;
        final targetDay = group.dayOfMonth ?? group.startDate.day;
        candidate = _clampDate(ref.year, targetMonth, targetDay, h, m);
    }

    // * Jika kandidat sudah lewat, maju satu periode
    while (!candidate.isAfter(now)) {
      candidate = calculateNext(group, candidate);
    }

    return candidate;
  }

  // * weekday: 1=Senin, 7=Minggu (Dart convention)
  // * mask:    bit 0 = Senin, bit 6 = Minggu
  static bool _isDayActive(int weekday, int mask) =>
      (mask >> (weekday - 1)) & 1 == 1;

  static DateTime _addMonths(
    int year,
    int month,
    int months,
    int day,
    int h,
    int m,
  ) {
    int newMonth = month + months;
    int newYear = year;
    while (newMonth > 12) {
      newMonth -= 12;
      newYear++;
    }
    return _clampDate(newYear, newMonth, day, h, m);
  }

  static DateTime _clampDate(int year, int month, int day, int h, int m) {
    // * DateTime(y, m+1, 0) → hari terakhir bulan m
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day.clamp(1, lastDay), h, m);
  }
}
