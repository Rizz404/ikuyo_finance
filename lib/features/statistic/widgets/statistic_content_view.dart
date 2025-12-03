import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/currency/currency.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/features/statistic/bloc/statistic_bloc.dart';
import 'package:ikuyo_finance/features/statistic/models/category_summary.dart';
import 'package:ikuyo_finance/features/statistic/widgets/category_summary_list.dart';
import 'package:ikuyo_finance/features/statistic/widgets/statistic_chart_view.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';

/// * Widget utama untuk menampilkan konten statistik (chart + list)
class StatisticContentView extends StatelessWidget {
  final List<CategorySummary> summaries;
  final double total;
  final StatisticChartType chartType;
  final bool isIncome;
  final ValueChanged<StatisticChartType> onChartTypeChanged;
  final VoidCallback onRefresh;

  const StatisticContentView({
    super.key,
    required this.summaries,
    required this.total,
    required this.chartType,
    required this.isIncome,
    required this.onChartTypeChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: CustomScrollView(
        slivers: [
          // * Summary card
          SliverToBoxAdapter(child: _buildSummaryCard(context)),
          // * Chart section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: StatisticChartView(
                summaries: summaries,
                total: total,
                chartType: chartType,
                isIncome: isIncome,
                onChartTypeChanged: onChartTypeChanged,
              ),
            ),
          ),
          // * Category list
          SliverToBoxAdapter(
            child: CategorySummaryList(
              summaries: summaries,
              isIncome: isIncome,
            ),
          ),
          // * Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isIncome
              ? [
                  context.semantic.success,
                  context.semantic.success.withValues(alpha: 0.7),
                ]
              : [
                  context.semantic.error,
                  context.semantic.error.withValues(alpha: 0.7),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:
                (isIncome ? context.semantic.success : context.semantic.error)
                    .withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isIncome ? Icons.trending_up : Icons.trending_down,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 8),
              AppText(
                isIncome ? 'Total Pendapatan' : 'Total Pengeluaran',
                style: AppTextStyle.titleSmall,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppText(
            _formatCurrency(context, total),
            style: AppTextStyle.headlineMedium,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          const SizedBox(height: 8),
          AppText(
            '${summaries.length} kategori • ${_getTotalTransactionCount()} transaksi',
            style: AppTextStyle.bodySmall,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ],
      ),
    );
  }

  int _getTotalTransactionCount() {
    return summaries.fold<int>(0, (sum, s) => sum + s.transactionCount);
  }

  String _formatCurrency(BuildContext context, double amount) {
    return context.read<CurrencyCubit>().formatAmount(amount);
  }
}
