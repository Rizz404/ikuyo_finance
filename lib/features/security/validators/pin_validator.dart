import 'package:easy_localization/easy_localization.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';

class PinValidator {
  const PinValidator._();

  static String? pin(String? value, int expectedLength) {
    if (value == null || value.length != expectedLength) {
      return LocaleKeys.securityPinTooShort.tr();
    }
    return null;
  }

  static String? confirmPin(String? pin, String? confirm) {
    if (pin != confirm) {
      return LocaleKeys.securityPinMismatch.tr();
    }
    return null;
  }
}
