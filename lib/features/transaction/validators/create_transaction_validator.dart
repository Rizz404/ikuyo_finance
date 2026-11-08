import 'package:easy_localization/easy_localization.dart';
import 'package:ikuyo_finance/core/currency/models/currency.dart';
import 'package:ikuyo_finance/core/currency/utils/currency_input.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';

class CreateTransactionValidator {
  const CreateTransactionValidator._();

  static String? amount(String? value, [Currency? currency]) {
    if (value == null || value.isEmpty) {
      return LocaleKeys.transactionValidatorAmountRequired.tr();
    }
    final amount = CurrencyInput.parse(
      value,
      currency ?? CurrencyInput.defaultCurrency,
    );
    if (amount == null || amount <= 0) {
      return LocaleKeys.transactionValidatorAmountPositive.tr();
    }
    return null;
  }

  static String? assetUlid(String? value) {
    if (value == null || value.isEmpty) {
      return LocaleKeys.transactionValidatorAssetRequired.tr();
    }
    return null;
  }

  static String? categoryUlid(String? value) {
    // * Category is optional for transaction
    return null;
  }

  static String? transactionDate(DateTime? value) {
    // * Transaction date is optional, defaults to now
    return null;
  }

  static String? description(String? value) {
    if (value != null && value.length > 500) {
      return LocaleKeys.transactionValidatorDescriptionMaxLength.tr();
    }
    return null;
  }

  static String? imagePath(String? value) {
    // * Image path is optional
    return null;
  }
}
