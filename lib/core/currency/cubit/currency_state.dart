part of 'currency_cubit.dart';

class CurrencyState extends Equatable {
  final CurrencyCode currentCurrency;
  final bool isMigrating;

  const CurrencyState({
    this.currentCurrency = CurrencyCode.idr,
    this.isMigrating = false,
  });

  /// Get current Currency object
  Currency get currency => Currency.getByCode(currentCurrency);

  CurrencyState copyWith({CurrencyCode? currentCurrency, bool? isMigrating}) {
    return CurrencyState(
      currentCurrency: currentCurrency ?? this.currentCurrency,
      isMigrating: isMigrating ?? this.isMigrating,
    );
  }

  @override
  List<Object?> get props => [currentCurrency, isMigrating];
}
