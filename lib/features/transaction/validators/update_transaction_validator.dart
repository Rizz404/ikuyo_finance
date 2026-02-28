import 'package:easy_localization/easy_localization.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';

class UpdateTransactionValidator {
  const UpdateTransactionValidator._();

  static String? ulid(String? value) {
    if (value == null || value.isEmpty) {
      return LocaleKeys.transactionValidatorUlidRequired.tr();
    }
    return null;
  }

  static String? amount(String? value) {
    if (value == null || value.isEmpty) {
      return null; // * Optional for update
    }
    final amount = double.tryParse(value.replaceAll('.', ''));
    if (amount == null || amount <= 0) {
      return LocaleKeys.transactionValidatorAmountPositive.tr();
    }
    return null;
  }

  static String? assetUlid(String? value) {
    // * Optional for update
    return null;
  }

  static String? categoryUlid(String? value) {
    // * Optional for update
    return null;
  }

  static String? transactionDate(DateTime? value) {
    // * Optional for update
    return null;
  }

  static String? description(String? value) {
    if (value != null && value.length > 500) {
      return LocaleKeys.transactionValidatorDescriptionMaxLength.tr();
    }
    return null;
  }

  static String? imagePath(String? value) {
    // * Optional for update
    return null;
  }
}
