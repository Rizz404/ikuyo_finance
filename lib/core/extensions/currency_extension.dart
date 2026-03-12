import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/currency/cubit/currency_cubit.dart';
import 'package:ikuyo_finance/core/currency/models/currency.dart';
import 'package:ikuyo_finance/core/currency/utils/currency_converter.dart';

/// Extension for easy currency access from BuildContext
extension CurrencyContextExtension on BuildContext {
  /// Get CurrencyCubit instance
  CurrencyCubit get currencyCubit => read<CurrencyCubit>();

  /// Watch CurrencyState for reactive updates
  CurrencyState get currencyState => watch<CurrencyCubit>().state;

  /// Get current display currency
  Currency get currentCurrency => currencyState.currency;

  /// Get current currency symbol
  String get currencySymbol => currentCurrency.symbol;

  /// Format amount in current currency
  /// * Values in DB are already in current currency (migrated on currency change)
  String formatMoney(double amount, {bool compact = false}) {
    return read<CurrencyCubit>().formatAmount(amount, compact: compact);
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
