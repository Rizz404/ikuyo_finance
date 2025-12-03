import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/currency/currency.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/features/statistic/models/category_summary.dart';
import 'package:ikuyo_finance/shared/utils/icon_registry.dart';
import 'package:ikuyo_finance/shared/widgets/app_image.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';

/// * Widget untuk menampilkan list kategori dengan total transaksi
class CategorySummaryList extends StatelessWidget {
  final List<CategorySummary> summaries;
  final bool isIncome;

  const CategorySummaryList({
    super.key,
    required this.summaries,
    required this.isIncome,
  });

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: AppText(
            isIncome ? 'Pendapatan per Kategori' : 'Pengeluaran per Kategori',
            style: AppTextStyle.titleSmall,
            fontWeight: FontWeight.w600,
          ),
        ),
        ...summaries.asMap().entries.map((entry) {
          final index = entry.key;
          final summary = entry.value;
          return _CategorySummaryTile(
            summary: summary,
            isIncome: isIncome,
            index: index,
          );
        }),
      ],
    );
  }
}

class _CategorySummaryTile extends StatelessWidget {
  final CategorySummary summary;
  final bool isIncome;
  final int index;

  const _CategorySummaryTile({
    required this.summary,
    required this.isIncome,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getCategoryColor(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          // * Category icon/color indicator
          _buildIconContainer(context, color),
          const SizedBox(width: 12),
          // * Category info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppText(
                        summary.categoryName,
                        style: AppTextStyle.bodyMedium,
                        fontWeight: FontWeight.w600,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AppText(
                      _formatCurrency(context, summary.totalAmount),
                      style: AppTextStyle.bodyMedium,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    AppText(
                      '${summary.transactionCount} transaksi',
                      style: AppTextStyle.labelSmall,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: AppText(
                        '${summary.percentage.toStringAsFixed(1)}%',
                        style: AppTextStyle.labelSmall,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // * Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: summary.percentage / 100,
                    backgroundColor: context.colorScheme.outlineVariant
                        .withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(BuildContext context, Color color) {
    final iconData = summary.categoryIcon;

    // * Jika ada icon data (codePoint atau file path)
    if (iconData != null && iconData.isNotEmpty) {
      return AppImage.icon(iconData: iconData, size: 24, color: color);
    }

    return Icon(
      isIncome ? Icons.trending_up : Icons.trending_down,
      color: color,
      size: 24,
    );
  }

  /// * Check if icon is from registry (not a file path)
  bool _isRegistryIcon(String? iconData) {
    if (iconData == null || iconData.isEmpty) return true;
    return IconRegistry.isIconKey(iconData);
  }

  Widget _buildIconContainer(BuildContext context, Color color) {
    final iconData = summary.categoryIcon;
    final isRegistryIcon = _isRegistryIcon(iconData);

    // * User uploaded image - show without colored background
    if (!isRegistryIcon && iconData != null && iconData.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: AppImage.icon(iconData: iconData, size: 44),
        ),
      );
    }

    // * Flutter Icon - show with colored background
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: _buildIcon(context, color)),
    );
  }

  Color _getCategoryColor(BuildContext context) {
    // * Try to use category color first
    if (summary.categoryColor != null) {
      try {
        return Color(
          int.parse(summary.categoryColor!.replaceFirst('#', '0xFF')),
        );
      } catch (_) {}
    }

    // * Fallback to predefined colors based on index
    final colors = isIncome
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

  String _formatCurrency(BuildContext context, double amount) {
    return context.read<CurrencyCubit>().formatAmount(amount);
  }
}
