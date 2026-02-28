import 'package:easy_localization/easy_localization.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';

class UpdateAssetValidator {
  const UpdateAssetValidator._();

  static String? ulid(String? value) {
    if (value == null || value.isEmpty) {
      return LocaleKeys.assetValidatorUlidRequired.tr();
    }
    return null;
  }

  static String? name(String? value) {
    if (value == null || value.isEmpty) {
      return null; // * Optional for update
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
    // * Optional for update
    return null;
  }

  static String? balance(String? value) {
    if (value == null || value.isEmpty) {
      return null; // * Optional for update
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
    // * Optional for update
    return null;
  }
}
