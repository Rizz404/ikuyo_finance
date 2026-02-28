import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/features/security/cubit/security_cubit.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';

/// Dialog untuk setup / ubah password
class PasswordSetupDialog extends StatefulWidget {
  final VoidCallback? onSuccess;

  const PasswordSetupDialog({super.key, this.onSuccess});

  @override
  State<PasswordSetupDialog> createState() => _PasswordSetupDialogState();
}

class _PasswordSetupDialogState extends State<PasswordSetupDialog> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _errorText;
  bool _obscure = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _save() {
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (password.length < 6) {
      setState(() => _errorText = LocaleKeys.securityPasswordTooShort.tr());
      return;
    }

    if (password != confirm) {
      setState(() => _errorText = LocaleKeys.securityPasswordMismatch.tr());
      return;
    }

    context.read<SecurityCubit>().setPassword(password);
    Navigator.of(context).pop();
    widget.onSuccess?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AlertDialog(
      title: AppText(
        LocaleKeys.securityPasswordSetup.tr(),
        style: AppTextStyle.titleMedium,
        fontWeight: FontWeight.bold,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppText(
            LocaleKeys.securityPasswordSetupDesc.tr(),
            style: AppTextStyle.bodyMedium,
            color: colors.textSecondary,
          ),
          const SizedBox(height: 16),
          // * Password
          TextField(
            controller: _passwordController,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: LocaleKeys.securityPasswordLabel.tr(),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.primary, width: 2),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // * Confirm password
          TextField(
            controller: _confirmController,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              labelText: LocaleKeys.securityPasswordConfirmLabel.tr(),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.primary, width: 2),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            onSubmitted: (_) => _save(),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 8),
            AppText(
              _errorText!,
              style: AppTextStyle.bodySmall,
              color: context.semantic.error,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(LocaleKeys.securityCancel.tr()),
        ),
        TextButton(onPressed: _save, child: Text(LocaleKeys.securitySave.tr())),
      ],
    );
  }
}
