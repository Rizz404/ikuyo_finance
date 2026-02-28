import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:ikuyo_finance/core/currency/cubit/currency_cubit.dart';
import 'package:ikuyo_finance/core/currency/models/currency.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';

enum AppTextFieldType {
  email,
  password,
  text,
  phone,
  number,
  currency,
  url,
  multiline,
  hidden, // * Hidden field untuk form validation tanpa UI visible
}

class AppTextField extends StatefulWidget {
  final String name;
  final String? initialValue;
  final String label;
  final String? placeHolder;
  final AppTextFieldType type;
  final int? maxLines;
  final String? Function(String?)? validator;
  final bool enableAutoCapitalization;
  final bool readOnly;
  final String? prefixText;
  final String? suffixText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final void Function(String?)? onChanged;
  final bool? enabled;

  const AppTextField({
    super.key,
    required this.name,
    this.initialValue,
    required this.label,
    this.placeHolder,
    this.type = AppTextFieldType.text,
    this.maxLines,
    this.validator,
    this.enableAutoCapitalization = true,
    this.readOnly = false,
    this.prefixText,
    this.suffixText,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.enabled,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final isPassword = widget.type == AppTextFieldType.password;
    final isHidden = widget.type == AppTextFieldType.hidden;
    final isMultiline =
        widget.type == AppTextFieldType.multiline ||
        (widget.maxLines != null && widget.maxLines! > 1);

    // * Return invisible field untuk hidden type
    if (isHidden) {
      return SizedBox(
        height: 0,
        child: FormBuilderTextField(
          name: widget.name,
          initialValue: widget.initialValue,
          validator: widget.validator,
          onChanged: widget.onChanged,
          style: const TextStyle(height: 0, fontSize: 0),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            constraints: BoxConstraints(maxHeight: 0, maxWidth: 0),
          ),
        ),
      );
    }

    // Menentukan keyboard type berdasarkan enum
    TextInputType getKeyboardType() {
      switch (widget.type) {
        case AppTextFieldType.email:
          return TextInputType.emailAddress;
        case AppTextFieldType.phone:
          return TextInputType.phone;
        case AppTextFieldType.number:
        case AppTextFieldType.currency:
          return TextInputType.number;
        case AppTextFieldType.url:
          return TextInputType.url;
        case AppTextFieldType.multiline:
          return TextInputType.multiline;
        default:
          return TextInputType.text;
      }
    }

    // Menentukan text capitalization
    TextCapitalization getTextCapitalization() {
      if (!widget.enableAutoCapitalization) return TextCapitalization.none;

      switch (widget.type) {
        case AppTextFieldType.email:
        case AppTextFieldType.password:
        case AppTextFieldType.phone:
        case AppTextFieldType.number:
        case AppTextFieldType.currency:
        case AppTextFieldType.url:
          return TextCapitalization.none;
        default:
          return TextCapitalization.sentences;
      }
    }

    // Menentukan input formatters
    List<TextInputFormatter> getInputFormatters() {
      switch (widget.type) {
        case AppTextFieldType.number:
          return [FilteringTextInputFormatter.digitsOnly];
        case AppTextFieldType.currency:
          final currency = context.read<CurrencyCubit>().state.currency;
          if (currency.decimalDigits > 0) {
            return [
              FilteringTextInputFormatter.allow(
                RegExp(
                  r'[0-9' + _escapeRegex(currency.decimalSeparator) + r']',
                ),
              ),
              _CurrencyFormatter(currency),
            ];
          }
          return [
            FilteringTextInputFormatter.digitsOnly,
            _CurrencyFormatter(currency),
          ];
        case AppTextFieldType.phone:
          return [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s\(\)]'))];
        default:
          return [];
      }
    }

    // Menentukan prefix dan suffix text
    String? getPrefixText() {
      if (widget.prefixText != null) return widget.prefixText;

      switch (widget.type) {
        case AppTextFieldType.currency:
          final currency = context.read<CurrencyCubit>().state.currency;
          return currency.symbol;
        default:
          return null;
      }
    }

    // * Format initial value untuk currency field
    String? formattedInitialValue = widget.initialValue;
    if (widget.type == AppTextFieldType.currency &&
        widget.initialValue != null) {
      final currency = context.read<CurrencyCubit>().state.currency;
      formattedInitialValue = _CurrencyFormatter.formatValue(
        widget.initialValue!,
        currency,
      );
    }

    return FormBuilderTextField(
      name: widget.name,
      initialValue: formattedInitialValue,
      maxLines: isPassword ? 1 : (widget.maxLines ?? (isMultiline ? 5 : 1)),
      obscureText: isPassword ? _obscureText : false,
      keyboardType: getKeyboardType(),
      textCapitalization: getTextCapitalization(),
      inputFormatters: getInputFormatters(),
      readOnly: widget.readOnly,
      valueTransformer: (value) => value?.trim(),
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.placeHolder,
        prefixText: getPrefixText(),
        suffixText: widget.suffixText,
        prefixIcon: widget.prefixIcon,
        suffixIcon:
            widget.suffixIcon ??
            (isPassword
                ? IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  )
                : null),
        filled: true,
        fillColor: context.colors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.semantic.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.semantic.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: widget.validator,
      enabled: widget.enabled ?? true,
    );
  }
}

