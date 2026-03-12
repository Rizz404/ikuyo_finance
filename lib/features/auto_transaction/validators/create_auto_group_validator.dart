import 'package:easy_localization/easy_localization.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_schedule_frequency.dart';

class CreateAutoGroupValidator {
  const CreateAutoGroupValidator._();

  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) {
      return LocaleKeys.autoTransactionValidatorNameRequired.tr();
    }
    return null;
  }

  static String? frequency(dynamic value) {
    if (value == null) {
      return LocaleKeys.autoTransactionValidatorFrequencyRequired.tr();
    }
    return null;
  }

  static String? scheduleTime(dynamic value) {
    // * AppTimePicker always provides a valid TimeOfDay — no validation needed
    return null;
  }

  static String? dayOfWeek(dynamic value, AutoScheduleFrequency frequency) {
    if (frequency == AutoScheduleFrequency.weekly) {
      if (value == null) {
        return LocaleKeys.autoTransactionValidatorDayOfWeekRequired.tr();
      }
    }
    return null;
  }

  static String? dayOfMonth(String? value, AutoScheduleFrequency frequency) {
    if (frequency == AutoScheduleFrequency.monthly ||
        frequency == AutoScheduleFrequency.yearly) {
      if (value == null || value.trim().isEmpty) {
        return LocaleKeys.autoTransactionValidatorDayOfMonthRequired.tr();
      }
      final parsed = int.tryParse(value.trim());
      if (parsed == null || parsed < 1 || parsed > 28) {
        return LocaleKeys.autoTransactionValidatorDayOfMonthInvalid.tr();
      }
    }
    return null;
  }

  static String? monthOfYear(dynamic value, AutoScheduleFrequency frequency) {
    if (frequency == AutoScheduleFrequency.yearly) {
      if (value == null) {
        return LocaleKeys.autoTransactionValidatorMonthOfYearRequired.tr();
      }
    }
    return null;
  }

  static String? intervalDays(String? value, AutoScheduleFrequency frequency) {
    if (frequency == AutoScheduleFrequency.everyNDays) {
      if (value == null || value.trim().isEmpty) {
        return LocaleKeys.autoTransactionValidatorIntervalDaysRequired.tr();
      }
      final parsed = int.tryParse(value.trim());
      if (parsed == null || parsed < 1) {
        return LocaleKeys.autoTransactionValidatorIntervalDaysInvalid.tr();
      }
    }
    return null;
  }

  static String? startDate(DateTime? value) {
    if (value == null) {
      return LocaleKeys.autoTransactionValidatorStartDateRequired.tr();
    }
    return null;
  }

  static String? endDate(DateTime? value) {
    // * Optional — no validation required
    return null;
  }
}
