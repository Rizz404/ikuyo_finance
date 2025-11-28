import 'package:flutter/material.dart';

/// Kita Ikuyo Inspired Color Palette using 60-30-10 Rule
/// 60% - Primary/Background colors (Warm pinkish neutrals)
/// 30% - Secondary/Supporting colors (Red-ish tones)
/// 10% - Accent/Action colors (Yellow pops)
class AppColors {
  // Private constructor to prevent instantiation
  AppColors._();

  // ============================================
  // LIGHT THEME COLORS (Kita's Daytime Energy)
  // ============================================

  static const LightColors light = LightColors._();

  // ============================================
  // DARK THEME COLORS (Kita's Night Stage Vibes)
  // ============================================

  static const DarkColors dark = DarkColors._();

  // ============================================
  // SEMANTIC COLORS (Same for both themes, with a fun twist if needed)
  // ============================================

  static const SemanticColors semantic = SemanticColors._();
}

/// Light Theme Color Palette - Inspired by Kita's bright personality
class LightColors {
  const LightColors._();

  // 60% - Primary Colors (Backgrounds & Main surfaces)
  // Soft pinkish with warm tints
  final Color background = const Color(0xFFFFE4E1); // Misty rose with pink tint
  final Color surface = const Color(0xFFFFFFFF); // Pure white
  final Color surfaceVariant = const Color(0xFFFFF0F0); // Very light pink

  // 30% - Secondary Colors (Supporting elements)
  // Red-inspired palette
  final Color primary = const Color(0xFFFF3232); // Bright red like her hair
  final Color primaryContainer = const Color(0xFFFFDADA); // Light red-pink
  final Color secondary = const Color(0xFFE8A7A1); // Soft pinkish
  final Color secondaryContainer = const Color(0xFFFFF5F5); // Pale pink

  // 10% - Accent Colors (CTAs, Important actions)
  // Vibrant yellow accent
  final Color accent = const Color(0xFFFFFF3D); // Bright yellow like her eyes
  final Color accentHover = const Color(0xFFFFEA00); // Lighter yellow hover
  final Color accentPressed = const Color(0xFFFFD700); // Goldish pressed

  // Text Colors
  final Color textPrimary = const Color(0xFF2F0000); // Dark red-brown
  final Color textSecondary = const Color(0xFF5C2A2A); // Muted red
  final Color textTertiary = const Color(0xFFA05252); // Light red
  final Color textDisabled = const Color(0xFFD9B3B3); // Pale pink disabled
  final Color textOnPrimary = const Color(0xFFFFFFFF); // White on primary
  final Color textOnAccent = const Color(0xFF000000); // Black on yellow accent

  // Border & Divider Colors
  final Color border = const Color(0xFFFFDADA); // Light red border
  final Color borderHover = const Color(0xFFFFB3B3); // Hover pink
  final Color divider = const Color(0xFFFFF0F0); // Pale divider

  // Interactive States
  final Color hover = const Color(0xFFFFFAFA); // Near white hover
  final Color pressed = const Color(0xFFFFF0F0); // Pressed pink
  final Color focus = const Color(0xffff323230); // Red with opacity 0.12
  final Color disabled = const Color(0xFFFFF5F5); // Disabled pale

  // Special Surfaces
  final Color card = const Color(0xFFFFFFFF); // White card
  final Color modal = const Color(0xFFFFFFFF); // White modal
  final Color tooltip = const Color(0xFF2F0000); // Dark tooltip

  // Navigation
  final Color navBar = const Color(0xFFFFFFFF); // White nav
  final Color navSelected = const Color(0xFFFF3232); // Red selected
  final Color navUnselected = const Color(0xFFE8A7A1); // Pink unselected

  // Overlay
  final Color overlay = const Color(0x80000000); // Black 0.5
  final Color scrim = const Color(0x52000000); // Black 0.32
}

/// Dark Theme Color Palette - Kita's mysterious yet energetic side
class DarkColors {
  const DarkColors._();

  // 60% - Primary Colors (Backgrounds & Main surfaces)
  // Dark with red undertones
  final Color background = const Color(0xFF2F0000); // Dark red-brown
  final Color surface = const Color(0xFF5C2A2A); // Muted dark red
  final Color surfaceVariant = const Color(0xFF8B0000); // Darker red

  // 30% - Secondary Colors (Supporting elements)
  // Lighter red variations
  final Color primary = const Color(0xFFFF6961); // Light red
  final Color primaryContainer = const Color(0xFF8B0000); // Dark red container
  final Color secondary = const Color(0xFFA05252); // Medium pink-red
  final Color secondaryContainer = const Color(0xFF5C2A2A); // Dark secondary

  // 10% - Accent Colors (CTAs, Important actions)
  // Bright yellow for contrast
  final Color accent = const Color(0xFFFFFF3D); // Bright yellow
  final Color accentHover = const Color(0xFFFFEA00); // Hover yellow
  final Color accentPressed = const Color(0xFFFFD700); // Pressed gold

  // Text Colors
  final Color textPrimary = const Color(0xFFFFFAFA); // Light pinkish white
  final Color textSecondary = const Color(0xFFFFDADA); // Light red
  final Color textTertiary = const Color(0xFFA05252); // Medium red
  final Color textDisabled = const Color(0xFF5C2A2A); // Dark disabled
  final Color textOnPrimary = const Color(0xFF2F0000); // Dark on primary
  final Color textOnAccent = const Color(0xFF000000); // Black on accent

  // Border & Divider Colors
  final Color border = const Color(0xFF8B0000); // Dark red border
  final Color borderHover = const Color(0xFFA05252); // Hover red
  final Color divider = const Color(0xFF5C2A2A); // Dark divider

  // Interactive States
  final Color hover = const Color(0x808B0000); // Red hover 0.5
  final Color pressed = const Color(0x80A05252); // Pressed 0.5
  final Color focus = const Color(0x1ffff6961); // Light red focus 0.12
  final Color disabled = const Color(0xFF5C2A2A); // Disabled dark

  // Special Surfaces
  final Color card = const Color(0xFF5C2A2A); // Dark card
  final Color modal = const Color(0xFF5C2A2A); // Dark modal
  final Color tooltip = const Color(0xFFFFFAFA); // Light tooltip

  // Navigation
  final Color navBar = const Color(0xFF5C2A2A); // Dark nav
  final Color navSelected = const Color(0xFFFF6961); // Light red selected
  final Color navUnselected = const Color(0xFFA05252); // Medium unselected

  // Overlay
  final Color overlay = const Color(0xB3000000); // Black 0.7
  final Color scrim = const Color(0x80000000); // Black 0.5
}

/// Semantic Colors for Status & Feedback (Kept similar but can be tweaked)
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
  final Color error = const Color.fromRGBO(
    239,
    68,
    68,
    1,
  ); // Red (matches Kita's hair vibe!)
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
