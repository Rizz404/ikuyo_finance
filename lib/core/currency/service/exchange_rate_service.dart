import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ikuyo_finance/core/currency/models/currency.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';

/// Service to fetch real-time exchange rates from API
/// Uses https://open.er-api.com (free, no API key required)
class ExchangeRateService {
  final Dio _dio;
  final SharedPreferences _prefs;

  static const _baseUrl = 'https://open.er-api.com/v6/latest/USD';
  static const _cacheKey = 'cached_exchange_rates';
  static const _cacheTimestampKey = 'exchange_rates_timestamp';

  // * Cache valid for 12 hours
  static const _cacheDuration = Duration(hours: 12);

  ExchangeRateService(this._prefs)
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

  /// Fetch latest exchange rates from API
  /// Returns map of CurrencyCode -> rate to USD
  /// Falls back to cached data if API fails
  Future<Map<CurrencyCode, double>> fetchRates() async {
    // * Check cache first
    final cached = _getCachedRates();
    if (cached != null) {
      talker.info('[ExchangeRateService] Using cached exchange rates');
      return cached;
    }

    try {
      talker.info('[ExchangeRateService] Fetching exchange rates from API...');
      final response = await _dio.get(_baseUrl);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final rates = _parseRates(data);

        // * Cache the rates
        await _cacheRates(rates);
        talker.info(
          '[ExchangeRateService] Exchange rates updated successfully',
        );

        return rates;
      }

      throw Exception('API returned status ${response.statusCode}');
    } catch (e, s) {
      talker.error('[ExchangeRateService] Failed to fetch rates', e, s);

      // * Try stale cache as fallback
      final staleCache = _getCachedRates(ignoreExpiry: true);
      if (staleCache != null) {
        talker.info('[ExchangeRateService] Using stale cached rates');
        return staleCache;
      }

      // * Return default rates as last resort
      return _defaultRates();
    }
  }

  /// Parse API response into CurrencyCode -> rate map
  Map<CurrencyCode, double> _parseRates(Map<String, dynamic> data) {
    final apiRates = data['rates'] as Map<String, dynamic>;
    final rates = <CurrencyCode, double>{};

    for (final code in CurrencyCode.values) {
      final key = code.name.toUpperCase();
      if (apiRates.containsKey(key)) {
        rates[code] = (apiRates[key] as num).toDouble();
      }
    }

    return rates;
  }

  /// Get cached rates if still valid
  Map<CurrencyCode, double>? _getCachedRates({bool ignoreExpiry = false}) {
    final cachedJson = _prefs.getString(_cacheKey);
    final timestamp = _prefs.getInt(_cacheTimestampKey);

    if (cachedJson == null || timestamp == null) return null;

    if (!ignoreExpiry) {
      final cachedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(cachedTime) > _cacheDuration) return null;
    }

    try {
      final map = jsonDecode(cachedJson) as Map<String, dynamic>;
      final rates = <CurrencyCode, double>{};

      for (final entry in map.entries) {
        final code = CurrencyCode.values.firstWhere(
          (c) => c.name == entry.key,
          orElse: () => CurrencyCode.usd,
        );
        rates[code] = (entry.value as num).toDouble();
      }

      return rates;
    } catch (_) {
      return null;
    }
  }

  /// Cache rates to SharedPreferences
  Future<void> _cacheRates(Map<CurrencyCode, double> rates) async {
    final map = <String, double>{};
    for (final entry in rates.entries) {
      map[entry.key.name] = entry.value;
    }

    await _prefs.setString(_cacheKey, jsonEncode(map));
    await _prefs.setInt(
      _cacheTimestampKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Default fallback rates (approximate)
  Map<CurrencyCode, double> _defaultRates() {
    return {
      CurrencyCode.usd: 1.0,
      CurrencyCode.idr: 16800.0,
      CurrencyCode.eur: 0.85,
      CurrencyCode.gbp: 0.74,
      CurrencyCode.jpy: 156.0,
      CurrencyCode.sgd: 1.26,
      CurrencyCode.myr: 3.89,
      CurrencyCode.aud: 1.41,
      CurrencyCode.cny: 6.87,
      CurrencyCode.krw: 1440.0,
    };
  }
}
