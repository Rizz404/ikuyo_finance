import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:ikuyo_finance/core/extensions/currency_extension.dart';
import 'package:ikuyo_finance/core/extensions/theme_extension.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';

class AssetStatisticView extends StatefulWidget {
  final List<Asset> assets;

  const AssetStatisticView({super.key, required this.assets});

  @override
  State<AssetStatisticView> createState() => _AssetStatisticViewState();
}

class _AssetStatisticViewState extends State<AssetStatisticView> {
  int _touchedIndex = -1;

  Color _colorForType(AssetType type) {
    switch (type) {
      case AssetType.cash:
        return Colors.green;
      case AssetType.bank:
        return Colors.blue;
      case AssetType.eWallet:
        return Colors.orange;
      case AssetType.stock:
        return Colors.purple;
      case AssetType.crypto:
        return Colors.amber;
    }
  }

  String _nameForType(AssetType type) {
    switch (type) {
      case AssetType.cash:
        return LocaleKeys.assetTypesCash.tr();
      case AssetType.bank:
        return LocaleKeys.assetTypesBank.tr();
      case AssetType.eWallet:
        return LocaleKeys.assetTypesEWallet.tr();
      case AssetType.stock:
        return LocaleKeys.assetTypesStock.tr();
      case AssetType.crypto:
        return LocaleKeys.assetTypesCrypto.tr();
    }
  }

  Map<AssetType, double> _groupByType() {
    final map = <AssetType, double>{};
    for (final asset in widget.assets) {
      map[asset.assetType] = (map[asset.assetType] ?? 0) + asset.balance;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.assets.isEmpty) {
      return _buildEmptyState(context);
    }

    final totalBalance = widget.assets.fold(0.0, (sum, a) => sum + a.balance);
    final byType = _groupByType();
    final sortedEntries = byType.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _buildSummaryCard(context, totalBalance),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: _buildPieChart(context, sortedEntries, totalBalance),
          ),
        ),
        SliverToBoxAdapter(
          child: _buildTypeBreakdown(context, sortedEntries, totalBalance),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pie_chart_outline,
            size: 64,
            color: context.colorScheme.outline.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          AppText(
            LocaleKeys.assetStatisticNoData.tr(),
            style: AppTextStyle.bodyLarge,
            color: context.colorScheme.outline,
          ),
          const SizedBox(height: 8),
          AppText(
            LocaleKeys.assetStatisticNoDataSubtitle.tr(),
            style: AppTextStyle.bodySmall,
            color: context.colorScheme.outline.withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, double totalBalance) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.colorScheme.primary,
            context.colorScheme.primary.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.colorScheme.primary.withValues(alpha: 0.3),
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
              const Icon(
                Icons.account_balance_wallet,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 8),
              AppText(
                LocaleKeys.assetStatisticTotalBalance.tr(),
                style: AppTextStyle.titleSmall,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppText(
            context.formatMoney(totalBalance),
            style: AppTextStyle.headlineMedium,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          const SizedBox(height: 8),
          AppText(
            '${widget.assets.length} ${LocaleKeys.assetStatisticAssetCount.tr()}',
            style: AppTextStyle.bodySmall,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(
    BuildContext context,
    List<MapEntry<AssetType, double>> entries,
    double total,
  ) {
    if (entries.isEmpty) return const SizedBox();

    return SizedBox(
      height: 220,
      child: PieChart(
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
          sections: entries.asMap().entries.map((entry) {
            final index = entry.key;
            final type = entry.value.key;
            final amount = entry.value.value;
            final isTouched = index == _touchedIndex;
            final percentage = total > 0 ? (amount / total * 100) : 0.0;

            return PieChartSectionData(
              color: _colorForType(type),
              value: amount,
              title: '${percentage.toStringAsFixed(1)}%',
              radius: isTouched ? 65.0 : 55.0,
              titleStyle: TextStyle(
                fontSize: isTouched ? 14.0 : 12.0,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: const [Shadow(color: Colors.black26, blurRadius: 2)],
              ),
              badgeWidget: isTouched ? _buildBadge(context, type) : null,
              badgePositionPercentageOffset: 1.3,
            );
          }).toList(),
        ),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ),
    );
  }

  Widget _buildBadge(BuildContext context, AssetType type) {
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
        _nameForType(type),
        style: AppTextStyle.labelSmall,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTypeBreakdown(
    BuildContext context,
    List<MapEntry<AssetType, double>> entries,
    double total,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppText(
            LocaleKeys.assetStatisticByType.tr(),
            style: AppTextStyle.titleMedium,
            fontWeight: FontWeight.bold,
          ),
        ),
        ...entries.map((entry) {
          final type = entry.key;
          final amount = entry.value;
          final percentage = total > 0 ? amount / total : 0.0;
          final color = _colorForType(type);

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AppText(
                            _nameForType(type),
                            style: AppTextStyle.bodyMedium,
                            fontWeight: FontWeight.w500,
                          ),
                          AppText(
                            context.formatMoney(amount),
                            style: AppTextStyle.bodyMedium,
                            fontWeight: FontWeight.w600,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: percentage,
                          minHeight: 4,
                          backgroundColor:
                              context.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                      const SizedBox(height: 2),
                      AppText(
                        '${(percentage * 100).toStringAsFixed(1)}%',
                        style: AppTextStyle.labelSmall,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
