import 'package:easy_localization/easy_localization.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';

class BulkCopyTransactionValidator {
  const BulkCopyTransactionValidator._();

  static String? amount(String? value) {
    if (value == null || value.isEmpty) {
      return LocaleKeys.transactionBulkCopyAmountRequired.tr();
    }
    final amount = double.tryParse(value.replaceAll('.', ''));
    if (amount == null || amount <= 0) {
      return LocaleKeys.transactionBulkCopyAmountMustBePositive.tr();
    }
    return null;
  }

  static String? assetUlid(String? value) {
    if (value == null || value.isEmpty) {
      return LocaleKeys.transactionBulkCopyAssetRequired.tr();
    }
    return null;
  }

  static String? categoryUlid(String? value) {
    // * Category is optional
    return null;
  }

  static String? transactionDate(DateTime? value) {
    // * Date is optional
    return null;
  }

  static String? description(String? value) {
    if (value != null && value.length > 500) {
      return LocaleKeys.transactionValidatorDescriptionMaxLength.tr();
    }
    return null;
  }
}
