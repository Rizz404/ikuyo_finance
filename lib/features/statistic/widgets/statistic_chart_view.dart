import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/features/statistic/bloc/statistic_bloc.dart';
import 'package:ikuyo_finance/features/statistic/models/category_summary.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:intl/intl.dart';

/// * Widget untuk menampilkan chart statistik
class StatisticChartView extends StatefulWidget {
  final List<CategorySummary> summaries;
  final double total;
  final StatisticChartType chartType;
  final bool isIncome;
  final ValueChanged<StatisticChartType> onChartTypeChanged;

  const StatisticChartView({
    super.key,
    required this.summaries,
    required this.total,
    required this.chartType,
    required this.isIncome,
    required this.onChartTypeChanged,
  });

  @override
  State<StatisticChartView> createState() => _StatisticChartViewState();
}

class _StatisticChartViewState extends State<StatisticChartView> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.summaries.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      children: [
        // * Chart type selector
        _buildChartTypeSelector(context),
        const SizedBox(height: 16),
        // * Total display
        _buildTotalDisplay(context),
        const SizedBox(height: 24),
        // * Chart
        SizedBox(height: 220, child: _buildChart(context)),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.isIncome
                ? Icons.trending_up_outlined
                : Icons.trending_down_outlined,
            size: 64,
            color: context.colorScheme.outline.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          AppText(
            widget.isIncome ? 'Belum ada pendapatan' : 'Belum ada pengeluaran',
            style: AppTextStyle.bodyLarge,
            color: context.colorScheme.outline,
          ),
          const SizedBox(height: 8),
          AppText(
            'Transaksi akan muncul di sini',
            style: AppTextStyle.bodySmall,
            color: context.colorScheme.outline.withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }

  Widget _buildChartTypeSelector(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: StatisticChartType.values.map((type) {
        final isSelected = widget.chartType == type;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ChoiceChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getChartIcon(type),
                  size: 16,
                  color: isSelected
                      ? context.colorScheme.onPrimaryContainer
                      : context.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(_getChartLabel(type)),
              ],
            ),
            selected: isSelected,
            onSelected: (_) => widget.onChartTypeChanged(type),
            visualDensity: VisualDensity.compact,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTotalDisplay(BuildContext context) {
    final color = widget.isIncome
        ? context.semantic.success
        : context.semantic.error;

    return Column(
      children: [
        AppText(
          widget.isIncome ? 'Total Pendapatan' : 'Total Pengeluaran',
          style: AppTextStyle.bodyMedium,
          color: context.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 4),
        AppText(
          _formatCurrency(widget.total),
          style: AppTextStyle.headlineMedium,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ],
    );
  }

  Widget _buildChart(BuildContext context) {
    switch (widget.chartType) {
      case StatisticChartType.pie:
        return _buildPieChart(context);
      case StatisticChartType.bar:
        return _buildBarChart(context);
      case StatisticChartType.line:
        return _buildLineChart(context);
    }
  }

  Widget _buildPieChart(BuildContext context) {
    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {
            setState(() {
              if (!event.isInterestedForInteractions ||
                  pieTouchResponse == null ||
                  pieTouchResponse.touchedSection == null) {
                _touchedIndex = -1;
                return;
              }
              _touchedIndex =
                  pieTouchResponse.touchedSection!.touchedSectionIndex;
            });
          },
        ),
        borderData: FlBorderData(show: false),
        sectionsSpace: 2,
        centerSpaceRadius: 50,
        sections: _buildPieSections(context),
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  List<PieChartSectionData> _buildPieSections(BuildContext context) {
    return widget.summaries.asMap().entries.map((entry) {
      final index = entry.key;
      final summary = entry.value;
      final isTouched = index == _touchedIndex;
      final radius = isTouched ? 60.0 : 50.0;
      final fontSize = isTouched ? 14.0 : 12.0;

      return PieChartSectionData(
        color: _getCategoryColor(index, summary),
        value: summary.totalAmount,
        title: '${summary.percentage.toStringAsFixed(1)}%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [Shadow(color: Colors.black26, blurRadius: 2)],
        ),
        badgeWidget: isTouched ? _buildBadge(context, summary) : null,
        badgePositionPercentageOffset: 1.3,
      );
    }).toList();
  }

  Widget _buildBadge(BuildContext context, CategorySummary summary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: context.colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 4,
          ),
        ],
      ),
      child: AppText(
        summary.categoryName,
        style: AppTextStyle.labelSmall,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildBarChart(BuildContext context) {
    final maxY = widget.summaries.isEmpty
        ? 100.0
        : widget.summaries
                  .map((s) => s.totalAmount)
                  .reduce((a, b) => a > b ? a : b) *
              1.2;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => context.colorScheme.inverseSurface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final summary = widget.summaries[groupIndex];
              return BarTooltipItem(
                '${summary.categoryName}\n${_formatCurrency(summary.totalAmount)}',
                TextStyle(
                  color: context.colorScheme.onInverseSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= widget.summaries.length) return const SizedBox();
                final summary = widget.summaries[index];
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: AppText(
                    summary.categoryName.length > 6
                        ? '${summary.categoryName.substring(0, 5)}...'
                        : summary.categoryName,
                    style: AppTextStyle.labelSmall,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                );
              },
              reservedSize: 32,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return AppText(
                  _formatShortAmount(value),
                  style: AppTextStyle.labelSmall,
                  color: context.colorScheme.onSurfaceVariant,
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: widget.summaries.asMap().entries.map((entry) {
          final index = entry.key;
          final summary = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: summary.totalAmount,
                color: _getCategoryColor(index, summary),
                width: 20,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
              ),
            ],
          );
        }).toList(),
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildLineChart(BuildContext context) {
    if (widget.summaries.isEmpty) return const SizedBox();

    final maxY =
        widget.summaries
            .map((s) => s.totalAmount)
            .reduce((a, b) => a > b ? a : b) *
        1.2;
    final color = widget.isIncome
        ? context.semantic.success
        : context.semantic.error;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= widget.summaries.length || index < 0) {
                  return const SizedBox();
                }
                final summary = widget.summaries[index];
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: AppText(
                    summary.categoryName.length > 4
                        ? '${summary.categoryName.substring(0, 3)}...'
                        : summary.categoryName,
                    style: AppTextStyle.labelSmall,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                );
              },
              reservedSize: 32,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return AppText(
                  _formatShortAmount(value),
                  style: AppTextStyle.labelSmall,
                  color: context.colorScheme.onSurfaceVariant,
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (widget.summaries.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => context.colorScheme.inverseSurface,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                if (index >= widget.summaries.length) return null;
                final summary = widget.summaries[index];
                return LineTooltipItem(
                  '${summary.categoryName}\n${_formatCurrency(summary.totalAmount)}',
                  TextStyle(
                    color: context.colorScheme.onInverseSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: widget.summaries.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble(), entry.value.totalAmount);
            }).toList(),
            isCurved: true,
            color: color,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: color,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.3),
                  color.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Color _getCategoryColor(int index, CategorySummary summary) {
    // * Try to use category color first
    if (summary.categoryColor != null) {
      try {
        return Color(
          int.parse(summary.categoryColor!.replaceFirst('#', '0xFF')),
        );
      } catch (_) {}
    }

    // * Fallback to predefined colors
    final colors = widget.isIncome
        ? [
            Colors.green,
            Colors.teal,
            Colors.cyan,
            Colors.lightGreen,
            Colors.lime,
            Colors.greenAccent,
          ]
        : [
            Colors.red,
            Colors.orange,
            Colors.deepOrange,
            Colors.pink,
            Colors.purple,
            Colors.redAccent,
          ];

    return colors[index % colors.length];
  }

  IconData _getChartIcon(StatisticChartType type) {
    switch (type) {
      case StatisticChartType.pie:
        return Icons.pie_chart;
      case StatisticChartType.bar:
        return Icons.bar_chart;
      case StatisticChartType.line:
        return Icons.show_chart;
    }
  }

  String _getChartLabel(StatisticChartType type) {
    switch (type) {
      case StatisticChartType.pie:
        return 'Pie';
      case StatisticChartType.bar:
        return 'Bar';
      case StatisticChartType.line:
        return 'Line';
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    ).format(amount);
  }

  String _formatShortAmount(double amount) {
    if (amount >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}jt';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}rb';
    }
    return amount.toStringAsFixed(0);
  }
}
