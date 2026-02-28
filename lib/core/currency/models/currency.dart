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
  final String thousandSeparator;
  final String decimalSeparator;

  const Currency({
    required this.code,
    required this.symbol,
    required this.name,
    required this.rateToUsd,
    this.decimalDigits = 2,
    this.thousandSeparator = ',',
    this.decimalSeparator = '.',
  });

  /// Create a copy with updated rate
  Currency copyWithRate(double newRate) => Currency(
    code: code,
    symbol: symbol,
    name: name,
    rateToUsd: newRate,
    decimalDigits: decimalDigits,
    thousandSeparator: thousandSeparator,
    decimalSeparator: decimalSeparator,
  );

  @override
  List<Object?> get props => [
    code,
    symbol,
    name,
    rateToUsd,
    decimalDigits,
    thousandSeparator,
    decimalSeparator,
  ];

  /// All supported currencies with default exchange rates
  /// ! Exchange rates are static defaults, updated dynamically via ExchangeRateService
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
      rateToUsd: 16800.0,
      decimalDigits: 0,
      thousandSeparator: '.',
      decimalSeparator: ',',
    ),
    CurrencyCode.eur: Currency(
      code: CurrencyCode.eur,
      symbol: '€',
      name: 'EUR',
      rateToUsd: 0.85,
      thousandSeparator: '.',
      decimalSeparator: ',',
    ),
    CurrencyCode.gbp: Currency(
      code: CurrencyCode.gbp,
      symbol: '£',
      name: 'GBP',
      rateToUsd: 0.74,
    ),
    CurrencyCode.jpy: Currency(
      code: CurrencyCode.jpy,
      symbol: '¥',
      name: 'JPY',
      rateToUsd: 156.0,
      decimalDigits: 0,
    ),
    CurrencyCode.sgd: Currency(
      code: CurrencyCode.sgd,
      symbol: 'S\$',
      name: 'SGD',
      rateToUsd: 1.26,
    ),
    CurrencyCode.myr: Currency(
      code: CurrencyCode.myr,
      symbol: 'RM',
      name: 'MYR',
      rateToUsd: 3.89,
    ),
    CurrencyCode.aud: Currency(
      code: CurrencyCode.aud,
      symbol: 'A\$',
      name: 'AUD',
      rateToUsd: 1.41,
    ),
    CurrencyCode.cny: Currency(
      code: CurrencyCode.cny,
      symbol: '¥',
      name: 'CNY',
      rateToUsd: 6.87,
    ),
    CurrencyCode.krw: Currency(
      code: CurrencyCode.krw,
      symbol: '₩',
      name: 'KRW',
      rateToUsd: 1440.0,
      decimalDigits: 0,
    ),
  };

  /// Get currency by code (uses live rates if available)
  static Currency getByCode(CurrencyCode code) =>
      _liveRates[code] ?? currencies[code] ?? currencies[CurrencyCode.usd]!;

  /// Live rates storage (updated by ExchangeRateService)
  static final Map<CurrencyCode, Currency> _liveRates = {};

  /// Update live rates from API data
  static void updateRates(Map<CurrencyCode, double> rates) {
    for (final entry in rates.entries) {
      final base = currencies[entry.key];
      if (base != null) {
        _liveRates[entry.key] = base.copyWithRate(entry.value);
      }
    }
  }

  /// Get currency by name string
  static Currency? getByName(String name) {
    try {
      final code = CurrencyCode.values.firstWhere(
        (c) => c.name.toLowerCase() == name.toLowerCase(),
      );
      return getByCode(code);
    } catch (_) {
      return null;
    }
  }
}
