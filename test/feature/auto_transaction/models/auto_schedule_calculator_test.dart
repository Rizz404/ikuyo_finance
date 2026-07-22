import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_schedule_calculator.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_schedule_frequency.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_group.dart';

/// Builds a group with sensible defaults so each test only has to override
/// the fields relevant to the scenario under test.
AutoTransactionGroup _group({
  AutoScheduleFrequency frequency = AutoScheduleFrequency.daily,
  int scheduleHour = 8,
  int scheduleMinute = 0,
  int? dayOfWeek,
  int? dayOfMonth,
  int? monthOfYear,
  int intervalDays = 1,
  int activeDaysMask = 0,
  required DateTime startDate,
}) {
  return AutoTransactionGroup(
    name: 'Test group',
    frequency: frequency.index,
    scheduleHour: scheduleHour,
    scheduleMinute: scheduleMinute,
    dayOfWeek: dayOfWeek,
    dayOfMonth: dayOfMonth,
    monthOfYear: monthOfYear,
    intervalDays: intervalDays,
    activeDaysMask: activeDaysMask,
    startDate: startDate,
  );
}

void main() {
  group('calculateNext - daily', () {
    test('advances by exactly 1 day at the scheduled time when mask is 0', () {
      final from = DateTime(2025, 7, 13, 10, 30);
      final group = _group(
        frequency: AutoScheduleFrequency.daily,
        scheduleHour: 9,
        scheduleMinute: 15,
        startDate: from,
      );

      final next = AutoScheduleCalculator.calculateNext(group, from);

      expect(next, DateTime(2025, 7, 14, 9, 15));
    });

    test('skips inactive days according to activeDaysMask', () {
      final from = DateTime(2025, 7, 13, 8, 0);
      // * Only allow the day that is 2 days after `from` — this forces the
      // * calculator to skip the immediate next day and land 2 days out,
      // * regardless of what weekday `from` actually falls on.
      final skippedDay = DateTime(from.year, from.month, from.day + 1);
      final allowedDay = DateTime(from.year, from.month, from.day + 2);
      final mask = 1 << (allowedDay.weekday - 1);
      // * Sanity check: the two candidate weekdays must differ for the mask
      // * to be meaningful.
      expect(skippedDay.weekday == allowedDay.weekday, isFalse);

      final group = _group(
        frequency: AutoScheduleFrequency.daily,
        scheduleHour: 8,
        scheduleMinute: 0,
        activeDaysMask: mask,
        startDate: from,
      );

      final next = AutoScheduleCalculator.calculateNext(group, from);

      expect(next, DateTime(allowedDay.year, allowedDay.month, allowedDay.day, 8, 0));
    });

    test('mask allowing the immediate next day returns that day unchanged', () {
      final from = DateTime(2025, 7, 13, 8, 0);
      final nextDay = DateTime(from.year, from.month, from.day + 1);
      final mask = 1 << (nextDay.weekday - 1);

      final group = _group(
        frequency: AutoScheduleFrequency.daily,
        scheduleHour: 8,
        scheduleMinute: 0,
        activeDaysMask: mask,
        startDate: from,
      );

      final next = AutoScheduleCalculator.calculateNext(group, from);

      expect(next, DateTime(nextDay.year, nextDay.month, nextDay.day, 8, 0));
    });
  });

  group('calculateNext - everyNDays', () {
    test('advances by intervalDays', () {
      final from = DateTime(2025, 1, 1, 8, 0);
      final group = _group(
        frequency: AutoScheduleFrequency.everyNDays,
        intervalDays: 5,
        startDate: from,
      );

      final next = AutoScheduleCalculator.calculateNext(group, from);

      expect(next, DateTime(2025, 1, 6, 8, 0));
    });

    test('clamps intervalDays above 365 down to 365', () {
      final from = DateTime(2025, 1, 1, 8, 0);
      final group = _group(
        frequency: AutoScheduleFrequency.everyNDays,
        intervalDays: 1000,
        startDate: from,
      );

      final next = AutoScheduleCalculator.calculateNext(group, from);

      expect(next, from.add(const Duration(days: 365)));
    });

    test('clamps intervalDays below 1 up to 1', () {
      final from = DateTime(2025, 1, 1, 8, 0);
      final group = _group(
        frequency: AutoScheduleFrequency.everyNDays,
        intervalDays: -10,
        startDate: from,
      );

      final next = AutoScheduleCalculator.calculateNext(group, from);

      expect(next, DateTime(2025, 1, 2, 8, 0));
    });
  });

  group('calculateNext - weekly', () {
    test('advances by exactly 7 days at the scheduled time', () {
      final from = DateTime(2025, 7, 13, 8, 0);
      final group = _group(
        frequency: AutoScheduleFrequency.weekly,
        startDate: from,
      );

      final next = AutoScheduleCalculator.calculateNext(group, from);

      expect(next, DateTime(2025, 7, 20, 8, 0));
    });

    test('ignores dayOfWeek — always exactly 7 days from `from`', () {
      final from = DateTime(2025, 7, 13, 8, 0);
      // * dayOfWeek deliberately set to something that does not match `from`.
      final mismatchedDow = (from.weekday % 7) + 1;
      final group = _group(
        frequency: AutoScheduleFrequency.weekly,
        dayOfWeek: mismatchedDow,
        startDate: from,
      );

      final next = AutoScheduleCalculator.calculateNext(group, from);

      expect(next, from.add(const Duration(days: 7)));
    });
  });

  group('calculateNext - monthly', () {
    test('advances to the same day next month', () {
      final from = DateTime(2025, 3, 15, 8, 0);
      final group = _group(
        frequency: AutoScheduleFrequency.monthly,
        dayOfMonth: 15,
        startDate: from,
      );

      final next = AutoScheduleCalculator.calculateNext(group, from);

      expect(next, DateTime(2025, 4, 15, 8, 0));
    });

    test('clamps day 31 to the last day of a shorter month (Jan -> Feb)', () {
      final from = DateTime(2025, 1, 31, 8, 0);
      final group = _group(
        frequency: AutoScheduleFrequency.monthly,
        dayOfMonth: 31,
        startDate: from,
      );

      final next = AutoScheduleCalculator.calculateNext(group, from);

      // * 2025 is not a leap year, so February has 28 days.
      expect(next, DateTime(2025, 2, 28, 8, 0));
    });

    test('clamps to Feb 29 in a leap year when dayOfMonth is 31', () {
      final from = DateTime(2024, 1, 31, 8, 0);
      final group = _group(
        frequency: AutoScheduleFrequency.monthly,
        dayOfMonth: 31,
        startDate: from,
      );

      final next = AutoScheduleCalculator.calculateNext(group, from);

      // * 2024 is a leap year, so February has 29 days.
      expect(next, DateTime(2024, 2, 29, 8, 0));
    });

    test('falls back to startDate.day when dayOfMonth is null', () {
      final startDate = DateTime(2025, 3, 20, 8, 0);
      final from = DateTime(2025, 5, 20, 8, 0);
      final group = _group(
        frequency: AutoScheduleFrequency.monthly,
        startDate: startDate,
      );

      final next = AutoScheduleCalculator.calculateNext(group, from);

      expect(next, DateTime(2025, 6, 20, 8, 0));
    });

    test('rolls over the year on a December -> January transition', () {
      final from = DateTime(2025, 12, 15, 8, 0);
      final group = _group(
        frequency: AutoScheduleFrequency.monthly,
        dayOfMonth: 15,
        startDate: from,
      );

      final next = AutoScheduleCalculator.calculateNext(group, from);

      expect(next, DateTime(2026, 1, 15, 8, 0));
    });
  });

  group('calculateNext - yearly', () {
    test('advances to the same month/day next year', () {
      final from = DateTime(2025, 6, 10, 8, 0);
      final group = _group(
        frequency: AutoScheduleFrequency.yearly,
        monthOfYear: 6,
        dayOfMonth: 10,
        startDate: from,
      );

      final next = AutoScheduleCalculator.calculateNext(group, from);

      expect(next, DateTime(2026, 6, 10, 8, 0));
    });

    test('clamps Feb 29 down to Feb 28 when the next year is not a leap year', () {
      final from = DateTime(2024, 2, 29, 8, 0);
      final group = _group(
        frequency: AutoScheduleFrequency.yearly,
        monthOfYear: 2,
        dayOfMonth: 29,
        startDate: from,
      );

      final next = AutoScheduleCalculator.calculateNext(group, from);

      expect(next, DateTime(2025, 2, 28, 8, 0));
    });

    test('falls back to startDate month/day when monthOfYear/dayOfMonth are null', () {
      final startDate = DateTime(2024, 9, 5, 8, 0);
      final from = DateTime(2025, 9, 5, 8, 0);
      final group = _group(
        frequency: AutoScheduleFrequency.yearly,
        startDate: startDate,
      );

      final next = AutoScheduleCalculator.calculateNext(group, from);

      expect(next, DateTime(2026, 9, 5, 8, 0));
    });
  });

  group('calculateFirst', () {
    test('daily: schedules for the start date itself (already after now)', () {
      final startDate = DateTime.now().add(const Duration(days: 10));
      final group = _group(
        frequency: AutoScheduleFrequency.daily,
        scheduleHour: 8,
        scheduleMinute: 0,
        startDate: startDate,
      );

      final first = AutoScheduleCalculator.calculateFirst(group);

      expect(first, DateTime(startDate.year, startDate.month, startDate.day, 8, 0));
    });

    test('daily with mask: skips to the first active day on/after the start date', () {
      final startDate = DateTime.now().add(const Duration(days: 10));
      // * Disallow startDate's own weekday, but allow the day after it — the
      // * "inclusive search" in calculateFirst should then land 1 day later.
      final dayAfter = startDate.add(const Duration(days: 1));
      final mask = 1 << (dayAfter.weekday - 1);

      final group = _group(
        frequency: AutoScheduleFrequency.daily,
        scheduleHour: 8,
        scheduleMinute: 0,
        activeDaysMask: mask,
        startDate: startDate,
      );

      final first = AutoScheduleCalculator.calculateFirst(group);

      expect(first, DateTime(dayAfter.year, dayAfter.month, dayAfter.day, 8, 0));
    });

    test('everyNDays: schedules for the start date itself', () {
      final startDate = DateTime.now().add(const Duration(days: 5));
      final group = _group(
        frequency: AutoScheduleFrequency.everyNDays,
        intervalDays: 3,
        scheduleHour: 8,
        scheduleMinute: 0,
        startDate: startDate,
      );

      final first = AutoScheduleCalculator.calculateFirst(group);

      expect(first, DateTime(startDate.year, startDate.month, startDate.day, 8, 0));
    });

    test('weekly: lands on the start date when dayOfWeek matches its weekday', () {
      final startDate = DateTime.now().add(const Duration(days: 14));
      final group = _group(
        frequency: AutoScheduleFrequency.weekly,
        dayOfWeek: startDate.weekday,
        scheduleHour: 8,
        scheduleMinute: 0,
        startDate: startDate,
      );

      final first = AutoScheduleCalculator.calculateFirst(group);

      expect(first, DateTime(startDate.year, startDate.month, startDate.day, 8, 0));
    });

    test('weekly: advances to the next occurrence of dayOfWeek after the start date', () {
      final startDate = DateTime.now().add(const Duration(days: 14));
      final targetDow = startDate.weekday == 7 ? 1 : startDate.weekday + 1;
      final group = _group(
        frequency: AutoScheduleFrequency.weekly,
        dayOfWeek: targetDow,
        scheduleHour: 8,
        scheduleMinute: 0,
        startDate: startDate,
      );

      final first = AutoScheduleCalculator.calculateFirst(group);
      final expectedDate = startDate.add(const Duration(days: 1));

      expect(
        first,
        DateTime(expectedDate.year, expectedDate.month, expectedDate.day, 8, 0),
      );
    });

    test('monthly: uses dayOfMonth relative to the start date', () {
      final startDate = DateTime.now().add(const Duration(days: 20));
      final group = _group(
        frequency: AutoScheduleFrequency.monthly,
        dayOfMonth: startDate.day,
        scheduleHour: 8,
        scheduleMinute: 0,
        startDate: startDate,
      );

      final first = AutoScheduleCalculator.calculateFirst(group);

      expect(first, DateTime(startDate.year, startDate.month, startDate.day, 8, 0));
    });

    test('yearly: uses monthOfYear/dayOfMonth relative to the start date', () {
      final startDate = DateTime.now().add(const Duration(days: 30));
      final group = _group(
        frequency: AutoScheduleFrequency.yearly,
        monthOfYear: startDate.month,
        dayOfMonth: startDate.day,
        scheduleHour: 8,
        scheduleMinute: 0,
        startDate: startDate,
      );

      final first = AutoScheduleCalculator.calculateFirst(group);

      expect(first, DateTime(startDate.year, startDate.month, startDate.day, 8, 0));
    });

    test('advances past a candidate that has already passed relative to now', () {
      // * startDate in the past -> ref becomes "now", and scheduling at
      // * 00:00 guarantees the initial candidate is already behind "now",
      // * forcing the while-loop in calculateFirst to advance one period.
      final now = DateTime.now();
      final startDate = now.subtract(const Duration(days: 5));
      final group = _group(
        frequency: AutoScheduleFrequency.daily,
        scheduleHour: 0,
        scheduleMinute: 0,
        startDate: startDate,
      );

      final first = AutoScheduleCalculator.calculateFirst(group);
      final tomorrow = now.add(const Duration(days: 1));

      expect(first, DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 0, 0));
    });

    test('the returned date is always strictly after now', () {
      final startDate = DateTime.now().subtract(const Duration(days: 100));
      final group = _group(
        frequency: AutoScheduleFrequency.monthly,
        dayOfMonth: 1,
        scheduleHour: 0,
        scheduleMinute: 0,
        startDate: startDate,
      );

      final before = DateTime.now();
      final first = AutoScheduleCalculator.calculateFirst(group);

      expect(first.isAfter(before), isTrue);
    });
  });
}
