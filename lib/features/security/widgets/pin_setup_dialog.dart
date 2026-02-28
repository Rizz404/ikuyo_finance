import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/features/security/cubit/security_cubit.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';

/// Dialog untuk setup / ubah PIN (4-6 digit)
class PinSetupDialog extends StatefulWidget {
  final VoidCallback? onSuccess;

  const PinSetupDialog({super.key, this.onSuccess});

  @override
  State<PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<PinSetupDialog> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _errorText;
  bool _isConfirming = false;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _proceed() {
    if (!_isConfirming) {
      // * Step 1: enter PIN
      final pin = _pinController.text.trim();
      if (pin.length < 4) {
        setState(() => _errorText = LocaleKeys.securityPinTooShort.tr());
        return;
      }
      setState(() {
        _isConfirming = true;
        _errorText = null;
      });
    } else {
      // * Step 2: confirm PIN
      final pin = _pinController.text.trim();
      final confirm = _confirmController.text.trim();
      if (pin != confirm) {
        setState(() => _errorText = LocaleKeys.securityPinMismatch.tr());
        return;
      }

      context.read<SecurityCubit>().setPin(pin);
      Navigator.of(context).pop();
      widget.onSuccess?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AlertDialog(
      title: AppText(
        _isConfirming
            ? LocaleKeys.securityPinConfirm.tr()
            : LocaleKeys.securityPinSetup.tr(),
        style: AppTextStyle.titleMedium,
        fontWeight: FontWeight.bold,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppText(
            _isConfirming
                ? LocaleKeys.securityPinConfirmDesc.tr()
                : LocaleKeys.securityPinSetupDesc.tr(),
            style: AppTextStyle.bodyMedium,
            color: colors.textSecondary,
          ),
          const SizedBox(height: 16),
          if (!_isConfirming)
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              textAlign: TextAlign.center,
              autofocus: true,
              style: const TextStyle(fontSize: 24, letterSpacing: 12),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: '••••',
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.primary, width: 2),
                ),
              ),
            )
          else
            TextField(
              controller: _confirmController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              textAlign: TextAlign.center,
              autofocus: true,
              style: const TextStyle(fontSize: 24, letterSpacing: 12),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: '••••',
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.primary, width: 2),
                ),
              ),
              onSubmitted: (_) => _proceed(),
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
        TextButton(
          onPressed: _proceed,
          child: Text(
            _isConfirming
                ? LocaleKeys.securitySave.tr()
                : LocaleKeys.securityNext.tr(),
          ),
        ),
      ],
    );
  }
}
