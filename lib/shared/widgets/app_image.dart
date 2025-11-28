import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:skeletonizer/skeletonizer.dart';

enum ImageSize {
  xSmall(16),
  small(24),
  medium(32),
  large(48),
  xLarge(64),
  xxLarge(96),
  xxxLarge(128),
  fullWidth(250);

  const ImageSize(this.value);
  final double value;
}

enum ImageShape { circle, rectangle }

class AppImage extends StatelessWidget {
  final ImageSize size;
  final String? imageUrl;
  final String? assetPath;
  final Widget? placeholder;
  final Widget? errorWidget;
  final VoidCallback? onTap;
  final bool showBorder;
  final Color? borderColor;
  final double? borderWidth;
  final ImageShape shape;
  final BoxFit fit;
  final Color? backgroundColor;

  const AppImage({
    super.key,
    this.size = ImageSize.medium,
    this.imageUrl,
    this.assetPath,
    this.placeholder,
    this.errorWidget,
    this.onTap,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth,
    this.shape = ImageShape.rectangle,
    this.fit = BoxFit.cover,
    this.backgroundColor,
  });

  bool get _isNetworkImage =>
      imageUrl != null && Uri.tryParse(imageUrl!)?.hasScheme == true;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    final isFullWidth = size == ImageSize.fullWidth;

    final effectiveWidth = isFullWidth ? null : size.value;
    final effectiveHeight = size.value;

    final borderRadius = shape == ImageShape.circle
        ? BorderRadius.circular((effectiveWidth ?? size.value) / 2)
        : BorderRadius.circular(8);

    final effectiveBorderColor = borderColor ?? theme.colorScheme.outline;
    final effectiveBorderWidth = borderWidth ?? 1.0;

    Widget imageWidget;

    if (_isNetworkImage) {
      imageWidget = CachedNetworkImage(
        imageUrl: imageUrl!,
        width: effectiveWidth,
        height: effectiveHeight,
        fit: fit,
        placeholder: (context, url) => Skeletonizer(
          enabled: true,
          child: Container(
            width: effectiveWidth,
            height: effectiveHeight,
            color: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        errorWidget: (context, url, error) =>
            errorWidget ??
            Icon(
              Icons.broken_image,
              size: (effectiveWidth ?? size.value) * 0.5,
              color: theme.colorScheme.error,
            ),
      );
    } else if (assetPath != null) {
      imageWidget = Image.asset(
        assetPath!,
        width: effectiveWidth,
        height: effectiveHeight,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            errorWidget ??
            Icon(
              Icons.broken_image,
              size: (effectiveWidth ?? size.value) * 0.5,
              color: theme.colorScheme.error,
            ),
      );
    } else {
      imageWidget =
          placeholder ??
          Container(
            width: effectiveWidth,
            height: effectiveHeight,
            color: backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
          );
    }

    final containerWidth = isFullWidth
        ? double.infinity
        : size.value + (showBorder ? effectiveBorderWidth * 2 : 0);
    final containerHeight =
        size.value + (showBorder ? effectiveBorderWidth * 2 : 0);

    final container = Container(
      width: containerWidth,
      height: containerHeight,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: showBorder
            ? Border.all(
                color: effectiveBorderColor,
                width: effectiveBorderWidth,
              )
            : null,
      ),
      child: ClipRRect(borderRadius: borderRadius, child: imageWidget),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: container,
      );
    }

    return container;
  }
}