// * Escape special regex characters in separator string
String _escapeRegex(String s) =>
    s.replaceAllMapped(RegExp(r'[.*+?^${}()|[\]\\]'), (m) => '\\${m[0]}');

/// Dynamic currency formatter based on Currency model
/// Supports different thousand/decimal separators per currency
class _CurrencyFormatter extends TextInputFormatter {
  final Currency currency;

  const _CurrencyFormatter(this.currency);

  /// Static method to format initial value
  static String formatValue(String value, Currency currency) {
    if (value.isEmpty) return value;

    // * Remove all non-digit & non-decimal-separator characters
    final cleanDigits = value.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanDigits.isEmpty) return '';

    return _addThousandSeparator(cleanDigits, currency.thousandSeparator);
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final separator = currency.thousandSeparator;
    final decSep = currency.decimalSeparator;
    final hasDecimals = currency.decimalDigits > 0;

    String newText = newValue.text;
    int cursorIndex = newValue.selection.end;

    // * Count digits (and decimal separator) before cursor
    int digitsBeforeCursor = 0;
    bool passedDecimal = false;
    for (int i = 0; i < cursorIndex && i < newText.length; i++) {
      if (RegExp(r'\d').hasMatch(newText[i])) {
        digitsBeforeCursor++;
      } else if (hasDecimals && newText[i] == decSep && !passedDecimal) {
        passedDecimal = true;
        digitsBeforeCursor++; // * Count decimal separator as a position marker
      }
    }

    // * Extract only digits and (optionally) one decimal separator
    String cleaned;
    if (hasDecimals) {
      // * Allow one decimal separator
      final parts = newText.split(decSep);
      final intPart = parts[0].replaceAll(RegExp(r'[^\d]'), '');
      if (parts.length > 1) {
        final decPart = parts
            .sublist(1)
            .join()
            .replaceAll(RegExp(r'[^\d]'), '');
        final trimmedDec = decPart.length > currency.decimalDigits
            ? decPart.substring(0, currency.decimalDigits)
            : decPart;
        cleaned = intPart.isEmpty ? '0' : intPart;
        final formatted = _addThousandSeparator(cleaned, separator);
        final result = '$formatted$decSep$trimmedDec';

        // * Recalculate cursor
        int newCursorIndex = _recalculateCursor(
          result,
          digitsBeforeCursor,
          separator,
          decSep,
        );
        return TextEditingValue(
          text: result,
          selection: TextSelection.collapsed(offset: newCursorIndex),
        );
      }
      cleaned = intPart;
    } else {
      cleaned = newText.replaceAll(RegExp(r'[^\d]'), '');
    }

    if (cleaned.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final formatted = _addThousandSeparator(cleaned, separator);

    int newCursorIndex = _recalculateCursor(
      formatted,
      digitsBeforeCursor,
      separator,
      decSep,
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursorIndex),
    );
  }

  /// Recalculate cursor position in formatted string
  static int _recalculateCursor(
    String formatted,
    int targetDigits,
    String separator,
    String decSep,
  ) {
    int cursor = 0;
    int encountered = 0;
    for (int i = 0; i < formatted.length; i++) {
      if (encountered == targetDigits) break;
      if (RegExp(r'\d').hasMatch(formatted[i]) || formatted[i] == decSep) {
        encountered++;
      }
      cursor++;
    }
    return cursor;
  }

  /// Add thousand separators to a digit-only string
  static String _addThousandSeparator(String value, String separator) {
    if (value.length <= 3) return value;

    String result = '';
    int count = 0;

    for (int i = value.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        result = '$separator$result';
      }
      result = value[i] + result;
      count++;
    }

    return result;
  }
}
