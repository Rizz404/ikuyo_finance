import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:skeletonizer/skeletonizer.dart';

enum AvatarSize {
  xSmall(16),
  small(24),
  medium(32),
  large(48),
  xLarge(64),
  xxLarge(96),
  xxxLarge(128);

  const AvatarSize(this.value);
  final double value;
}

enum AvatarShape { circle, rectangle }

class AppAvatar extends StatelessWidget {
  final AvatarSize size;
  final String? imageUrl;
  final String? assetPath;
  final Widget? placeholder;
  final Widget? errorWidget;
  final VoidCallback? onTap;
  final bool showBorder;
  final Color? borderColor;
  final double? borderWidth;
  final AvatarShape shape;
  final BoxFit fit;
  final Color? backgroundColor;

  const AppAvatar({
    super.key,
    this.size = AvatarSize.medium,
    this.imageUrl,
    this.assetPath,
    this.placeholder,
    this.errorWidget,
    this.onTap,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth,
    this.shape = AvatarShape.circle,
    this.fit = BoxFit.cover,
    this.backgroundColor,
  });

  bool get _isNetworkImage =>
      imageUrl != null && Uri.tryParse(imageUrl!)?.hasScheme == true;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    final borderRadius = shape == AvatarShape.circle
        ? BorderRadius.circular(size.value / 2)
        : BorderRadius.circular(8);

    final effectiveBorderColor = borderColor ?? theme.colorScheme.outline;
    final effectiveBorderWidth = borderWidth ?? 1.0;

    Widget avatarWidget;

    if (_isNetworkImage) {
      avatarWidget = CachedNetworkImage(
        imageUrl: imageUrl!,
        width: size.value,
        height: size.value,
        fit: fit,
        placeholder: (context, url) => Skeletonizer(
          enabled: true,
          child: Container(
            width: size.value,
            height: size.value,
            color: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        errorWidget: (context, url, error) =>
            errorWidget ??
            Icon(
              Icons.error,
              size: size.value * 0.5,
              color: theme.colorScheme.error,
            ),
      );
    } else if (assetPath != null) {
      avatarWidget = Image.asset(
        assetPath!,
        width: size.value,
        height: size.value,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            errorWidget ??
            Icon(
              Icons.error,
              size: size.value * 0.5,
              color: theme.colorScheme.error,
            ),
      );
    } else {
      avatarWidget =
          placeholder ??
          Container(
            width: size.value,
            height: size.value,
            color: backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.person,
              size: size.value * 0.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );
    }

    final container = Container(
      width: size.value + (showBorder ? effectiveBorderWidth * 2 : 0),
      height: size.value + (showBorder ? effectiveBorderWidth * 2 : 0),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: showBorder
            ? Border.all(
                color: effectiveBorderColor,
                width: effectiveBorderWidth,
              )
            : null,
      ),
      child: ClipRRect(borderRadius: borderRadius, child: avatarWidget),
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
