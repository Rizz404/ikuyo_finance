import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ikuyo_finance/core/theme/app_colors.dart';

// * Font family constants - Kita Ikuyo inspired! ⭐🎸
// Quicksand: Rounded, playful, energetic - like Kita's personality!
// Nunito: Friendly, readable, soft - perfect for body text
const String kFontHeading = 'Quicksand';
const String kFontBody = 'Nunito';

class AppTheme {
  AppTheme._();

  // * ThemeData Getter for Material Design (Light)
  static ThemeData get lightTheme {
    const colors = AppColors.light;
    const semantic = AppColors.semantic;
    final baseTheme = ThemeData.light(useMaterial3: true);

    return baseTheme.copyWith(
      brightness: Brightness.light,
      primaryColor: colors.primary,
      scaffoldBackgroundColor: colors.background,

      // * Color Scheme
      colorScheme: ColorScheme.light(
        primary: colors.primary,
        primaryContainer: colors.primaryContainer,
        secondary: colors.secondary,
        secondaryContainer: colors.secondaryContainer,
        tertiary: colors.accent,
        tertiaryContainer: colors.primaryContainer,
        surface: colors.surface,
        surfaceContainerHighest: colors.surfaceVariant,
        error: semantic.error,
        errorContainer: semantic.errorLight,
        onPrimary: colors.textOnPrimary,
        onPrimaryContainer: colors.textPrimary,
        onSecondary: colors.textOnPrimary,
        onSecondaryContainer: colors.textPrimary,
        onTertiary: colors.textOnAccent,
        onTertiaryContainer: colors.textPrimary,
        onSurface: colors.textPrimary,
        onSurfaceVariant: colors.textSecondary,
        onError: Colors.white,
        onErrorContainer: semantic.errorDark,
        outline: colors.border,
        outlineVariant: colors.divider,
        scrim: colors.scrim,
      ),

      // * Text Theme
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontFamily: kFontHeading,
          fontSize: 57,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.25,
          color: colors.textPrimary,
        ),
        displayMedium: TextStyle(
          fontFamily: kFontHeading,
          fontSize: 45,
          fontWeight: FontWeight.w400,
          color: colors.textPrimary,
        ),
        displaySmall: TextStyle(
          fontFamily: kFontHeading,
          fontSize: 36,
          fontWeight: FontWeight.w400,
          color: colors.textPrimary,
        ),
        headlineLarge: TextStyle(
          fontFamily: kFontHeading,
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
        headlineMedium: TextStyle(
          fontFamily: kFontHeading,
          fontSize: 28,
          fontWeight: FontWeight.w500,
          color: colors.textPrimary,
        ),
        headlineSmall: TextStyle(
          fontFamily: kFontHeading,
          fontSize: 24,
          fontWeight: FontWeight.w500,
          color: colors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontFamily: kFontHeading,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
          color: colors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontFamily: kFontHeading,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15,
          color: colors.textPrimary,
        ),
        titleSmall: TextStyle(
          fontFamily: kFontHeading,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          color: colors.textSecondary,
        ),
        bodyLarge: TextStyle(
          fontFamily: kFontBody,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.5,
          color: colors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontFamily: kFontBody,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.25,
          color: colors.textPrimary,
        ),
        bodySmall: TextStyle(
          fontFamily: kFontBody,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.4,
          color: colors.textSecondary,
        ),
        labelLarge: TextStyle(
          fontFamily: kFontBody,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          color: colors.textPrimary,
        ),
        labelMedium: TextStyle(
          fontFamily: kFontBody,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          color: colors.textSecondary,
        ),
        labelSmall: TextStyle(
          fontFamily: kFontBody,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          color: colors.textTertiary,
        ),
      ),

      // * App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: colors.divider,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: kFontHeading,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
        actionsIconTheme: IconThemeData(color: colors.textSecondary),
      ),

      // * Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.navBar,
        selectedItemColor: colors.navSelected,
        unselectedItemColor: colors.navUnselected,
        selectedLabelStyle: const TextStyle(
          fontFamily: kFontBody,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: kFontBody,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // * Navigation Bar Theme (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.navBar,
        indicatorColor: colors.primaryContainer,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.navSelected,
            );
          }
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colors.navUnselected,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colors.navSelected);
          }
          return IconThemeData(color: colors.navUnselected);
        }),
        elevation: 0,
        height: 80,
      ),

      // * Drawer Theme
      drawerTheme: DrawerThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),

      // * List Tile Theme
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        textColor: colors.textPrimary,
        iconColor: colors.textSecondary,
        selectedColor: colors.primary,
        selectedTileColor: colors.primaryContainer.withValues(alpha: 0.12),
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: colors.textPrimary,
        ),
        subtitleTextStyle: TextStyle(fontSize: 14, color: colors.textSecondary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // * Card Theme
      cardTheme: CardThemeData(
        color: colors.card,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.border, width: 1),
        ),
        margin: const EdgeInsets.all(8),
      ),

      // * Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style:
            ElevatedButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: colors.textOnAccent,
              disabledBackgroundColor: colors.disabled,
              disabledForegroundColor: colors.textDisabled,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              elevation: 0,
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              minimumSize: const Size(64, 40),
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered)) {
                  return colors.textOnAccent.withValues(alpha: 0.08);
                }
                if (states.contains(WidgetState.pressed)) {
                  return colors.textOnAccent.withValues(alpha: 0.12);
                }
                return null;
              }),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return colors.disabled;
                }
                if (states.contains(WidgetState.hovered)) {
                  return colors.accentHover;
                }
                if (states.contains(WidgetState.pressed)) {
                  return colors.accentPressed;
                }
                return colors.accent;
              }),
            ),
      ),

      // * Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              foregroundColor: colors.primary,
              disabledForegroundColor: colors.textDisabled,
              side: BorderSide(color: colors.border, width: 1),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              minimumSize: const Size(64, 40),
            ).copyWith(
              side: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return BorderSide(color: colors.disabled, width: 1);
                }
                if (states.contains(WidgetState.hovered)) {
                  return BorderSide(color: colors.borderHover, width: 1);
                }
                if (states.contains(WidgetState.pressed)) {
                  return BorderSide(color: colors.primary, width: 1);
                }
                return BorderSide(color: colors.border, width: 1);
              }),
            ),
      ),

      // * Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          disabledForegroundColor: colors.textDisabled,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),

      // * Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.accent,
        foregroundColor: colors.textOnAccent,
        elevation: 4,
        focusElevation: 6,
        hoverElevation: 6,
        highlightElevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // * Icon Button Theme
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colors.textSecondary,
          disabledForegroundColor: colors.textDisabled,
          highlightColor: colors.hover,
          padding: const EdgeInsets.all(8),
        ),
      ),

      // * Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: semantic.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: semantic.error, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.disabled, width: 1),
        ),
        hintStyle: TextStyle(color: colors.textTertiary),
        labelStyle: TextStyle(color: colors.textSecondary),
        errorStyle: TextStyle(color: semantic.error, fontSize: 12),
      ),

      // * Checkbox Theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(colors.textOnPrimary),
        side: BorderSide(color: colors.border, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // * Radio Theme
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primary;
          }
          return colors.textTertiary;
        }),
      ),

      // * Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.textOnPrimary;
          }
          return colors.textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primary;
          }
          return colors.border;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // * Slider Theme
      sliderTheme: SliderThemeData(
        activeTrackColor: colors.primary,
        inactiveTrackColor: colors.border,
        thumbColor: colors.primary,
        overlayColor: colors.primary.withValues(alpha: 0.12),
        valueIndicatorColor: colors.primary,
        valueIndicatorTextStyle: TextStyle(color: colors.textOnPrimary),
      ),

      // * Progress Indicator Theme
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.border,
        circularTrackColor: colors.border,
      ),

      // * Tab Bar Theme
      tabBarTheme: TabBarThemeData(
        labelColor: colors.primary,
        unselectedLabelColor: colors.textTertiary,
        indicatorColor: colors.primary,
        dividerColor: colors.divider,
        overlayColor: WidgetStateProperty.all(colors.hover),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
      ),

      // * Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceVariant,
        disabledColor: colors.disabled,
        selectedColor: colors.primaryContainer,
        secondarySelectedColor: colors.secondaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        labelStyle: TextStyle(fontSize: 14, color: colors.textPrimary),
        secondaryLabelStyle: TextStyle(fontSize: 14, color: colors.textPrimary),
        brightness: Brightness.light,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colors.border, width: 1),
        ),
      ),

      // * Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: colors.modal,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
        contentTextStyle: TextStyle(fontSize: 14, color: colors.textSecondary),
      ),

      // * Bottom Sheet Theme
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        modalBackgroundColor: colors.surface,
        modalElevation: 0,
      ),

      // * Snack Bar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.textPrimary,
        contentTextStyle: TextStyle(fontSize: 14, color: colors.textOnPrimary),
        actionTextColor: colors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 4,
      ),

      // * Tooltip Theme
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.tooltip,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: TextStyle(fontSize: 12, color: colors.textOnPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      // * Popup Menu Theme
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colors.border, width: 1),
        ),
        textStyle: TextStyle(fontSize: 14, color: colors.textPrimary),
      ),

      // * Divider Theme
      dividerTheme: DividerThemeData(
        color: colors.divider,
        thickness: 1,
        space: 16,
      ),

      // * Banner Theme
      bannerTheme: MaterialBannerThemeData(
        backgroundColor: colors.surfaceVariant,
        contentTextStyle: TextStyle(fontSize: 14, color: colors.textPrimary),
        padding: const EdgeInsets.all(16),
      ),

      // * Data Table Theme
      dataTableTheme: DataTableThemeData(
        headingTextStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
        dataTextStyle: TextStyle(fontSize: 14, color: colors.textPrimary),
        columnSpacing: 24,
        horizontalMargin: 16,
        dividerThickness: 1,
      ),

      // * Expansion Tile Theme
      expansionTileTheme: ExpansionTileThemeData(
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        textColor: colors.textPrimary,
        collapsedTextColor: colors.textPrimary,
        iconColor: colors.textSecondary,
        collapsedIconColor: colors.textSecondary,
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        expandedAlignment: Alignment.centerLeft,
      ),

      // * Search Bar Theme
      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStateProperty.all(colors.surface),
        surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        elevation: WidgetStateProperty.all(0),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 16),
        ),
        textStyle: WidgetStateProperty.all(
          TextStyle(fontSize: 16, color: colors.textPrimary),
        ),
        hintStyle: WidgetStateProperty.all(
          TextStyle(fontSize: 16, color: colors.textTertiary),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: colors.border, width: 1),
          ),
        ),
      ),

      // * Segmented Button Theme
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: colors.surface,
          foregroundColor: colors.textPrimary,
          selectedForegroundColor: colors.textOnPrimary,
          selectedBackgroundColor: colors.primary,
          side: BorderSide(color: colors.border, width: 1),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    );
  }

  // * ThemeData Getter for Material Design (Dark)
  static ThemeData get darkTheme {
    const colors = AppColors.dark;
    const semantic = AppColors.semantic;
    final baseTheme = ThemeData.dark(useMaterial3: true);

    return baseTheme.copyWith(
      brightness: Brightness.dark,
      primaryColor: colors.primary,
      scaffoldBackgroundColor: colors.background,

      // * Color Scheme
      colorScheme: ColorScheme.dark(
        primary: colors.primary,
        primaryContainer: colors.primaryContainer,
        secondary: colors.secondary,
        secondaryContainer: colors.secondaryContainer,
        tertiary: colors.accent,
        tertiaryContainer: colors.primaryContainer,
        surface: colors.surface,
        surfaceContainerHighest: colors.surfaceVariant,
        error: semantic.error,
        errorContainer: semantic.errorDark,
        onPrimary: colors.textOnPrimary,
        onPrimaryContainer: colors.textPrimary,
        onSecondary: colors.textOnPrimary,
        onSecondaryContainer: colors.textPrimary,
        onTertiary: colors.textOnAccent,
        onTertiaryContainer: colors.textPrimary,
        onSurface: colors.textPrimary,
        onSurfaceVariant: colors.textSecondary,
        onError: Colors.white,
        onErrorContainer: semantic.errorLight,
        outline: colors.border,
        outlineVariant: colors.divider,
        scrim: colors.scrim,
      ),

      // * Text Theme
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontFamily: kFontHeading,
          fontSize: 57,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.25,
          color: colors.textPrimary,
        ),
        displayMedium: TextStyle(
          fontFamily: kFontHeading,
          fontSize: 45,
          fontWeight: FontWeight.w400,
          color: colors.textPrimary,
        ),
        displaySmall: TextStyle(
          fontFamily: kFontHeading,
          fontSize: 36,
          fontWeight: FontWeight.w400,
          color: colors.textPrimary,
        ),
        headlineLarge: TextStyle(
          fontFamily: kFontHeading,
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
        headlineMedium: TextStyle(
          fontFamily: kFontHeading,
          fontSize: 28,
          fontWeight: FontWeight.w500,
          color: colors.textPrimary,
        ),
        headlineSmall: TextStyle(
          fontFamily: kFontHeading,
          fontSize: 24,
          fontWeight: FontWeight.w500,
          color: colors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontFamily: kFontHeading,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
          color: colors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontFamily: kFontHeading,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15,
          color: colors.textPrimary,
        ),
        titleSmall: TextStyle(
          fontFamily: kFontHeading,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          color: colors.textSecondary,
        ),
        bodyLarge: TextStyle(
          fontFamily: kFontBody,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.5,
          color: colors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontFamily: kFontBody,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.25,
          color: colors.textPrimary,
        ),
        bodySmall: TextStyle(
          fontFamily: kFontBody,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.4,
          color: colors.textSecondary,
        ),
        labelLarge: TextStyle(
          fontFamily: kFontBody,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          color: colors.textPrimary,
        ),
        labelMedium: TextStyle(
          fontFamily: kFontBody,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          color: colors.textSecondary,
        ),
        labelSmall: TextStyle(
          fontFamily: kFontBody,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          color: colors.textTertiary,
        ),
      ),

      // Most theme configurations remain similar to light theme
      // but use dark colors instead

      // * App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black26,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: kFontHeading,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
        actionsIconTheme: IconThemeData(color: colors.textSecondary),
      ),

      // Copy all other theme configurations from light theme but with dark colors
      // ... (rest of the theme configurations follow the same pattern)
    );
  }

  // * CupertinoThemeData Getter for iOS (Light)
  static CupertinoThemeData get cupertinoLightTheme {
    const colors = AppColors.light;

    return CupertinoThemeData(
      brightness: Brightness.light,
      primaryColor: colors.primary,
      scaffoldBackgroundColor: colors.background,
      barBackgroundColor: colors.surface,
      primaryContrastingColor: colors.textOnPrimary,
      textTheme: CupertinoTextThemeData(
        textStyle: TextStyle(color: colors.textPrimary),
        actionTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: colors.primary,
        ),
        tabLabelTextStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: colors.textTertiary,
        ),
        navLargeTitleTextStyle: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.bold,
          color: colors.textPrimary,
        ),
        navTitleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
        pickerTextStyle: TextStyle(fontSize: 18, color: colors.textPrimary),
        dateTimePickerTextStyle: TextStyle(
          fontSize: 18,
          color: colors.textPrimary,
        ),
      ),
    );
  }

  // * CupertinoThemeData Getter for iOS (Dark)
  static CupertinoThemeData get cupertinoDarkTheme {
    const colors = AppColors.dark;

    return CupertinoThemeData(
      brightness: Brightness.dark,
      primaryColor: colors.primary,
      scaffoldBackgroundColor: colors.background,
      barBackgroundColor: colors.surface,
      primaryContrastingColor: colors.textOnPrimary,
      textTheme: CupertinoTextThemeData(
        textStyle: TextStyle(color: colors.textPrimary),
        actionTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: colors.primary,
        ),
        tabLabelTextStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: colors.textTertiary,
        ),
        navLargeTitleTextStyle: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.bold,
          color: colors.textPrimary,
        ),
        navTitleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
        pickerTextStyle: TextStyle(fontSize: 18, color: colors.textPrimary),
        dateTimePickerTextStyle: TextStyle(
          fontSize: 18,
          color: colors.textPrimary,
        ),
      ),
    );
  }
}

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
