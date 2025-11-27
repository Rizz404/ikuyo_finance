import 'package:flutter/material.dart';

/// Modern Color Palette using 60-30-10 Rule
/// 60% - Primary/Background colors
/// 30% - Secondary/Supporting colors
/// 10% - Accent/Action colors
class AppColors {
  // Private constructor to prevent instantiation
  AppColors._();

  // ============================================
  // LIGHT THEME COLORS
  // ============================================

  static const LightColors light = LightColors._();

  // ============================================
  // DARK THEME COLORS
  // ============================================

  static const DarkColors dark = DarkColors._();

  // ============================================
  // SEMANTIC COLORS (Same for both themes)
  // ============================================

  static const SemanticColors semantic = SemanticColors._();
}

/// Light Theme Color Palette
class LightColors {
  const LightColors._();

  // 60% - Primary Colors (Backgrounds & Main surfaces)
  // Modern off-white and light grays
  final Color background = const Color.fromRGBO(
    250,
    251,
    253,
    1,
  ); // Slight blue tint
  final Color surface = const Color.fromRGBO(255, 255, 255, 1);
  final Color surfaceVariant = const Color.fromRGBO(245, 247, 250, 1);

  // 30% - Secondary Colors (Supporting elements)
  // Modern blue-gray palette
  final Color primary = const Color.fromRGBO(37, 99, 235, 1); // Modern blue
  final Color primaryContainer = const Color.fromRGBO(219, 234, 254, 1);
  final Color secondary = const Color.fromRGBO(100, 116, 139, 1); // Slate
  final Color secondaryContainer = const Color.fromRGBO(226, 232, 240, 1);

  // 10% - Accent Colors (CTAs, Important actions)
  // Vibrant modern accent
  final Color accent = const Color.fromRGBO(168, 85, 247, 1); // Purple accent
  final Color accentHover = const Color.fromRGBO(147, 51, 234, 1);
  final Color accentPressed = const Color.fromRGBO(126, 34, 206, 1);

  // Text Colors
  final Color textPrimary = const Color.fromRGBO(15, 23, 42, 1); // Dark slate
  final Color textSecondary = const Color.fromRGBO(71, 85, 105, 1);
  final Color textTertiary = const Color.fromRGBO(148, 163, 184, 1);
  final Color textDisabled = const Color.fromRGBO(203, 213, 225, 1);
  final Color textOnPrimary = const Color.fromRGBO(255, 255, 255, 1);
  final Color textOnAccent = const Color.fromRGBO(255, 255, 255, 1);

  // Border & Divider Colors
  final Color border = const Color.fromRGBO(226, 232, 240, 1);
  final Color borderHover = const Color.fromRGBO(203, 213, 225, 1);
  final Color divider = const Color.fromRGBO(241, 245, 249, 1);

  // Interactive States
  final Color hover = const Color.fromRGBO(248, 250, 252, 1);
  final Color pressed = const Color.fromRGBO(241, 245, 249, 1);
  final Color focus = const Color.fromRGBO(37, 99, 235, 0.12);
  final Color disabled = const Color.fromRGBO(241, 245, 249, 1);

  // Special Surfaces
  final Color card = const Color.fromRGBO(255, 255, 255, 1);
  final Color modal = const Color.fromRGBO(255, 255, 255, 1);
  final Color tooltip = const Color.fromRGBO(30, 41, 59, 1);

  // Navigation
  final Color navBar = const Color.fromRGBO(255, 255, 255, 1);
  final Color navSelected = const Color.fromRGBO(37, 99, 235, 1);
  final Color navUnselected = const Color.fromRGBO(100, 116, 139, 1);

  // Overlay
  final Color overlay = const Color.fromRGBO(0, 0, 0, 0.5);
  final Color scrim = const Color.fromRGBO(0, 0, 0, 0.32);
}

/// Dark Theme Color Palette
class DarkColors {
  const DarkColors._();

