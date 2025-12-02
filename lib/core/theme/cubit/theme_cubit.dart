import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ikuyo_finance/core/storage/storage_keys.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';

part 'theme_state.dart';

class ThemeCubit extends Cubit<ThemeState> {
  final SharedPreferences _prefs;

  ThemeCubit(this._prefs)
    : super(
        ThemeState(
          themeMode: _loadThemeMode(_prefs),
          lightTheme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
        ),
      ) {
    this.logInfo('ThemeCubit initialized with ${state.themeMode}');
  }

  static ThemeMode _loadThemeMode(SharedPreferences prefs) {
    final themeName = prefs.getString(StorageKeys.themeMode);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == themeName,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    try {
      await _prefs.setString(StorageKeys.themeMode, mode.name);
      emit(state.copyWith(themeMode: mode));
      this.logInfo('Theme changed to ${mode.name}');
    } catch (e, s) {
      this.logError('Failed to change theme', e, s);
    }
  }

  Future<void> toggleTheme() async {
    final newMode = state.themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    await setThemeMode(newMode);
  }

  bool get isDarkMode => state.themeMode == ThemeMode.dark;
  bool get isLightMode => state.themeMode == ThemeMode.light;
  bool get isSystemMode => state.themeMode == ThemeMode.system;
}
