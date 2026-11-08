import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ikuyo_finance/core/currency/models/currency.dart';
import 'package:ikuyo_finance/core/currency/service/currency_migration_service.dart';
import 'package:ikuyo_finance/core/currency/service/exchange_rate_service.dart';
import 'package:ikuyo_finance/core/currency/utils/currency_converter.dart';
import 'package:ikuyo_finance/core/storage/storage_keys.dart';
import 'package:ikuyo_finance/core/extensions/logger_extension.dart';

part 'currency_state.dart';

class CurrencyCubit extends Cubit<CurrencyState> {
  final SharedPreferences _prefs;
  final CurrencyMigrationService _migrationService;
  final ExchangeRateService _exchangeRateService;

  CurrencyCubit(this._prefs, this._migrationService, this._exchangeRateService)
    : super(
        CurrencyState(
          currentCurrency: _loadCurrency(_prefs, _migrationService),
        ),
      ) {
    logInfo('CurrencyCubit initialized with ${state.currentCurrency}');
    _syncPreference(state.currentCurrency);
    // * Fetch live exchange rates on init
    refreshExchangeRates();
  }

  static CurrencyCode _loadCurrency(
    SharedPreferences prefs,
    CurrencyMigrationService migrationService,
  ) {
    final currencyName = prefs.getString(StorageKeys.currency);
    final preferred = CurrencyCode.values.firstWhere(
      (c) => c.name == currencyName,
      orElse: () => CurrencyCode.idr,
    );
    // * Penanda DB adalah sumber kebenaran; prefs hanya cermin
    try {
      return migrationService.resolveStoredCurrency(preferred);
    } catch (e, s) {
      talker.error('[CurrencyCubit] Failed to read currency marker', e, s);
      return preferred;
    }
  }

  /// Selaraskan prefs dengan penanda DB; kegagalan tidak fatal karena
  /// penanda tetap menjadi sumber kebenaran pada startup berikutnya.
  Future<bool> _syncPreference(CurrencyCode code) async {
    try {
      if (_prefs.getString(StorageKeys.currency) == code.name) return true;
      await _prefs.setString(StorageKeys.currency, code.name);
      return true;
    } catch (e, s) {
      logError('Failed to persist currency preference', e, s);
      return false;
    }
  }

  /// Change currency and migrate all database values
  /// * This will convert all amounts in database from old to new currency
  Future<CurrencyMigrationResult> setCurrency(
    CurrencyCode code, {
    void Function(String status, double progress)? onProgress,
  }) async {
    if (code == state.currentCurrency) {
      return const CurrencyMigrationResult();
    }

    final oldCurrency = state.currentCurrency;

    try {
      // * Set migrating state
      emit(state.copyWith(isMigrating: true));

      // * Migrate all data in database
      final result = await _migrationService.migrateAllData(
        fromCurrency: oldCurrency,
        toCurrency: code,
        onProgress: onProgress,
      );

      if (!result.success) {
        if (!isClosed) emit(state.copyWith(isMigrating: false));
        return result;
      }

      // * Konversi + penanda sudah commit; prefs hanya cermin
      await _syncPreference(code);
      if (isClosed) return result;
      emit(state.copyWith(currentCurrency: code, isMigrating: false));
      logInfo('Currency migrated to ${code.name}');

      return result;
    } catch (e, s) {
      logError('Failed to migrate currency', e, s);
      if (!isClosed) emit(state.copyWith(isMigrating: false));
      return CurrencyMigrationResult.failure(e.toString());
    }
  }

  /// Quick currency switch without migration (for display-only)
  Future<void> setDisplayCurrency(CurrencyCode code) async {
    try {
      // * Nominal tidak dikonversi: DB kini dianggap dalam mata uang [code]
      _migrationService.markStoredCurrency(code);
      await _syncPreference(code);
      if (isClosed) return;
      emit(state.copyWith(currentCurrency: code));
      logInfo('Display currency changed to ${code.name}');
    } catch (e, s) {
      logError('Failed to change display currency', e, s);
    }
  }

  /// Get record counts that will be affected by migration
  Future<Map<String, int>> getRecordCounts() {
    return _migrationService.getRecordCounts();
  }

  /// Format amount in current currency (no conversion needed now)
  String formatAmount(double amount, {bool compact = false}) {
    return CurrencyConverter.format(
      amount: amount,
      currency: state.currency,
      compact: compact,
    );
  }

  /// Get current currency symbol
  String get symbol => state.currency.symbol;

  /// Get all available currencies
  List<Currency> get availableCurrencies => Currency.currencies.values.toList();

  /// Fetch live exchange rates from API and update Currency model
  Future<void> refreshExchangeRates() async {
    try {
      emit(state.copyWith(isLoadingRates: true));
      final rates = await _exchangeRateService.fetchRates();
      Currency.updateRates(rates);
      if (isClosed) return;
      emit(
        state.copyWith(isLoadingRates: false, ratesLastUpdated: DateTime.now()),
      );
      logInfo('Exchange rates refreshed successfully');
    } catch (e, s) {
      logError('Failed to refresh exchange rates', e, s);
      if (isClosed) return;
      emit(state.copyWith(isLoadingRates: false));
    }
  }
}
