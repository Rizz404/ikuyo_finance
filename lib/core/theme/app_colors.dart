import 'package:flutter/material.dart';

/// Kita Ikuyo Inspired Color Palette - Refined & Balanced Version
/// Structure preserved, colors optimized for UI/UX readability.
class AppColors {
  // Private constructor to prevent instantiation
  AppColors._();

  // ============================================
  // LIGHT THEME COLORS (Energetic but Clean)
  // ============================================

  static const LightColors light = LightColors._();

  // ============================================
  // DARK THEME COLORS (Cool, Stage-Ready, Contrast Optimized)
  // ============================================

  static const DarkColors dark = DarkColors._();

  // ============================================
  // SEMANTIC COLORS
  // ============================================

  static const SemanticColors semantic = SemanticColors._();
}

/// Light Theme - Balanced with Warm Neutrals & Kita's Red
class LightColors {
  const LightColors._();

  // 60% - Primary Colors (Backgrounds & Main surfaces)
  // Warm White base - clean but welcoming
  final Color background = const Color(0xFFFFFBFA); // Very light warm white
  final Color surface = const Color(0xFFFFFFFF); // Pure white
  final Color surfaceVariant = const Color(0xFFF5F5F5); // Light greyish

  // 30% - Secondary Colors (Brand Identity)
  // Kita's Signature Red
  final Color primary = const Color(0xFFE53935); // Vibrant Kita Red
  final Color primaryContainer = const Color(0xFFFFEBEE); // Soft red container
  final Color secondary = const Color(0xFFEF5350); // Softer red
  final Color secondaryContainer = const Color(0xFFFFCDD2); // Pale red

  // 10% - Accent Colors (Action pops)
  // Electric Yellow
  final Color accent = const Color(0xFFFFD600); // Energetic Yellow
  final Color accentHover = const Color(0xFFFFEA00); // Lighter yellow
  final Color accentPressed = const Color(0xFFFFC400); // Deep yellow

  // Text Colors
  final Color textPrimary = const Color(0xFF212121); // High emphasis black
  final Color textSecondary = const Color(0xFF757575); // Medium emphasis grey
  final Color textTertiary = const Color(0xFFBDBDBD); // Low emphasis
  final Color textDisabled = const Color(0xFFE0E0E0); // Disabled grey
  final Color textOnPrimary = const Color(0xFFFFFFFF); // White on Red
  final Color textOnAccent = const Color(0xFF000000); // Black on Yellow

  // Border & Divider Colors
  final Color border = const Color(0xFFE0E0E0); // Subtle grey border
  final Color borderHover = const Color(0xFFE53935); // Red when active/hover
  final Color divider = const Color(0xFFEEEEEE); // Very light divider

  // Interactive States
  final Color hover = const Color(0x0DE53935); // Red tint 5%
  final Color pressed = const Color(0x1AE53935); // Red tint 10%
  final Color focus = const Color(0x1FE53935); // Red tint 12%
  final Color disabled = const Color(0xFFF5F5F5); // Grey disabled bg

  // Special Surfaces
  final Color card = const Color(0xFFFFFFFF); // White card
  final Color modal = const Color(0xFFFFFFFF); // White modal
  final Color tooltip = const Color(0xFF323232); // Dark grey tooltip

  // Navigation
  final Color navBar = const Color(0xFFFFFFFF); // White nav
  final Color navSelected = const Color(0xFFE53935); // Kita Red selected
  final Color navUnselected = const Color(0xFF9E9E9E); // Grey unselected

  // Overlay
  final Color overlay = const Color(0x80000000); // Black 50%
  final Color scrim = const Color(0x52000000); // Black 32%
}

/// Dark Theme - Sleek Dark Grey with Kita's Red Glow
class DarkColors {
  const DarkColors._();

  // 60% - Primary Colors (Backgrounds & Main surfaces)
  // Dark Grey (Not Black, Not Red) for eye comfort
  final Color background = const Color(0xFF121212); // Standard Dark UI base
  final Color surface = const Color(0xFF1E1E1E); // Slightly lighter grey
  final Color surfaceVariant = const Color(0xFF2C2C2C); // Elevation level

  // 30% - Secondary Colors (Brand Identity)
  // Desaturated Red for Dark Mode
  final Color primary = const Color(0xFFEF5350); // Soft Red
  final Color primaryContainer = const Color(0xFF3E1515); // Muted red container
  final Color secondary = const Color(0xFFE57373); // Muted secondary red
  final Color secondaryContainer = const Color(0xFF2C2C2C); // Dark container

  // 10% - Accent Colors
  // Bright Yellow maintains contrast
  final Color accent = const Color(0xFFFFD600); // Yellow
  final Color accentHover = const Color(0xFFFFEA00); // Lighter yellow
  final Color accentPressed = const Color(0xFFFFC400); // Deep yellow

  // Text Colors
  final Color textPrimary = const Color(0xFFEEEEEE); // Off-white
  final Color textSecondary = const Color(0xFFB0B0B0); // Light grey
  final Color textTertiary = const Color(0xFF616161); // Darker grey
  final Color textDisabled = const Color(0xFF424242); // Very dark grey
  final Color textOnPrimary = const Color(
    0xFF000000,
  ); // Black on Red (High contrast)
  final Color textOnAccent = const Color(0xFF000000); // Black on Yellow

  // Border & Divider Colors
  final Color border = const Color(0xFF424242); // Dark grey border
  final Color borderHover = const Color(0xFFEF5350); // Red hover
  final Color divider = const Color(0xFF2C2C2C); // Divider

  // Interactive States
  final Color hover = const Color(0x14FFFFFF); // White tint hover
  final Color pressed = const Color(0x1FFFFFFF); // White tint pressed
  final Color focus = const Color(0x1FEF5350); // Red focus
  final Color disabled = const Color(0xFF2C2C2C); // Disabled bg

  // Special Surfaces
  final Color card = const Color(0xFF1E1E1E); // Dark card
  final Color modal = const Color(0xFF2C2C2C); // Modal surface
  final Color tooltip = const Color(0xFFE0E0E0); // Light tooltip

  // Navigation
  final Color navBar = const Color(0xFF1E1E1E); // Dark nav
  final Color navSelected = const Color(0xFFEF5350); // Soft Red selected
  final Color navUnselected = const Color(0xFF757575); // Grey unselected

  // Overlay
  final Color overlay = const Color(0xB3000000); // Black 70%
  final Color scrim = const Color(0x80000000); // Black 50%
}

/// Semantic Colors (Matches Kita's Vibe + Standard UI Safety)
class SemanticColors {
  const SemanticColors._();

  // Success
  final Color success = const Color(0xFF43A047); // Green
  final Color successLight = const Color(0xFFE8F5E9);
  final Color successDark = const Color(0xFF1B5E20);

  // Warning
  final Color warning = const Color(0xFFFFA000); // Amber
  final Color warningLight = const Color(0xFFFFF8E1);
  final Color warningDark = const Color(0xFFFF6F00);

  // Error - Using a distinct red, slightly different from Brand Primary to avoid confusion
  final Color error = const Color(0xFFD32F2F); // Standard UI Error Red
  final Color errorLight = const Color(0xFFFFEBEE);
  final Color errorDark = const Color(0xFFB71C1C);

  // Info
  final Color info = const Color(0xFF1976D2); // Blue
  final Color infoLight = const Color(0xFFE3F2FD);
  final Color infoDark = const Color(0xFF0D47A1);
}

/// Theme-aware color wrapper (Struktur Tetap Sama)
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
