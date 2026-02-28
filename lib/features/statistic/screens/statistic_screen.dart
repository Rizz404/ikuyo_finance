import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/features/statistic/bloc/statistic_bloc.dart';
import 'package:ikuyo_finance/features/statistic/widgets/custom_period_dialog.dart';
import 'package:ikuyo_finance/features/statistic/widgets/statistic_content_view.dart';
import 'package:ikuyo_finance/features/statistic/widgets/statistic_period_navigator.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:ikuyo_finance/shared/widgets/screen_wrapper.dart';

class StatisticScreen extends StatefulWidget {
  const StatisticScreen({super.key});

  @override
  State<StatisticScreen> createState() => _StatisticScreenState();
}

class _StatisticScreenState extends State<StatisticScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // * Fetch initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StatisticBloc>().add(const StatisticFetched());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StatisticBloc, StatisticState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: StatisticPeriodNavigator(
              period: state.currentPeriod,
              onPrevious: () => context.read<StatisticBloc>().add(
                const StatisticPeriodChanged(isNext: false),
              ),
              onNext: () => context.read<StatisticBloc>().add(
                const StatisticPeriodChanged(isNext: true),
              ),
              onPeriodTypeChanged: (type) => context.read<StatisticBloc>().add(
                StatisticPeriodTypeChanged(type: type),
              ),
              onCustomPeriodTap: () => _showCustomPeriodPicker(context),
            ),
            bottom: TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: LocaleKeys.statisticScreenTabExpense.tr()),
                Tab(text: LocaleKeys.statisticScreenTabIncome.tr()),
              ],
            ),
          ),
          body: ScreenWrapper(child: _buildBody(context, state)),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, StatisticState state) {
    // * Handle loading state
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // * Handle error state
    if (state.status == StatisticStatus.failure) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: context.colorScheme.error,
            ),
            const SizedBox(height: 16),
            AppText(
              state.errorMessage ??
                  LocaleKeys.statisticScreenErrorOccurred.tr(),
              style: AppTextStyle.bodyMedium,
              color: context.colorScheme.error,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () =>
                  context.read<StatisticBloc>().add(const StatisticRefreshed()),
              icon: const Icon(Icons.refresh),
              label: Text(LocaleKeys.statisticScreenTryAgain.tr()),
            ),
          ],
        ),
      );
    }

    // * Success state - TabBarView
    return TabBarView(
      controller: _tabController,
      children: [
        // * Tab 1: Pengeluaran
        StatisticContentView(
          summaries: state.summary.expenseSummaries,
          total: state.summary.totalExpense,
          chartType: state.chartType,
          isIncome: false,
          onChartTypeChanged: (type) => context.read<StatisticBloc>().add(
            StatisticChartTypeChanged(chartType: type),
          ),
          onRefresh: () =>
              context.read<StatisticBloc>().add(const StatisticRefreshed()),
        ),
        // * Tab 2: Pendapatan
        StatisticContentView(
          summaries: state.summary.incomeSummaries,
          total: state.summary.totalIncome,
          chartType: state.chartType,
          isIncome: true,
          onChartTypeChanged: (type) => context.read<StatisticBloc>().add(
            StatisticChartTypeChanged(chartType: type),
          ),
          onRefresh: () =>
              context.read<StatisticBloc>().add(const StatisticRefreshed()),
        ),
      ],
    );
  }

  Future<void> _showCustomPeriodPicker(BuildContext context) async {
    final bloc = context.read<StatisticBloc>();
    final currentPeriod = bloc.state.currentPeriod;

    final result = await CustomPeriodDialog.show(
      context: context,
      initialStartDate: currentPeriod.startDate,
      initialEndDate: currentPeriod.endDate,
    );

    if (result != null && context.mounted) {
      bloc.add(
        StatisticCustomPeriodSet(startDate: result.$1, endDate: result.$2),
      );
    }
  }
}
