import 'package:intl/intl.dart';

import 'package:ikuyo_finance/core/currency/models/currency.dart';

/// Utility class for currency conversion and formatting
class CurrencyConverter {
  CurrencyConverter._();

  /// Convert amount from one currency to another
  /// Uses USD as base currency for conversion
  static double convert({
    required double amount,
    required Currency from,
    required Currency to,
  }) {
    if (from.code == to.code) return amount;

    // * Convert to USD first, then to target currency
    final amountInUsd = amount / from.rateToUsd;
    final convertedAmount = amountInUsd * to.rateToUsd;

    return convertedAmount;
  }

  /// Convert amount from source currency to target currency code
  static double convertByCode({
    required double amount,
    required CurrencyCode from,
    required CurrencyCode to,
  }) {
    return convert(
      amount: amount,
      from: Currency.getByCode(from),
      to: Currency.getByCode(to),
    );
  }

  /// Get locale string for currency formatting
  static String _getLocale(CurrencyCode code) {
    return switch (code) {
      CurrencyCode.idr => 'id_ID',
      CurrencyCode.jpy => 'ja_JP',
      CurrencyCode.krw => 'ko_KR',
      CurrencyCode.cny => 'zh_CN',
      CurrencyCode.eur => 'de_DE',
      CurrencyCode.gbp => 'en_GB',
      CurrencyCode.aud => 'en_AU',
      CurrencyCode.sgd => 'en_SG',
      CurrencyCode.myr => 'ms_MY',
      _ => 'en_US',
    };
  }

  /// Format amount with currency symbol and locale-aware formatting
  /// * IDR: Rp 12.000,00 (uses . for thousands, , for decimals)
  /// * USD: $12,000.00 (uses , for thousands, . for decimals)
  static String format({
    required double amount,
    required Currency currency,
    bool showSymbol = true,
    bool compact = false,
  }) {
    final locale = _getLocale(currency.code);
    final symbol = showSymbol ? '${currency.symbol} ' : '';

    if (compact) {
      final formatter = NumberFormat.compact(locale: locale);
      return '$symbol${formatter.format(amount)}';
    }

    final formatter = NumberFormat.currency(
      locale: locale,
      symbol: '',
      decimalDigits: currency.decimalDigits,
    );

    return '$symbol${formatter.format(amount)}';
  }

  /// Format amount with currency code
  static String formatByCode({
    required double amount,
    required CurrencyCode code,
    bool showSymbol = true,
    bool compact = false,
  }) {
    return format(
      amount: amount,
      currency: Currency.getByCode(code),
      showSymbol: showSymbol,
      compact: compact,
    );
  }

  /// Convert and format in one step
  static String convertAndFormat({
    required double amount,
    required Currency from,
    required Currency to,
    bool showSymbol = true,
    bool compact = false,
  }) {
    final converted = convert(amount: amount, from: from, to: to);
    return format(
      amount: converted,
      currency: to,
      showSymbol: showSymbol,
      compact: compact,
    );
  }

  /// Convert and format using currency codes
  static String convertAndFormatByCode({
    required double amount,
    required CurrencyCode from,
    required CurrencyCode to,
    bool showSymbol = true,
    bool compact = false,
  }) {
    return convertAndFormat(
      amount: amount,
      from: Currency.getByCode(from),
      to: Currency.getByCode(to),
      showSymbol: showSymbol,
      compact: compact,
    );
  }
}

/// Extension for easy currency formatting on double values
extension CurrencyFormatExtension on double {
  /// Format this amount in the given currency
  String formatCurrency(Currency currency, {bool compact = false}) {
    return CurrencyConverter.format(
      amount: this,
      currency: currency,
      compact: compact,
    );
  }

  /// Convert this amount from one currency to another
  double convertTo(Currency from, Currency to) {
    return CurrencyConverter.convert(amount: this, from: from, to: to);
  }
}
