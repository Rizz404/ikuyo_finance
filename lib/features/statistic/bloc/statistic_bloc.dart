import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/features/statistic/models/category_summary.dart';
import 'package:ikuyo_finance/features/statistic/models/get_statistic_params.dart';
import 'package:ikuyo_finance/features/statistic/models/statistic_period.dart';
import 'package:ikuyo_finance/features/transaction/repositories/transaction_repository.dart';

part 'statistic_event.dart';
part 'statistic_state.dart';

class StatisticBloc extends Bloc<StatisticEvent, StatisticState> {
  StatisticBloc(this._transactionRepository) : super(StatisticState()) {
    on<StatisticFetched>(_onStatisticFetched);
    on<StatisticPeriodChanged>(_onPeriodChanged);
    on<StatisticPeriodTypeChanged>(_onPeriodTypeChanged);
    on<StatisticCustomPeriodSet>(_onCustomPeriodSet);
    on<StatisticRefreshed>(_onRefreshed);
    on<StatisticChartTypeChanged>(_onChartTypeChanged);
  }

  final TransactionRepository _transactionRepository;

  /// * Fetch statistic data
  Future<void> _onStatisticFetched(
    StatisticFetched event,
    Emitter<StatisticState> emit,
  ) async {
    emit(state.copyWith(status: StatisticStatus.loading));

    final period = event.period ?? state.currentPeriod;

    final result = await _transactionRepository
        .getStatisticSummary(
          GetStatisticParams(
            startDate: period.startDate,
            endDate: period.endDate,
          ),
        )
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: StatisticStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: StatisticStatus.success,
          summary: success.data,
          currentPeriod: period,
          errorMessage: () => null,
        ),
      ),
    );
  }

  /// * Navigate to previous/next period
  Future<void> _onPeriodChanged(
    StatisticPeriodChanged event,
    Emitter<StatisticState> emit,
  ) async {
    final newPeriod = event.isNext
        ? state.currentPeriod.next()
        : state.currentPeriod.previous();

    add(StatisticFetched(period: newPeriod));
  }

  /// * Change period type (weekly, monthly, yearly, custom)
  Future<void> _onPeriodTypeChanged(
    StatisticPeriodTypeChanged event,
    Emitter<StatisticState> emit,
  ) async {
    final newPeriod = state.currentPeriod.changeType(event.type);
    add(StatisticFetched(period: newPeriod));
  }

  /// * Set custom period
  Future<void> _onCustomPeriodSet(
    StatisticCustomPeriodSet event,
    Emitter<StatisticState> emit,
  ) async {
    final newPeriod = StatisticPeriod.custom(
      startDate: event.startDate,
      endDate: event.endDate,
    );
    add(StatisticFetched(period: newPeriod));
  }

  /// * Refresh current period
  Future<void> _onRefreshed(
    StatisticRefreshed event,
    Emitter<StatisticState> emit,
  ) async {
    add(StatisticFetched(period: state.currentPeriod));
  }

  /// * Change chart type
  void _onChartTypeChanged(
    StatisticChartTypeChanged event,
    Emitter<StatisticState> emit,
  ) {
    emit(state.copyWith(chartType: event.chartType));
  }
}
