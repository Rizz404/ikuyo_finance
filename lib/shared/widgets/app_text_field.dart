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
  currency, // * Dynamic currency based on user selection
  priceJP,
  priceUS,
  url,
  multiline,
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
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final isPassword = widget.type == AppTextFieldType.password;
    final isMultiline =
        widget.type == AppTextFieldType.multiline ||
        (widget.maxLines != null && widget.maxLines! > 1);

    // Menentukan keyboard type berdasarkan enum
    TextInputType getKeyboardType() {
      switch (widget.type) {
        case AppTextFieldType.email:
          return TextInputType.emailAddress;
        case AppTextFieldType.phone:
          return TextInputType.phone;
        case AppTextFieldType.number:
        case AppTextFieldType.currency:
        case AppTextFieldType.priceJP:
        case AppTextFieldType.priceUS:
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
        case AppTextFieldType.priceJP:
        case AppTextFieldType.priceUS:
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
          return [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            _CurrencyFormatter(context),
          ];
        case AppTextFieldType.priceJP:
          return [FilteringTextInputFormatter.digitsOnly, _JPPriceFormatter()];
        case AppTextFieldType.priceUS:
          return [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            _USPriceFormatter(),
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
          // * Get dynamic currency symbol from CurrencyCubit
          final currencyState = context.watch<CurrencyCubit>().state;
          return currencyState.currency.symbol;
        case AppTextFieldType.priceJP:
          return '¥';
        case AppTextFieldType.priceUS:
          return '\$';
        default:
          return null;
      }
    }

    return FormBuilderTextField(
      name: widget.name,
      initialValue: widget.initialValue,
      maxLines: isPassword ? 1 : (widget.maxLines ?? (isMultiline ? 5 : 1)),
      obscureText: isPassword ? _obscureText : false,
      keyboardType: getKeyboardType(),
      textCapitalization: getTextCapitalization(),
      inputFormatters: getInputFormatters(),
      readOnly: widget.readOnly,
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
    );
  }
}

// Custom formatter untuk harga Jepang (format: 1,000,000)
class _JPPriceFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Remove existing commas
    String digitsOnly = newValue.text.replaceAll(',', '');

    // Add commas for thousands
    String formatted = _addCommas(digitsOnly);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _addCommas(String value) {
    if (value.length <= 3) return value;

    String result = '';
    int count = 0;

    for (int i = value.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        result = ',$result';
      }
      result = value[i] + result;
      count++;
    }

    return result;
  }
}

// Custom formatter untuk harga US (format: 1,000.00)
class _USPriceFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Allow only digits, comma, and one decimal point
    String filtered = newValue.text.replaceAll(RegExp(r'[^0-9.,]'), '');

    // Ensure only one decimal point
    List<String> parts = filtered.split('.');
    if (parts.length > 2) {
      filtered = '${parts[0]}.${parts.sublist(1).join('')}';
    }

    // Limit decimal places to 2
    if (parts.length == 2 && parts[1].length > 2) {
      filtered = '${parts[0]}.${parts[1].substring(0, 2)}';
    }

    // Format the integer part with commas
    if (parts.isNotEmpty) {
      String integerPart = parts[0].replaceAll(',', '');
      String formattedInteger = _addCommas(integerPart);

      if (parts.length > 1) {
        filtered = '$formattedInteger.${parts[1]}';
      } else if (filtered.endsWith('.')) {
        filtered = '$formattedInteger.';
      } else {
        filtered = formattedInteger;
      }
    }

    return TextEditingValue(
      text: filtered,
      selection: TextSelection.collapsed(offset: filtered.length),
    );
  }

  String _addCommas(String value) {
    if (value.length <= 3) return value;

    String result = '';
    int count = 0;

    for (int i = value.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        result = ',$result';
      }
      result = value[i] + result;
      count++;
    }

    return result;
  }
}

/// Dynamic currency formatter based on selected currency
/// * IDR: 12.000 (uses . for thousands, no decimals)
/// * USD: 12,000.00 (uses , for thousands, . for decimals)
class _CurrencyFormatter extends TextInputFormatter {
  final BuildContext context;

  _CurrencyFormatter(this.context);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final currencyState = context.read<CurrencyCubit>().state;
    final currency = currencyState.currency;

    // * For currencies with no decimals (IDR, JPY, KRW)
    if (currency.decimalDigits == 0) {
      return _formatNoDecimals(newValue, currency.code);
    }

    // * For currencies with decimals (USD, EUR, etc.)
    return _formatWithDecimals(newValue, currency.code);
  }

  TextEditingValue _formatNoDecimals(
    TextEditingValue newValue,
    CurrencyCode code,
  ) {
    // Remove all non-digits
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return newValue.copyWith(text: '');

    // * IDR, MYR uses . for thousands (12.000)
    // * JPY, KRW uses , for thousands (12,000)
    final separator = (code == CurrencyCode.idr || code == CurrencyCode.myr)
        ? '.'
        : ',';

    String formatted = _addSeparators(digitsOnly, separator);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  TextEditingValue _formatWithDecimals(
    TextEditingValue newValue,
    CurrencyCode code,
  ) {
    // * IDR format: 12.000,00 (. for thousands, , for decimals)
    // * USD format: 12,000.00 (, for thousands, . for decimals)
    final isIdFormat = code == CurrencyCode.idr || code == CurrencyCode.myr;
    final thousandsSep = isIdFormat ? '.' : ',';
    final decimalSep = isIdFormat ? ',' : '.';

    // Allow only digits and decimal separator
    String filtered = newValue.text.replaceAll(RegExp('[^0-9$decimalSep]'), '');

    // Ensure only one decimal separator
    List<String> parts = filtered.split(decimalSep);
    if (parts.length > 2) {
      filtered = '${parts[0]}$decimalSep${parts.sublist(1).join('')}';
      parts = [parts[0], parts.sublist(1).join('')];
    }

    // Limit decimal places to 2
    if (parts.length == 2 && parts[1].length > 2) {
      filtered = '${parts[0]}$decimalSep${parts[1].substring(0, 2)}';
      parts = [parts[0], parts[1].substring(0, 2)];
    }

    // Format integer part with thousands separator
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      String integerPart = parts[0].replaceAll(thousandsSep, '');
      String formattedInteger = _addSeparators(integerPart, thousandsSep);

      if (parts.length > 1) {
        filtered = '$formattedInteger$decimalSep${parts[1]}';
      } else if (filtered.endsWith(decimalSep)) {
        filtered = '$formattedInteger$decimalSep';
      } else {
        filtered = formattedInteger;
      }
    }

    return TextEditingValue(
      text: filtered,
      selection: TextSelection.collapsed(offset: filtered.length),
    );
  }

  String _addSeparators(String value, String separator) {
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
