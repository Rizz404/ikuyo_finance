import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
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
              _formatPeriodLabel(context),
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

  String _formatPeriodLabel(BuildContext context) {
    switch (period.type) {
      case StatisticPeriodType.weekly:
        final startFormat = DateFormat('d MMM', context.locale.toString());
        final endFormat = DateFormat('d MMM yyyy', context.locale.toString());
        return '${startFormat.format(period.startDate)} - ${endFormat.format(period.endDate)}';

      case StatisticPeriodType.monthly:
        return DateFormat(
          'MMMM yyyy',
          context.locale.toString(),
        ).format(period.startDate);

      case StatisticPeriodType.yearly:
        return period.startDate.year.toString();

      case StatisticPeriodType.custom:
        final format = DateFormat('d MMM yy', context.locale.toString());
        return '${format.format(period.startDate)} - ${format.format(period.endDate)}';
    }
  }

  String _getPeriodTypeLabel(StatisticPeriodType type) {
    switch (type) {
      case StatisticPeriodType.weekly:
        return LocaleKeys.statisticPeriodWeekly.tr();
      case StatisticPeriodType.monthly:
        return LocaleKeys.statisticPeriodMonthly.tr();
      case StatisticPeriodType.yearly:
        return LocaleKeys.statisticPeriodYearly.tr();
      case StatisticPeriodType.custom:
        return LocaleKeys.statisticPeriodCustom.tr();
    }
  }
}