  // 60% - Primary Colors (Backgrounds & Main surfaces)
  // Modern dark with slight blue undertone
  final Color background = const Color.fromRGBO(15, 23, 42, 1); // Dark slate
  final Color surface = const Color.fromRGBO(30, 41, 59, 1);
  final Color surfaceVariant = const Color.fromRGBO(51, 65, 85, 1);

  // 30% - Secondary Colors (Supporting elements)
  // Lighter variations for contrast
  final Color primary = const Color.fromRGBO(96, 165, 250, 1); // Light blue
  final Color primaryContainer = const Color.fromRGBO(30, 58, 138, 1);
  final Color secondary = const Color.fromRGBO(148, 163, 184, 1); // Light slate
  final Color secondaryContainer = const Color.fromRGBO(51, 65, 85, 1);

  // 10% - Accent Colors (CTAs, Important actions)
  // Vibrant for dark backgrounds
  final Color accent = const Color.fromRGBO(196, 181, 253, 1); // Light purple
  final Color accentHover = const Color.fromRGBO(221, 214, 254, 1);
  final Color accentPressed = const Color.fromRGBO(167, 139, 250, 1);

  // Text Colors
  final Color textPrimary = const Color.fromRGBO(
    248,
    250,
    252,
    1,
  ); // Light slate
  final Color textSecondary = const Color.fromRGBO(203, 213, 225, 1);
  final Color textTertiary = const Color.fromRGBO(148, 163, 184, 1);
  final Color textDisabled = const Color.fromRGBO(71, 85, 105, 1);
  final Color textOnPrimary = const Color.fromRGBO(15, 23, 42, 1);
  final Color textOnAccent = const Color.fromRGBO(15, 23, 42, 1);

  // Border & Divider Colors
  final Color border = const Color.fromRGBO(51, 65, 85, 1);
  final Color borderHover = const Color.fromRGBO(71, 85, 105, 1);
  final Color divider = const Color.fromRGBO(30, 41, 59, 1);

  // Interactive States
  final Color hover = const Color.fromRGBO(51, 65, 85, 0.5);
  final Color pressed = const Color.fromRGBO(71, 85, 105, 0.5);
  final Color focus = const Color.fromRGBO(96, 165, 250, 0.12);
  final Color disabled = const Color.fromRGBO(30, 41, 59, 1);

  // Special Surfaces
  final Color card = const Color.fromRGBO(30, 41, 59, 1);
  final Color modal = const Color.fromRGBO(30, 41, 59, 1);
  final Color tooltip = const Color.fromRGBO(241, 245, 249, 1);

  // Navigation
  final Color navBar = const Color.fromRGBO(30, 41, 59, 1);
  final Color navSelected = const Color.fromRGBO(96, 165, 250, 1);
  final Color navUnselected = const Color.fromRGBO(148, 163, 184, 1);

  // Overlay
  final Color overlay = const Color.fromRGBO(0, 0, 0, 0.7);
  final Color scrim = const Color.fromRGBO(0, 0, 0, 0.5);
}

/// Semantic Colors for Status & Feedback
class SemanticColors {
  const SemanticColors._();

  // Success
  final Color success = const Color.fromRGBO(34, 197, 94, 1); // Green
  final Color successLight = const Color.fromRGBO(220, 252, 231, 1);
  final Color successDark = const Color.fromRGBO(22, 163, 74, 1);

  // Warning
  final Color warning = const Color.fromRGBO(251, 191, 36, 1); // Amber
  final Color warningLight = const Color.fromRGBO(254, 249, 195, 1);
  final Color warningDark = const Color.fromRGBO(245, 158, 11, 1);

  // Error
  final Color error = const Color.fromRGBO(239, 68, 68, 1); // Red
  final Color errorLight = const Color.fromRGBO(254, 226, 226, 1);
  final Color errorDark = const Color.fromRGBO(220, 38, 38, 1);

