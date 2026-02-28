import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/shared/utils/icon_registry.dart';
import 'package:skeletonizer/skeletonizer.dart';

enum ImageSize {
  xSmall(16),
  small(24),
  medium(32),
  large(48),
  xLarge(64),
  xxLarge(96),
  xxxLarge(128),
  fullWidth(250); // Ini default height kalau pakai enum fullWidth

  const ImageSize(this.value);
  final double value;
}

enum ImageShape { circle, rectangle }

class AppImage extends StatelessWidget {
  final ImageSize size;
  final String? imageUrl;
  final String? assetPath;
  final File? imageFile;
  final Widget? placeholder;
  final Widget? errorWidget;
  final VoidCallback? onTap;
  final bool enablePreview;
  final bool showBorder;
  final Color? borderColor;
  final double? borderWidth;
  final ImageShape shape;
  final BoxFit fit;
  final Color? backgroundColor;

  // NEW: Custom overrides biar fleksibel!
  final double? width;
  final double? height;

  const AppImage({
    super.key,
    this.size = ImageSize.medium,
    this.imageUrl,
    this.assetPath,
    this.imageFile,
    this.placeholder,
    this.errorWidget,
    this.onTap,
    this.enablePreview = false,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth,
    this.shape = ImageShape.rectangle,
    this.fit = BoxFit.cover,
    this.backgroundColor,
    this.width, // Tambahkan ini
    this.height, // Tambahkan ini
  });

  bool get _isNetworkImage =>
      imageUrl != null && Uri.tryParse(imageUrl!)?.hasScheme == true;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    // Logic: Kalau width/height di-isi manual, pakai itu.
    // Kalau null, baru fallback ke logic Enum.
    final isFullWidthEnum = size == ImageSize.fullWidth;

    final effectiveWidth =
        width ?? (isFullWidthEnum ? double.infinity : size.value);
    final effectiveHeight = height ?? size.value;

    final borderRadius = shape == ImageShape.circle
        ? BorderRadius.circular(effectiveWidth / 2)
        : BorderRadius.circular(12);

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
              size: effectiveWidth * 0.5,
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
              size: effectiveWidth * 0.5,
              color: theme.colorScheme.error,
            ),
      );
    } else if (imageFile != null) {
      imageWidget = Image.file(
        imageFile!,
        width: effectiveWidth,
        height: effectiveHeight,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            errorWidget ??
            Icon(
              Icons.broken_image,
              size: effectiveWidth * 0.5,
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

    // Container wrapper
    // Hati-hati: kalau width infinity, jangan ditambah margin border nanti error overflow
    final containerWidth = effectiveWidth == double.infinity
        ? double.infinity
        : effectiveWidth + (showBorder ? effectiveBorderWidth * 2 : 0);

    final containerHeight =
        effectiveHeight + (showBorder ? effectiveBorderWidth * 2 : 0);

    final container = Container(
      width: containerWidth,
      // Kalau height null (misal auto), biarkan null. Kalau ada nilainya, pakai containerHeight.
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

    void handleTap() {
      if (onTap != null) {
        onTap!();
      } else if (enablePreview) {
        Widget? previewImage;
        if (_isNetworkImage) {
          previewImage = CachedNetworkImage(
            imageUrl: imageUrl!,
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorWidget: (context, url, error) =>
                const Icon(Icons.broken_image, color: Colors.white, size: 48),
          );
        } else if (assetPath != null) {
          previewImage = Image.asset(assetPath!, fit: BoxFit.contain);
        } else if (imageFile != null) {
          previewImage = Image.file(imageFile!, fit: BoxFit.contain);
        }

        if (previewImage != null) {
          showDialog(
            context: context,
            builder: (context) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.zero,
              child: Stack(
                fit: StackFit.loose,
                alignment: Alignment.center,
                children: [
                  InteractiveViewer(
                    panEnabled: true,
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.black.withValues(alpha: 0.8),
                        child: previewImage,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: SafeArea(
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 32,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    }

    if (onTap != null || enablePreview) {
      return InkWell(
        onTap: handleTap,
        borderRadius: borderRadius,
        child: container,
      );
    }

    return container;
  }

  /// * Factory untuk icon dari icon key atau file path
  /// * Cocok untuk small icons di dropdown, list tile, dll
  static Widget icon({
    required String iconData,
    double size = 24,
    Color? color,
    BoxFit fit = BoxFit.contain,
  }) {
    if (iconData.isEmpty) {
      return SizedBox(width: size, height: size);
    }

    // * Try getting icon from registry (new format: icon key)
    final registryIcon = IconRegistry.getIcon(iconData);
    if (registryIcon != null) {
      return Icon(registryIcon, size: size, color: color);
    }

    // * Skip old asset paths (no longer supported)
    if (iconData.startsWith('assets/')) {
      return Icon(Icons.image_outlined, size: size, color: color);
    }

    // * Otherwise treat as file path (user uploaded image)
    // * Note: Don't apply color tint to user uploaded images
    final file = File(iconData);
    return FutureBuilder<bool>(
      future: file.exists(),
      builder: (context, snapshot) {
        if (snapshot.data == true) {
          return Image.file(
            file,
            width: size,
            height: size,
            fit: fit,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.broken_image_outlined,
                size: size,
                color: color,
              );
            },
          );
        }
        // * File doesn't exist or still checking
        return Icon(
          Icons.image_not_supported_outlined,
          size: size,
          color: color,
        );
      },
    );
  }
}
