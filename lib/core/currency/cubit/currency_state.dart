part of 'currency_cubit.dart';

class CurrencyState extends Equatable {
  final CurrencyCode currentCurrency;
  final bool isMigrating;
  final bool isLoadingRates;
  final DateTime? ratesLastUpdated;

  const CurrencyState({
    this.currentCurrency = CurrencyCode.idr,
    this.isMigrating = false,
    this.isLoadingRates = false,
    this.ratesLastUpdated,
  });

  /// Get current Currency object
  Currency get currency => Currency.getByCode(currentCurrency);

  CurrencyState copyWith({
    CurrencyCode? currentCurrency,
    bool? isMigrating,
    bool? isLoadingRates,
    DateTime? ratesLastUpdated,
  }) {
    return CurrencyState(
      currentCurrency: currentCurrency ?? this.currentCurrency,
      isMigrating: isMigrating ?? this.isMigrating,
      isLoadingRates: isLoadingRates ?? this.isLoadingRates,
      ratesLastUpdated: ratesLastUpdated ?? this.ratesLastUpdated,
    );
  }

  @override
  List<Object?> get props => [
    currentCurrency,
    isMigrating,
    isLoadingRates,
    ratesLastUpdated,
  ];
}
