import 'package:easy_localization/easy_localization.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';

class CreateBudgetValidator {
  const CreateBudgetValidator._();

  static String? categoryUlid(String? value) {
    if (value == null || value.isEmpty) {
      return LocaleKeys.budgetValidatorCategoryRequired.tr();
    }
    return null;
  }

  static String? amountLimit(String? value) {
    if (value == null || value.isEmpty) {
      return LocaleKeys.budgetValidatorAmountLimitRequired.tr();
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
    if (value == null) {
      return LocaleKeys.budgetValidatorPeriodRequired.tr();
    }
    return null;
  }

  static String? startDate(DateTime? value) {
    // * Optional for non-custom period
    return null;
  }

  static String? endDate(DateTime? value) {
    // * Optional for non-custom period
    return null;
  }
}
