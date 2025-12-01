part of 'statistic_bloc.dart';

sealed class StatisticEvent {
  const StatisticEvent();
}

/// * Fetch statistic data for a period
final class StatisticFetched extends StatisticEvent {
  const StatisticFetched({this.period});

  final StatisticPeriod? period;
}

/// * Navigate to previous/next period
final class StatisticPeriodChanged extends StatisticEvent {
  const StatisticPeriodChanged({required this.isNext});

  final bool isNext;
}

/// * Change period type (weekly, monthly, yearly, custom)
final class StatisticPeriodTypeChanged extends StatisticEvent {
  const StatisticPeriodTypeChanged({required this.type});

  final StatisticPeriodType type;
}

/// * Set custom date range
final class StatisticCustomPeriodSet extends StatisticEvent {
  const StatisticCustomPeriodSet({
    required this.startDate,
    required this.endDate,
  });

  final DateTime startDate;
  final DateTime endDate;
}

/// * Refresh current statistic
final class StatisticRefreshed extends StatisticEvent {
  const StatisticRefreshed();
}

/// * Change chart type
final class StatisticChartTypeChanged extends StatisticEvent {
  const StatisticChartTypeChanged({required this.chartType});

  final StatisticChartType chartType;
}
