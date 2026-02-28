import 'package:easy_localization/easy_localization.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';

class UpdateBudgetValidator {
  const UpdateBudgetValidator._();

  static String? ulid(String? value) {
    if (value == null || value.isEmpty) {
      return LocaleKeys.budgetValidatorUlidRequired.tr();
    }
    return null;
  }

  static String? categoryUlid(String? value) {
    // * Optional for update
    return null;
  }

  static String? amountLimit(String? value) {
    if (value == null || value.isEmpty) {
      return null; // * Optional for update
    }
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null) {
      return LocaleKeys.budgetValidatorAmountLimitInvalid.tr();
    }
    if (parsed <= 0) {
      return LocaleKeys.budgetValidatorAmountLimitPositive.tr();
    }
    return null;
  }

  static String? period(dynamic value) {
    // * Optional for update
    return null;
  }

  static String? startDate(DateTime? value) {
    // * Optional for update
    return null;
  }

  static String? endDate(DateTime? value) {
    // * Optional for update
    return null;
  }
}
