import 'package:equatable/equatable.dart';

/// Supported currencies in the app
enum CurrencyCode { usd, idr, eur, gbp, jpy, sgd, myr, aud, cny, krw }

/// Currency model with exchange rates relative to USD
class Currency extends Equatable {
  final CurrencyCode code;
  final String symbol;
  final String name;
  final double rateToUsd; // * How many of this currency = 1 USD
  final int decimalDigits;

  const Currency({
    required this.code,
    required this.symbol,
    required this.name,
    required this.rateToUsd,
    this.decimalDigits = 2,
  });

  @override
  List<Object?> get props => [code, symbol, name, rateToUsd, decimalDigits];

  /// All supported currencies with default exchange rates
  /// ! Exchange rates are static defaults, can be updated dynamically via API
  static const Map<CurrencyCode, Currency> currencies = {
    CurrencyCode.usd: Currency(
      code: CurrencyCode.usd,
      symbol: '\$',
      name: 'USD',
      rateToUsd: 1.0,
    ),
    CurrencyCode.idr: Currency(
      code: CurrencyCode.idr,
      symbol: 'Rp',
      name: 'IDR',
      rateToUsd: 16000.0, // * ~16k IDR = 1 USD
      decimalDigits: 0,
    ),
    CurrencyCode.eur: Currency(
      code: CurrencyCode.eur,
      symbol: '€',
      name: 'EUR',
      rateToUsd: 0.92,
    ),
    CurrencyCode.gbp: Currency(
      code: CurrencyCode.gbp,
      symbol: '£',
      name: 'GBP',
      rateToUsd: 0.79,
    ),
    CurrencyCode.jpy: Currency(
      code: CurrencyCode.jpy,
      symbol: '¥',
      name: 'JPY',
      rateToUsd: 149.0,
      decimalDigits: 0,
    ),
    CurrencyCode.sgd: Currency(
      code: CurrencyCode.sgd,
      symbol: 'S\$',
      name: 'SGD',
      rateToUsd: 1.34,
    ),
    CurrencyCode.myr: Currency(
      code: CurrencyCode.myr,
      symbol: 'RM',
      name: 'MYR',
      rateToUsd: 4.47,
    ),
    CurrencyCode.aud: Currency(
      code: CurrencyCode.aud,
      symbol: 'A\$',
      name: 'AUD',
      rateToUsd: 1.54,
    ),
    CurrencyCode.cny: Currency(
      code: CurrencyCode.cny,
      symbol: '¥',
      name: 'CNY',
      rateToUsd: 7.24,
    ),
    CurrencyCode.krw: Currency(
      code: CurrencyCode.krw,
      symbol: '₩',
      name: 'KRW',
      rateToUsd: 1320.0,
      decimalDigits: 0,
    ),
  };

  /// Get currency by code
  static Currency getByCode(CurrencyCode code) =>
      currencies[code] ?? currencies[CurrencyCode.usd]!;

  /// Get currency by name string
  static Currency? getByName(String name) {
    try {
      final code = CurrencyCode.values.firstWhere(
        (c) => c.name.toLowerCase() == name.toLowerCase(),
      );
      return currencies[code];
    } catch (_) {
      return null;
    }
  }
}
