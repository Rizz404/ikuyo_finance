import 'package:easy_localization/easy_localization.dart';
import 'package:ikuyo_finance/core/currency/models/currency.dart';
import 'package:ikuyo_finance/core/currency/utils/currency_input.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';

class CreateBudgetValidator {
  const CreateBudgetValidator._();

  static String? categoryUlid(String? value) {
    if (value == null || value.isEmpty) {
      return LocaleKeys.budgetValidatorCategoryRequired.tr();
    }
    return null;
  }

  static String? amountLimit(String? value, [Currency? currency]) {
    if (value == null || value.isEmpty) {
      return LocaleKeys.budgetValidatorAmountLimitRequired.tr();
    }
    final parsed = CurrencyInput.parse(
      value,
      currency ?? CurrencyInput.defaultCurrency,
    );
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

  static String? dateRange(
    BudgetPeriod period,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    if (period != BudgetPeriod.custom) return null;
    if (startDate == null || endDate == null) {
      return LocaleKeys.budgetValidatorCustomDatesRequired.tr();
    }
    if (endDate.isBefore(startDate)) {
      return LocaleKeys.budgetValidatorDateRangeInvalid.tr();
    }
    return null;
  }
}
