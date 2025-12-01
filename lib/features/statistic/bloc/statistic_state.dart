part of 'statistic_bloc.dart';

/// * Status untuk statistic operations
enum StatisticStatus { initial, loading, success, failure }

/// * Tipe chart yang tersedia
enum StatisticChartType { pie, bar, line }

final class StatisticState extends Equatable {
  final StatisticStatus status;
  final StatisticSummary summary;
  final StatisticPeriod currentPeriod;
  final StatisticChartType chartType;
  final String? errorMessage;

  StatisticState({
    this.status = StatisticStatus.initial,
    StatisticSummary? summary,
    StatisticPeriod? currentPeriod,
    this.chartType = StatisticChartType.pie,
    this.errorMessage,
  }) : summary = summary ?? const StatisticSummary(),
       currentPeriod = currentPeriod ?? StatisticPeriod.monthly();

  /// * Computed properties
  bool get isLoading => status == StatisticStatus.loading;
  bool get hasData =>
      summary.incomeSummaries.isNotEmpty || summary.expenseSummaries.isNotEmpty;

  StatisticState copyWith({
    StatisticStatus? status,
    StatisticSummary? summary,
    StatisticPeriod? currentPeriod,
    StatisticChartType? chartType,
    String? Function()? errorMessage,
  }) {
    return StatisticState(
      status: status ?? this.status,
      summary: summary ?? this.summary,
      currentPeriod: currentPeriod ?? this.currentPeriod,
      chartType: chartType ?? this.chartType,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    summary,
    currentPeriod,
    chartType,
    errorMessage,
  ];
}
