import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:ikuyo_finance/core/extensions/currency_extension.dart';
import 'package:ikuyo_finance/core/extensions/navigator_extension.dart';
import 'package:ikuyo_finance/core/extensions/theme_extension.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/budget/models/budget_progress.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';

class BudgetCard extends StatelessWidget {
  final Budget budget;
  final BudgetProgress? progress;
  final VoidCallback? onTap;

  const BudgetCard({
    super.key,
    required this.budget,
    this.progress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getPeriodColor(context);
    final categoryName =
        budget.category.target?.name ?? LocaleKeys.transactionNoCategory.tr();

    return GestureDetector(
      onTap: onTap ?? () => context.pushToEditBudget(budget),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: context.colorScheme.shadow.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // * Header: Category & Period Badge
            Row(
              children: [
                Expanded(
                  child: AppText(
                    categoryName,
                    style: AppTextStyle.bodyLarge,
                    fontWeight: FontWeight.w600,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: AppText(
                    _getPeriodLabel().tr(),
                    style: AppTextStyle.labelSmall,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // * Amount Limit
            AppText(
              context.formatMoney(budget.amountLimit),
              style: AppTextStyle.titleMedium,
              fontWeight: FontWeight.bold,
              color: context.colorScheme.primary,
            ),
            if (progress != null) ...[
              const SizedBox(height: 8),
              _buildProgress(context, progress!),
            ],
            const SizedBox(height: 8),
            // * Date Range (for custom period)
            if (budget.budgetPeriod == BudgetPeriod.custom &&
                budget.startDate != null &&
                budget.endDate != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: context.colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  AppText(
                    '${_formatDate(context, budget.startDate!)} - ${_formatDate(context, budget.endDate!)}',
                    style: AppTextStyle.bodySmall,
                    color: context.colorScheme.outline,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // * Realisasi: bar di-clamp, persen & sisa tidak (AAOB-5)
  Widget _buildProgress(BuildContext context, BudgetProgress p) {
    final ratio = p.ratio;
    final barColor = p.isOverspent
        ? context.colorScheme.error
        : context.colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: p.barValue,
            minHeight: 6,
            color: barColor,
            backgroundColor: context.colorScheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: AppText(
                LocaleKeys.budgetCardSpentOf.tr(
                  namedArgs: {
                    'spent': context.formatMoney(p.spent),
                    'limit': context.formatMoney(p.limit),
                  },
                ),
                style: AppTextStyle.bodySmall,
                color: context.colorScheme.outline,
              ),
            ),
            if (ratio != null)
              AppText(
                '${(ratio * 100).round()}%',
                style: AppTextStyle.labelSmall,
                fontWeight: FontWeight.w600,
                color: barColor,
              ),
          ],
        ),
        const SizedBox(height: 2),
        AppText(
          p.isOverspent
              ? LocaleKeys.budgetCardOverspent.tr(
                  namedArgs: {'amount': context.formatMoney(-p.remaining)},
                )
              : LocaleKeys.budgetCardRemaining.tr(
                  namedArgs: {'amount': context.formatMoney(p.remaining)},
                ),
          style: AppTextStyle.bodySmall,
          fontWeight: FontWeight.w500,
          color: p.isOverspent ? context.colorScheme.error : null,
        ),
      ],
    );
  }

  String _getPeriodLabel() {
    return switch (budget.budgetPeriod) {
      BudgetPeriod.monthly => LocaleKeys.budgetScreenTabMonthly,
      BudgetPeriod.weekly => LocaleKeys.budgetScreenTabWeekly,
      BudgetPeriod.yearly => LocaleKeys.budgetScreenTabYearly,
      BudgetPeriod.custom => LocaleKeys.budgetScreenTabCustom,
    };
  }

  Color _getPeriodColor(BuildContext context) {
    return switch (budget.budgetPeriod) {
      BudgetPeriod.monthly => Colors.blue,
      BudgetPeriod.weekly => Colors.green,
      BudgetPeriod.yearly => Colors.purple,
      BudgetPeriod.custom => Colors.orange,
    };
  }

  String _formatDate(BuildContext context, DateTime date) {
    return DateFormat('dd MMM yyyy', context.locale.toString()).format(date);
  }
}
