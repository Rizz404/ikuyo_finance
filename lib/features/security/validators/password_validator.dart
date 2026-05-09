import 'package:easy_localization/easy_localization.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';

class PasswordValidator {
  const PasswordValidator._();

  static String? password(String? value) {
    if (value == null || value.isEmpty || value.length < 6) {
      return LocaleKeys.securityPasswordTooShort.tr();
    }
    return null;
  }

  static String? confirmPassword(String? password, String? confirm) {
    if (password != confirm) {
      return LocaleKeys.securityPasswordMismatch.tr();
    }
    return null;
  }
}
