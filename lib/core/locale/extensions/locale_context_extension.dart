import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:ikuyo_finance/core/locale/cubit/locale_cubit.dart';

/// Extension for easy locale access from BuildContext
extension LocaleContextExtension on BuildContext {
  /// Get LocaleCubit instance
  LocaleCubit get localeCubit => read<LocaleCubit>();

  /// Watch LocaleState for reactive updates
  LocaleState get localeState => watch<LocaleCubit>().state;

  /// Get current supported locale
  SupportedLocale get currentSupportedLocale => localeState.currentLocale;

  /// Change locale via cubit and EasyLocalization
  Future<void> changeLocale(SupportedLocale locale) async {
    await localeCubit.setLocale(locale);
    if (mounted) {
      await setLocale(locale.locale);
    }
  }
}
