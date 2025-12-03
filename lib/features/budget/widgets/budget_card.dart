import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/currency/currency.dart';
import 'package:ikuyo_finance/core/router/app_navigator.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:intl/intl.dart';

class BudgetCard extends StatelessWidget {
  final Budget budget;
  final VoidCallback? onTap;

  const BudgetCard({super.key, required this.budget, this.onTap});

  @override
  Widget build(BuildContext context) {
    final currencyCubit = context.read<CurrencyCubit>();
    final color = _getPeriodColor(context);
    final categoryName = budget.category.target?.name ?? 'Tanpa Kategori';

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
                    _getPeriodLabel(),
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
              currencyCubit.formatAmount(budget.amountLimit),
              style: AppTextStyle.titleMedium,
              fontWeight: FontWeight.bold,
              color: context.colorScheme.primary,
            ),
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
                    '${_formatDate(budget.startDate!)} - ${_formatDate(budget.endDate!)}',
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

  String _getPeriodLabel() {
    return switch (budget.budgetPeriod) {
      BudgetPeriod.monthly => 'Bulanan',
      BudgetPeriod.weekly => 'Mingguan',
      BudgetPeriod.yearly => 'Tahunan',
      BudgetPeriod.custom => 'Kustom',
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

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy', 'id_ID').format(date);
  }
}
