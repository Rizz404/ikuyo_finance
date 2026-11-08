import 'package:ikuyo_finance/core/currency/models/currency.dart';

/// Parse & format nominal yang diketik user di field currency.
/// ! Satu sumber kebenaran untuk formatter, parser, dan validator agar
/// ! separator ribuan/desimal tiap mata uang selalu konsisten (A08).
class CurrencyInput {
  CurrencyInput._();

  /// Mata uang default app (sama dengan default [CurrencyState])
  static Currency get defaultCurrency => Currency.getByCode(CurrencyCode.idr);

  /// Parse teks tampilan (mis. USD "1,234.56", EUR "1.234,56",
  /// IDR "1.000.000") menjadi angka. Null jika tidak valid.
  static double? parse(String? text, Currency currency) {
    if (text == null) return null;
    var value = text.trim();
    if (value.isEmpty) return null;

    value = value.replaceAll(currency.thousandSeparator, '');
    if (currency.decimalSeparator != '.') {
      value = value.replaceAll(currency.decimalSeparator, '.');
    }
    final parsed = double.tryParse(value);
    if (parsed == null || !parsed.isFinite) return null;
    return parsed;
  }

  /// Format angka menjadi teks input (tanpa simbol) sesuai separator
  /// mata uang, dengan bagian desimal dipertahankan.
  static String formatAmount(double amount, Currency currency) {
    final fixed = amount.abs().toStringAsFixed(currency.decimalDigits);
    final parts = fixed.split('.');
    final intPart = groupThousands(parts[0], currency.thousandSeparator);
    final sign = amount < 0 ? '-' : '';
    if (parts.length < 2) return '$sign$intPart';
    return '$sign$intPart${currency.decimalSeparator}${parts[1]}';
  }

  /// Sisipkan separator ribuan pada string digit
  static String groupThousands(String digits, String separator) {
    if (digits.length <= 3) return digits;
    final buffer = StringBuffer();
    final offset = digits.length % 3;
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (i - offset) % 3 == 0) buffer.write(separator);
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
