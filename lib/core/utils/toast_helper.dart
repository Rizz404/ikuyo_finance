import 'package:flutter/material.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';
import 'package:toastification/toastification.dart';

/// Toast helper untuk menampilkan notifikasi dengan tema aplikasi
class ToastHelper {
  ToastHelper._();

  static final ToastHelper _instance = ToastHelper._();
  static ToastHelper get instance => _instance;

  /// Show success toast
  ToastificationItem showSuccess({
    required BuildContext context,
    required String title,
    String? description,
    Duration? duration,
    Alignment? alignment,
    bool showProgressBar = true,
    bool closeOnClick = true,
    bool pauseOnHover = true,
    bool dragToClose = true,
  }) {
    final colors = context.colors;
    final semantic = context.semantic;

    logInfo('Showing success toast: $title');

    return toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.flatColored,
      title: Text(title),
      description: description != null ? Text(description) : null,
      alignment: alignment ?? Alignment.topRight,
      autoCloseDuration: duration ?? const Duration(seconds: 4),
      primaryColor: semantic.success,
      backgroundColor: colors.surface,
      foregroundColor: colors.textPrimary,
      icon: const Icon(Icons.check_circle_rounded),
      showIcon: true,
      showProgressBar: showProgressBar,
      closeOnClick: closeOnClick,
      pauseOnHover: pauseOnHover,
      dragToClose: dragToClose,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: semantic.success.withValues(alpha: 0.1),
          blurRadius: 16,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
      ],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      animationDuration: const Duration(milliseconds: 300),
      callbacks: ToastificationCallbacks(
        onTap: (item) => logInfo('Success toast tapped: ${item.id}'),
        onDismissed: (item) => logInfo('Success toast dismissed: ${item.id}'),
      ),
    );
  }

  /// Show error toast
  ToastificationItem showError({
    required BuildContext context,
    required String title,
    String? description,
    Duration? duration,
    Alignment? alignment,
    bool showProgressBar = true,
    bool closeOnClick = true,
    bool pauseOnHover = true,
    bool dragToClose = true,
  }) {
    final colors = context.colors;
    final semantic = context.semantic;

    logError('Showing error toast: $title');

    return toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.flatColored,
      title: Text(title),
      description: description != null ? Text(description) : null,
      alignment: alignment ?? Alignment.topRight,
      autoCloseDuration: duration ?? const Duration(seconds: 5),
      primaryColor: semantic.error,
      backgroundColor: colors.surface,
      foregroundColor: colors.textPrimary,
      icon: const Icon(Icons.error_rounded),
      showIcon: true,
      showProgressBar: showProgressBar,
      closeOnClick: closeOnClick,
      pauseOnHover: pauseOnHover,
      dragToClose: dragToClose,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: semantic.error.withValues(alpha: 0.1),
          blurRadius: 16,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
      ],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      animationDuration: const Duration(milliseconds: 300),
      callbacks: ToastificationCallbacks(
        onTap: (item) => logInfo('Error toast tapped: ${item.id}'),
        onDismissed: (item) => logInfo('Error toast dismissed: ${item.id}'),
      ),
    );
  }

  /// Show warning toast
  ToastificationItem showWarning({
    required BuildContext context,
    required String title,
    String? description,
    Duration? duration,
    Alignment? alignment,
    bool showProgressBar = true,
    bool closeOnClick = true,
    bool pauseOnHover = true,
    bool dragToClose = true,
  }) {
    final colors = context.colors;
    final semantic = context.semantic;

    logInfo('Showing warning toast: $title');

    return toastification.show(
      context: context,
      type: ToastificationType.warning,
      style: ToastificationStyle.flatColored,
      title: Text(title),
      description: description != null ? Text(description) : null,
      alignment: alignment ?? Alignment.topRight,
      autoCloseDuration: duration ?? const Duration(seconds: 4),
      primaryColor: semantic.warning,
      backgroundColor: colors.surface,
      foregroundColor: colors.textPrimary,
      icon: const Icon(Icons.warning_rounded),
      showIcon: true,
      showProgressBar: showProgressBar,
      closeOnClick: closeOnClick,
      pauseOnHover: pauseOnHover,
      dragToClose: dragToClose,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: semantic.warning.withValues(alpha: 0.1),
          blurRadius: 16,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
      ],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      animationDuration: const Duration(milliseconds: 300),
      callbacks: ToastificationCallbacks(
        onTap: (item) => logInfo('Warning toast tapped: ${item.id}'),
        onDismissed: (item) => logInfo('Warning toast dismissed: ${item.id}'),
      ),
    );
  }

  /// Show info toast
  ToastificationItem showInfo({
    required BuildContext context,
    required String title,
    String? description,
    Duration? duration,
    Alignment? alignment,
    bool showProgressBar = true,
    bool closeOnClick = true,
    bool pauseOnHover = true,
    bool dragToClose = true,
  }) {
    final colors = context.colors;
    final semantic = context.semantic;

    logInfo('Showing info toast: $title');

    return toastification.show(
      context: context,
      type: ToastificationType.info,
      style: ToastificationStyle.flatColored,
      title: Text(title),
      description: description != null ? Text(description) : null,
      alignment: alignment ?? Alignment.topRight,
      autoCloseDuration: duration ?? const Duration(seconds: 4),
      primaryColor: semantic.info,
      backgroundColor: colors.surface,
      foregroundColor: colors.textPrimary,
      icon: const Icon(Icons.info_rounded),
      showIcon: true,
      showProgressBar: showProgressBar,
      closeOnClick: closeOnClick,
      pauseOnHover: pauseOnHover,
      dragToClose: dragToClose,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: semantic.info.withValues(alpha: 0.1),
          blurRadius: 16,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
      ],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      animationDuration: const Duration(milliseconds: 300),
      callbacks: ToastificationCallbacks(
        onTap: (item) => logInfo('Info toast tapped: ${item.id}'),
        onDismissed: (item) => logInfo('Info toast dismissed: ${item.id}'),
      ),
    );
  }

  /// Dismiss toast by ID
  void dismissById(String id) {
    logInfo('Dismissing toast: $id');
    toastification.dismissById(id);
  }

  /// Dismiss all toasts
  void dismissAll({bool delayForAnimation = true}) {
    logInfo('Dismissing all toasts');
    toastification.dismissAll(delayForAnimation: delayForAnimation);
  }
}
