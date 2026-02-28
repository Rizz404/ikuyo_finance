import 'package:easy_localization/easy_localization.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';

class CreateCategoryValidator {
  const CreateCategoryValidator._();

  static String? name(String? value) {
    if (value == null || value.isEmpty) {
      return LocaleKeys.categoryValidatorNameRequired.tr();
    }
    if (value.length < 2) {
      return LocaleKeys.categoryValidatorNameMinLength.tr();
    }
    if (value.length > 50) {
      return LocaleKeys.categoryValidatorNameMaxLength.tr();
    }
    return null;
  }

  static String? type(dynamic value) {
    if (value == null) {
      return LocaleKeys.categoryValidatorTypeRequired.tr();
    }
    return null;
  }

  static String? icon(String? value) {
    // * Icon is optional
    return null;
  }

  static String? color(String? value) {
    // * Color is optional
    return null;
  }

  static String? parentUlid(String? value) {
    // * Parent is optional
    return null;
  }
}
