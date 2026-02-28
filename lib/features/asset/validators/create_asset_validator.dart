import 'package:easy_localization/easy_localization.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';

class CreateAssetValidator {
  const CreateAssetValidator._();

  static String? name(String? value) {
    if (value == null || value.isEmpty) {
      return LocaleKeys.assetValidatorNameRequired.tr();
    }
    if (value.length < 2) {
      return LocaleKeys.assetValidatorNameMinLength.tr();
    }
    if (value.length > 50) {
      return LocaleKeys.assetValidatorNameMaxLength.tr();
    }
    return null;
  }

  static String? type(dynamic value) {
    if (value == null) {
      return LocaleKeys.assetValidatorTypeRequired.tr();
    }
    return null;
  }

  static String? balance(String? value) {
    if (value == null || value.isEmpty) {
      return null; // * Balance is optional, defaults to 0
    }
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null) {
      return LocaleKeys.assetValidatorBalanceInvalid.tr();
    }
    if (parsed < 0) {
      return LocaleKeys.assetValidatorBalanceNegative.tr();
    }
    return null;
  }

  static String? icon(String? value) {
    // * Icon is optional
    return null;
  }
}
