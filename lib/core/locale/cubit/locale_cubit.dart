import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ikuyo_finance/core/storage/storage_keys.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';

part 'locale_state.dart';

class LocaleCubit extends Cubit<LocaleState> {
  final SharedPreferences _prefs;

  LocaleCubit(this._prefs)
    : super(LocaleState(currentLocale: _loadLocale(_prefs))) {
    this.logInfo('LocaleCubit initialized with ${state.currentLocale}');
  }

  static SupportedLocale _loadLocale(SharedPreferences prefs) {
    final localeName = prefs.getString(StorageKeys.locale);
    if (localeName == null) return SupportedLocale.english;

    return SupportedLocale.fromCode(localeName);
  }

  /// Change current locale
  Future<void> setLocale(SupportedLocale locale) async {
    try {
      await _prefs.setString(StorageKeys.locale, locale.name);
      emit(state.copyWith(currentLocale: locale));
      this.logInfo('Locale changed to ${locale.name}');
    } catch (e, s) {
      this.logError('Failed to change locale', e, s);
    }
  }

  /// Get all available locales
  List<SupportedLocale> get availableLocales => SupportedLocale.values.toList();

  /// Get supported Locale list for EasyLocalization
  static List<Locale> get supportedLocales =>
      SupportedLocale.values.map((l) => l.locale).toList();
}
