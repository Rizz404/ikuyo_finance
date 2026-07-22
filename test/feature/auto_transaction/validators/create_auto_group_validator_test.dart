import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_schedule_frequency.dart';
import 'package:ikuyo_finance/features/auto_transaction/validators/create_auto_group_validator.dart';

import '../../../support/locale_test_helper.dart';

void main() {
  group('CreateAutoGroupValidator.name', () {
    testWidgets('rejects null', (tester) async {
      await loadTestLocale(tester);
      expect(CreateAutoGroupValidator.name(null), isNotNull);
    });

    testWidgets('rejects an empty string', (tester) async {
      await loadTestLocale(tester);
      expect(CreateAutoGroupValidator.name(''), isNotNull);
    });

    testWidgets('rejects a whitespace-only string', (tester) async {
      await loadTestLocale(tester);
      expect(CreateAutoGroupValidator.name('   '), isNotNull);
    });

    testWidgets('accepts a valid name', (tester) async {
      await loadTestLocale(tester);
      expect(CreateAutoGroupValidator.name('Monthly rent'), isNull);
    });
  });

  group('CreateAutoGroupValidator.frequency', () {
    testWidgets('rejects null', (tester) async {
      await loadTestLocale(tester);
      expect(CreateAutoGroupValidator.frequency(null), isNotNull);
    });

    testWidgets('accepts a non-null value', (tester) async {
      await loadTestLocale(tester);
      expect(CreateAutoGroupValidator.frequency(AutoScheduleFrequency.daily), isNull);
    });
  });

  group('CreateAutoGroupValidator.scheduleTime', () {
    testWidgets('never produces an error', (tester) async {
      await loadTestLocale(tester);
      expect(CreateAutoGroupValidator.scheduleTime(null), isNull);
    });
  });

  group('CreateAutoGroupValidator.dayOfWeek', () {
    testWidgets('is required only when frequency is weekly', (tester) async {
      await loadTestLocale(tester);
      expect(
        CreateAutoGroupValidator.dayOfWeek(null, AutoScheduleFrequency.weekly),
        isNotNull,
      );
      expect(
        CreateAutoGroupValidator.dayOfWeek(1, AutoScheduleFrequency.weekly),
        isNull,
      );
    });

    testWidgets('is optional for every other frequency', (tester) async {
      await loadTestLocale(tester);
      for (final freq in [
        AutoScheduleFrequency.daily,
        AutoScheduleFrequency.everyNDays,
        AutoScheduleFrequency.monthly,
        AutoScheduleFrequency.yearly,
      ]) {
        expect(CreateAutoGroupValidator.dayOfWeek(null, freq), isNull);
      }
    });
  });

  group('CreateAutoGroupValidator.dayOfMonth', () {
    testWidgets('required and validated for monthly frequency', (tester) async {
      await loadTestLocale(tester);
      expect(
        CreateAutoGroupValidator.dayOfMonth(null, AutoScheduleFrequency.monthly),
        isNotNull,
      );
      expect(
        CreateAutoGroupValidator.dayOfMonth('', AutoScheduleFrequency.monthly),
        isNotNull,
      );
      expect(
        CreateAutoGroupValidator.dayOfMonth('abc', AutoScheduleFrequency.monthly),
        isNotNull,
      );
      expect(
        CreateAutoGroupValidator.dayOfMonth('0', AutoScheduleFrequency.monthly),
        isNotNull,
      );
      expect(
        CreateAutoGroupValidator.dayOfMonth('29', AutoScheduleFrequency.monthly),
        isNotNull,
      );
      expect(
        CreateAutoGroupValidator.dayOfMonth('1', AutoScheduleFrequency.monthly),
        isNull,
      );
      expect(
        CreateAutoGroupValidator.dayOfMonth('28', AutoScheduleFrequency.monthly),
        isNull,
      );
    });

    testWidgets('required and validated for yearly frequency too', (tester) async {
      await loadTestLocale(tester);
      expect(
        CreateAutoGroupValidator.dayOfMonth(null, AutoScheduleFrequency.yearly),
        isNotNull,
      );
      expect(
        CreateAutoGroupValidator.dayOfMonth('15', AutoScheduleFrequency.yearly),
        isNull,
      );
    });

    testWidgets('is optional for daily/weekly/everyNDays', (tester) async {
      await loadTestLocale(tester);
      expect(
        CreateAutoGroupValidator.dayOfMonth(null, AutoScheduleFrequency.daily),
        isNull,
      );
      expect(
        CreateAutoGroupValidator.dayOfMonth(null, AutoScheduleFrequency.weekly),
        isNull,
      );
      expect(
        CreateAutoGroupValidator.dayOfMonth(null, AutoScheduleFrequency.everyNDays),
        isNull,
      );
    });
  });

  group('CreateAutoGroupValidator.monthOfYear', () {
    testWidgets('is required only when frequency is yearly', (tester) async {
      await loadTestLocale(tester);
      expect(
        CreateAutoGroupValidator.monthOfYear(null, AutoScheduleFrequency.yearly),
        isNotNull,
      );
      expect(
        CreateAutoGroupValidator.monthOfYear(3, AutoScheduleFrequency.yearly),
        isNull,
      );
      expect(
        CreateAutoGroupValidator.monthOfYear(null, AutoScheduleFrequency.monthly),
        isNull,
      );
    });
  });

  group('CreateAutoGroupValidator.intervalDays', () {
    testWidgets('required and validated for everyNDays frequency', (tester) async {
      await loadTestLocale(tester);
      expect(
        CreateAutoGroupValidator.intervalDays(null, AutoScheduleFrequency.everyNDays),
        isNotNull,
      );
      expect(
        CreateAutoGroupValidator.intervalDays('', AutoScheduleFrequency.everyNDays),
        isNotNull,
      );
      expect(
        CreateAutoGroupValidator.intervalDays('abc', AutoScheduleFrequency.everyNDays),
        isNotNull,
      );
      expect(
        CreateAutoGroupValidator.intervalDays('0', AutoScheduleFrequency.everyNDays),
        isNotNull,
      );
      expect(
        CreateAutoGroupValidator.intervalDays('-1', AutoScheduleFrequency.everyNDays),
        isNotNull,
      );
      expect(
        CreateAutoGroupValidator.intervalDays('1', AutoScheduleFrequency.everyNDays),
        isNull,
      );
      expect(
        CreateAutoGroupValidator.intervalDays('365', AutoScheduleFrequency.everyNDays),
        isNull,
      );
    });

    testWidgets('is optional for every other frequency', (tester) async {
      await loadTestLocale(tester);
      expect(
        CreateAutoGroupValidator.intervalDays(null, AutoScheduleFrequency.daily),
        isNull,
      );
    });
  });

  group('CreateAutoGroupValidator.startDate', () {
    testWidgets('rejects null', (tester) async {
      await loadTestLocale(tester);
      expect(CreateAutoGroupValidator.startDate(null), isNotNull);
    });

    testWidgets('accepts a valid date', (tester) async {
      await loadTestLocale(tester);
      expect(CreateAutoGroupValidator.startDate(DateTime.now()), isNull);
    });
  });

  group('CreateAutoGroupValidator.endDate', () {
    testWidgets('is always optional', (tester) async {
      await loadTestLocale(tester);
      expect(CreateAutoGroupValidator.endDate(null), isNull);
      expect(CreateAutoGroupValidator.endDate(DateTime.now()), isNull);
    });
  });
}
