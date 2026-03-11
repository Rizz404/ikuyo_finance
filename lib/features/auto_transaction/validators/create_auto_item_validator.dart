import 'package:easy_localization/easy_localization.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';

class CreateAutoItemValidator {
  const CreateAutoItemValidator._();

  static String? transactionUlid(String? value) {
    if (value == null || value.trim().isEmpty) {
      return LocaleKeys.autoTransactionValidatorTransactionRequired.tr();
    }
    return null;
  }
}
