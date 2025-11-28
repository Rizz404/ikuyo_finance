import 'package:flutter/material.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';

enum AppButtonVariant { filled, outlined, text }

enum AppButtonColor { primary, secondary, success, error, warning, neutral }

enum AppButtonSize { small, medium, large }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonVariant variant;
  final AppButtonColor color;
  final AppButtonSize size;
  final bool isFullWidth;
  final Widget? leadingIcon;
  final Widget? trailingIcon;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.variant = AppButtonVariant.filled,
    this.color = AppButtonColor.primary,
    this.size = AppButtonSize.medium,
    this.isFullWidth = true,
    this.leadingIcon,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    ({Color backgroundColor, Color foregroundColor, BorderSide? side})
    _getColorProps() {
      // *  Udah dibennerin harusnya
      final colorMap = {
        AppButtonColor.primary: (
          bg: theme.colorScheme.primary,
          fg: theme.colorScheme.onPrimary,
        ),
        AppButtonColor.secondary: (
          bg: theme.colorScheme.secondary,
          fg: theme.colorScheme.onSecondary,
        ),
        AppButtonColor.success: (
          bg: context.semantic.success,
          fg: context.colors.textOnPrimary,
        ),
        AppButtonColor.error: (
          bg: theme.colorScheme.error,
          fg: theme.colorScheme.onError,
        ),
        AppButtonColor.warning: (
          bg: context.semantic.warning,
          fg: context.colors.textPrimary,
        ),
        AppButtonColor.neutral: (
          bg: theme.colorScheme.surfaceContainerHighest,
          fg: theme.colorScheme.onSurfaceVariant,
        ),
      };

      final selectedColorSet = colorMap[color]!;

      switch (variant) {
        case AppButtonVariant.filled:
          return (
            backgroundColor: selectedColorSet.bg,
            foregroundColor: selectedColorSet.fg,
            side: null,
          );
        case AppButtonVariant.outlined:
          return (
            backgroundColor: Colors.transparent,
            foregroundColor: selectedColorSet.bg,
            side: BorderSide(color: selectedColorSet.bg, width: 1.5),
          );
        case AppButtonVariant.text:
          return (
            backgroundColor: Colors.transparent,
            foregroundColor: selectedColorSet.bg,
            side: null,
          );
      }
    }

    ({EdgeInsetsGeometry padding, TextStyle? textStyle, double height})
    _getSizingProps() {
      switch (size) {
        case AppButtonSize.small:
          return (
            padding: const EdgeInsets.symmetric(horizontal: 16),
            textStyle: theme.textTheme.labelLarge,
            height: 40,
          );
        case AppButtonSize.large:
          return (
            padding: const EdgeInsets.symmetric(horizontal: 32),
            textStyle: theme.textTheme.titleMedium,
            height: 60,
          );
        case AppButtonSize.medium:
          return (
            padding: const EdgeInsets.symmetric(horizontal: 24),
            textStyle: theme.textTheme.titleSmall,
            height: 50,
          );
      }
    }

    final colorProps = _getColorProps();
    final sizingProps = _getSizingProps();

    // Progress indicator color should always contrast with background
    final progressIndicatorColor = variant == AppButtonVariant.filled
        ? colorProps.foregroundColor
        : colorProps.backgroundColor;

    final buttonContent = isLoading
        ? SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: progressIndicatorColor,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leadingIcon != null) ...[
                IconTheme(
                  data: IconThemeData(
                    color: colorProps.foregroundColor,
                    size: 20,
                  ),
                  child: leadingIcon!,
                ),
                const SizedBox(width: 8),
              ],
              AppText(
                text,
                color: colorProps.foregroundColor,
                fontWeight: FontWeight.w600,
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 8),
                IconTheme(
                  data: IconThemeData(
                    color: colorProps.foregroundColor,
                    size: 20,
                  ),
                  child: trailingIcon!,
                ),
              ],
            ],
          );

    final baseStyle = ButtonStyle(
      padding: WidgetStateProperty.all(sizingProps.padding),
      textStyle: WidgetStateProperty.all(sizingProps.textStyle),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return theme.colorScheme.onSurface.withValues(alpha: 0.12);
        }
        return colorProps.backgroundColor;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return theme.colorScheme.onSurface.withValues(alpha: 0.38);
        }
        return colorProps.foregroundColor;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled) && colorProps.side != null) {
          return BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
            width: colorProps.side!.width,
          );
        }
        return colorProps.side;
      }),
      minimumSize: isFullWidth
          ? WidgetStateProperty.all(Size.fromHeight(sizingProps.height))
          : WidgetStateProperty.all(Size(88, sizingProps.height)),
      maximumSize: isFullWidth
          ? WidgetStateProperty.all(Size.fromHeight(sizingProps.height))
          : null,
      elevation: WidgetStateProperty.resolveWith((states) {
        if (variant == AppButtonVariant.filled &&
            !states.contains(WidgetState.disabled)) {
          return states.contains(WidgetState.pressed) ? 1 : 2;
        }
        return 0;
      }),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) {
          return colorProps.foregroundColor.withValues(alpha: 0.08);
        }
        if (states.contains(WidgetState.pressed)) {
          return colorProps.foregroundColor.withValues(alpha: 0.12);
        }
        return null;
      }),
    );

    switch (variant) {
      case AppButtonVariant.outlined:
        return OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: baseStyle,
          child: buttonContent,
        );
      case AppButtonVariant.text:
        return TextButton(
          onPressed: isLoading ? null : onPressed,
          style: baseStyle,
          child: buttonContent,
        );
      case AppButtonVariant.filled:
        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: baseStyle,
          child: buttonContent,
        );
    }
  }
}
