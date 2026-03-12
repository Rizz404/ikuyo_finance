import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/extensions/theme_extension.dart';
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
  final _pinFocus = FocusNode();
  final _confirmFocus = FocusNode();
  String? _errorText;
  bool _isConfirming = false;
  int _pinLength = 6;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    _pinFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _proceed() {
    if (!_isConfirming) {
      // * Step 1: enter PIN
      final pin = _pinController.text.trim();
      if (pin.length != _pinLength) {
        setState(() => _errorText = LocaleKeys.securityPinTooShort.tr());
        return;
      }
      setState(() {
        _isConfirming = true;
        _errorText = null;
      });
      Future.delayed(
        const Duration(milliseconds: 100),
        () => _confirmFocus.requestFocus(),
      );
    } else {
      // * Step 2: confirm PIN
      final pin = _pinController.text.trim();
      final confirm = _confirmController.text.trim();
      if (pin != confirm) {
        setState(() {
          _errorText = LocaleKeys.securityPinMismatch.tr();
          _confirmController.clear();
        });
        _confirmFocus.requestFocus();
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
          if (!_isConfirming) ...[
            SegmentedButton<int>(
              segments: [
                ButtonSegment(
                  value: 4,
                  label: Text(LocaleKeys.securityPinDigit.tr(args: ['4'])),
                ),
                ButtonSegment(
                  value: 6,
                  label: Text(LocaleKeys.securityPinDigit.tr(args: ['6'])),
                ),
              ],
              selected: {_pinLength},
              onSelectionChanged: (Set<int> newSelection) {
                setState(() {
                  _pinLength = newSelection.first;
                  _pinController.clear();
                  _errorText = null;
                });
                _pinFocus.requestFocus();
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              focusNode: _pinFocus,
              keyboardType: TextInputType.number,
              maxLength: _pinLength,
              obscureText: true,
              textAlign: TextAlign.center,
              autofocus: true,
              style: const TextStyle(fontSize: 24, letterSpacing: 12),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: '•' * _pinLength,
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.primary, width: 2),
                ),
              ),
              onChanged: (value) {
                if (value.length == _pinLength) {
                  _proceed();
                }
              },
            ),
          ] else
            TextField(
              controller: _confirmController,
              focusNode: _confirmFocus,
              keyboardType: TextInputType.number,
              maxLength: _pinLength,
              obscureText: true,
              textAlign: TextAlign.center,
              autofocus: true,
              style: const TextStyle(fontSize: 24, letterSpacing: 12),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: '•' * _pinLength,
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.primary, width: 2),
                ),
              ),
              onChanged: (value) {
                if (value.length == _pinLength) {
                  _proceed();
                }
              },
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
        if (!_isConfirming)
          TextButton(
            onPressed: _proceed,
            child: Text(LocaleKeys.securityNext.tr()),
          ),
      ],
    );
  }
}
