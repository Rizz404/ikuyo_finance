import 'package:easy_localization/easy_localization.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';

class UpdateCategoryValidator {
  const UpdateCategoryValidator._();

  static String? ulid(String? value) {
    if (value == null || value.isEmpty) {
      return LocaleKeys.categoryValidatorUlidRequired.tr();
    }
    return null;
  }

  static String? name(String? value) {
    if (value == null || value.isEmpty) {
      return null; // * Optional for update
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
    // * Optional for update
    return null;
  }

  static String? icon(String? value) {
    // * Optional for update
    return null;
  }

  static String? color(String? value) {
    // * Optional for update
    return null;
  }

  static String? parentUlid(String? value) {
    // * Optional for update
    return null;
  }
}
