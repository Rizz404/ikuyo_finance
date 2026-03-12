export 'package:ikuyo_finance/core/theme/app_theme.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ikuyo_finance/core/theme/app_colors.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';

/// Extension methods for BuildContext to easily access themes
extension ThemeExtension on BuildContext {
  /// Get the current ThemeData
  ThemeData get theme => Theme.of(this);

  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Get the current CupertinoThemeData
  CupertinoThemeData get cupertinoTheme => CupertinoTheme.of(this);

  /// Check if the current theme is dark mode
  bool get isDarkMode => theme.brightness == Brightness.dark;

  /// Get the appropriate AppTheme based on current brightness
  ThemeData get appTheme =>
      isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme;

  /// Get the appropriate Cupertino AppTheme based on current brightness
  CupertinoThemeData get appCupertinoTheme =>
      isDarkMode ? AppTheme.cupertinoDarkTheme : AppTheme.cupertinoLightTheme;

  /// Get the light theme
  ThemeData get appLightTheme => AppTheme.lightTheme;

  /// Get the dark theme
  ThemeData get appDarkTheme => AppTheme.darkTheme;

  /// Get the light Cupertino theme
  CupertinoThemeData get appCupertinoLightTheme => AppTheme.cupertinoLightTheme;

  /// Get the dark Cupertino theme
  CupertinoThemeData get appCupertinoDarkTheme => AppTheme.cupertinoDarkTheme;

  /// Get semantic colors (same for both themes)
  SemanticColors get semantic => AppColors.semantic;
}

/// Extension for easy access to theme-aware colors
extension ThemeColors on BuildContext {
  AppColorsTheme get colors {
    return Theme.of(this).brightness == Brightness.light
        ? AppColorsTheme.light()
        : AppColorsTheme.dark();
  }
}
