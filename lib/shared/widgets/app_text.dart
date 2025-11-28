import 'package:flutter/material.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';

enum AppTextStyle {
  displayLarge,
  displayMedium,
  displaySmall,
  headlineLarge,
  headlineMedium,
  headlineSmall,
  titleLarge,
  titleMedium,
  titleSmall,
  bodyLarge,
  bodyMedium,
  bodySmall,
  labelLarge,
  labelMedium,
  labelSmall,
}

class AppText extends StatelessWidget {
  final String text;
  final AppTextStyle? style;
  final TextAlign? textAlign;
  final Color? color;
  final TextStyle? customStyle;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final double? fontSize;
  final FontWeight? fontWeight;
  final double? letterSpacing;
  final double? lineHeight;
  final TextDecoration? decoration;

  const AppText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.color,
    this.customStyle,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.fontSize,
    this.fontWeight,
    this.letterSpacing,
    this.lineHeight,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;

    TextStyle getBaseStyle() {
      if (customStyle != null) return customStyle!;

      // Default ke bodyMedium jika style tidak dispesifikasikan
      final selectedStyle = style ?? AppTextStyle.bodyMedium;

      // Pemetaan dari AppTextStyle ke TextTheme Material 3
      switch (selectedStyle) {
        case AppTextStyle.displayLarge:
          return textTheme.displayLarge!;
        case AppTextStyle.displayMedium:
          return textTheme.displayMedium!;
        case AppTextStyle.displaySmall:
          return textTheme.displaySmall!;
        case AppTextStyle.headlineLarge:
          return textTheme.headlineLarge!;
        case AppTextStyle.headlineMedium:
          return textTheme.headlineMedium!;
        case AppTextStyle.headlineSmall:
          return textTheme.headlineSmall!;
        case AppTextStyle.titleLarge:
          return textTheme.titleLarge!;
        case AppTextStyle.titleMedium:
          return textTheme.titleMedium!;
        case AppTextStyle.titleSmall:
          return textTheme.titleSmall!;
        case AppTextStyle.bodyLarge:
          return textTheme.bodyLarge!;
        case AppTextStyle.bodyMedium:
          return textTheme.bodyMedium!;
        case AppTextStyle.bodySmall:
          return textTheme.bodySmall!;
        case AppTextStyle.labelLarge:
          return textTheme.labelLarge!;
        case AppTextStyle.labelMedium:
          return textTheme.labelMedium!;
        case AppTextStyle.labelSmall:
          return textTheme.labelSmall!;
      }
    }

    final finalStyle = getBaseStyle().copyWith(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: lineHeight,
      decoration: decoration,
    );

    return Text(
      text,
      style: finalStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
    );
  }
}