  // Info
  final Color info = const Color.fromRGBO(59, 130, 246, 1); // Blue
  final Color infoLight = const Color.fromRGBO(219, 234, 254, 1);
  final Color infoDark = const Color.fromRGBO(37, 99, 235, 1);
}

/// Theme-aware color wrapper
class AppColorsTheme {
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color primary;
  final Color primaryContainer;
  final Color secondary;
  final Color secondaryContainer;
  final Color accent;
  final Color accentHover;
  final Color accentPressed;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;
  final Color textOnPrimary;
  final Color textOnAccent;
  final Color border;
  final Color borderHover;
  final Color divider;
  final Color hover;
  final Color pressed;
  final Color focus;
  final Color disabled;
  final Color card;
  final Color modal;
  final Color tooltip;
  final Color navBar;
  final Color navSelected;
  final Color navUnselected;
  final Color overlay;
  final Color scrim;

  const AppColorsTheme._({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.primary,
    required this.primaryContainer,
    required this.secondary,
    required this.secondaryContainer,
    required this.accent,
    required this.accentHover,
    required this.accentPressed,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.textOnPrimary,
    required this.textOnAccent,
    required this.border,
    required this.borderHover,
    required this.divider,
    required this.hover,
    required this.pressed,
    required this.focus,
    required this.disabled,
    required this.card,
    required this.modal,
    required this.tooltip,
    required this.navBar,
    required this.navSelected,
    required this.navUnselected,
    required this.overlay,
    required this.scrim,
  });

  factory AppColorsTheme.light() {
    const colors = AppColors.light;
    return AppColorsTheme._(
      background: colors.background,
      surface: colors.surface,
      surfaceVariant: colors.surfaceVariant,
      primary: colors.primary,
      primaryContainer: colors.primaryContainer,
      secondary: colors.secondary,
      secondaryContainer: colors.secondaryContainer,
      accent: colors.accent,
      accentHover: colors.accentHover,
      accentPressed: colors.accentPressed,
      textPrimary: colors.textPrimary,
      textSecondary: colors.textSecondary,
      textTertiary: colors.textTertiary,
      textDisabled: colors.textDisabled,
      textOnPrimary: colors.textOnPrimary,
      textOnAccent: colors.textOnAccent,
      border: colors.border,
      borderHover: colors.borderHover,
      divider: colors.divider,
      hover: colors.hover,
      pressed: colors.pressed,
      focus: colors.focus,
      disabled: colors.disabled,
      card: colors.card,
      modal: colors.modal,
      tooltip: colors.tooltip,
      navBar: colors.navBar,
      navSelected: colors.navSelected,
      navUnselected: colors.navUnselected,
      overlay: colors.overlay,
      scrim: colors.scrim,
    );
  }

  factory AppColorsTheme.dark() {
    const colors = AppColors.dark;
    return AppColorsTheme._(
      background: colors.background,
      surface: colors.surface,
      surfaceVariant: colors.surfaceVariant,
      primary: colors.primary,
      primaryContainer: colors.primaryContainer,
      secondary: colors.secondary,
      secondaryContainer: colors.secondaryContainer,
      accent: colors.accent,
      accentHover: colors.accentHover,
      accentPressed: colors.accentPressed,
      textPrimary: colors.textPrimary,
      textSecondary: colors.textSecondary,
      textTertiary: colors.textTertiary,
      textDisabled: colors.textDisabled,
      textOnPrimary: colors.textOnPrimary,
      textOnAccent: colors.textOnAccent,
      border: colors.border,
      borderHover: colors.borderHover,
      divider: colors.divider,
      hover: colors.hover,
      pressed: colors.pressed,
      focus: colors.focus,
      disabled: colors.disabled,
      card: colors.card,
      modal: colors.modal,
      tooltip: colors.tooltip,
      navBar: colors.navBar,
      navSelected: colors.navSelected,
      navUnselected: colors.navUnselected,
      overlay: colors.overlay,
      scrim: colors.scrim,
    );
  }
}
