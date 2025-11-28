import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';

/// Reusable loader overlay widget
class AppLoaderOverlay extends StatelessWidget {
  final Widget child;
  final Color? overlayColor;
  final double? overlayOpacity;

  const AppLoaderOverlay({
    super.key,
    required this.child,
    this.overlayColor,
    this.overlayOpacity,
  });

  @override
  Widget build(BuildContext context) {
    return LoaderOverlay(
      overlayColor: (overlayColor ?? Colors.black).withValues(
        alpha: overlayOpacity ?? 0.6,
      ),
      overlayWidgetBuilder: (progress) => Center(
        child: SpinKitThreeBounce(color: context.colorScheme.primary, size: 50),
      ),
      child: child,
    );
  }
}
