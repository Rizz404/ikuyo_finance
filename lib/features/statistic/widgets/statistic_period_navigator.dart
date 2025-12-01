import 'package:flutter/material.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/features/statistic/models/statistic_period.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:intl/intl.dart';

/// * Widget untuk navigasi periode (prev/next) dengan dropdown tipe periode
class StatisticPeriodNavigator extends StatelessWidget {
  final StatisticPeriod period;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<StatisticPeriodType> onPeriodTypeChanged;
  final VoidCallback onCustomPeriodTap;

  const StatisticPeriodNavigator({
    super.key,
    required this.period,
    required this.onPrevious,
    required this.onNext,
    required this.onPeriodTypeChanged,
    required this.onCustomPeriodTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // * Period navigator (left side)
          Expanded(child: _buildPeriodNav(context)),
          const SizedBox(width: 8),
          // * Period type dropdown (right side)
          _buildPeriodDropdown(context),
        ],
      ),
    );
  }

  Widget _buildPeriodNav(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrevious,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: GestureDetector(
            onTap: period.type == StatisticPeriodType.custom
                ? onCustomPeriodTap
                : null,
            child: AppText(
              _formatPeriodLabel(),
              style: AppTextStyle.titleMedium,
              fontWeight: FontWeight.w600,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildPeriodDropdown(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<StatisticPeriodType>(
          value: period.type,
          isDense: true,
          icon: Icon(Icons.arrow_drop_down, color: context.colorScheme.primary),
          style: context.textTheme.labelMedium?.copyWith(
            color: context.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
          items: StatisticPeriodType.values.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(_getPeriodTypeLabel(type)),
            );
          }).toList(),
          onChanged: (type) {
            if (type != null) {
              if (type == StatisticPeriodType.custom) {
                onCustomPeriodTap();
              } else {
                onPeriodTypeChanged(type);
              }
            }
          },
        ),
      ),
    );
  }

  String _formatPeriodLabel() {
    switch (period.type) {
      case StatisticPeriodType.weekly:
        final startFormat = DateFormat('d MMM', 'id_ID');
        final endFormat = DateFormat('d MMM yyyy', 'id_ID');
        return '${startFormat.format(period.startDate)} - ${endFormat.format(period.endDate)}';

      case StatisticPeriodType.monthly:
        return DateFormat('MMMM yyyy', 'id_ID').format(period.startDate);

      case StatisticPeriodType.yearly:
        return period.startDate.year.toString();

      case StatisticPeriodType.custom:
        final format = DateFormat('d MMM yy', 'id_ID');
        return '${format.format(period.startDate)} - ${format.format(period.endDate)}';
    }
  }

  String _getPeriodTypeLabel(StatisticPeriodType type) {
    switch (type) {
      case StatisticPeriodType.weekly:
        return 'Mingguan';
      case StatisticPeriodType.monthly:
        return 'Bulanan';
      case StatisticPeriodType.yearly:
        return 'Tahunan';
      case StatisticPeriodType.custom:
        return 'Periode';
    }
  }
}
