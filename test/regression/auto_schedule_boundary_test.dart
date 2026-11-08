// Regression: AUTO-14. Daily active-day stepping must move by calendar days
// (a fixed 24h Duration drifts by an hour across a DST change), and an
// active-days mask with no weekday bits (possible via a restored backup) must
// not hang the scheduler. Run under a DST time zone to exercise the drift:
//   TZ=America/New_York flutter test test/regression/auto_schedule_boundary_test.dart
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_schedule_calculator.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_schedule_frequency.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_group.dart';

AutoTransactionGroup _daily(int mask) => AutoTransactionGroup(
      name: 'g',
      frequency: AutoScheduleFrequency.daily.index,
      scheduleHour: 8,
      scheduleMinute: 30,
      intervalDays: 1,
      activeDaysMask: mask,
      startDate: DateTime(2026, 1, 1),
    );

void main() {
  test('weekday-only stepping keeps the scheduled wall-clock time all year',
      () {
    // * Senin..Jumat; melompati akhir pekan memakai loop langkah hari
    final group = _daily(0x1F);
    var at = DateTime(2026, 1, 2, 8, 30);
    for (var i = 0; i < 300; i++) {
      final next = AutoScheduleCalculator.calculateNext(group, at);
      expect(next.hour, 8, reason: 'from $at got $next');
      expect(next.minute, 30, reason: 'from $at got $next');
      expect(next.weekday, lessThanOrEqualTo(DateTime.friday));
      expect(next.isAfter(at), isTrue);
      at = next;
    }
  });

  test('a mask with no weekday bits terminates and schedules the next day',
      () async {
    final next = await Isolate.run(
      () => AutoScheduleCalculator.calculateNext(
        _daily(128),
        DateTime(2026, 3, 2, 8, 30),
      ),
    ).timeout(const Duration(seconds: 5));

    expect(next, DateTime(2026, 3, 3, 8, 30));
  });
}
