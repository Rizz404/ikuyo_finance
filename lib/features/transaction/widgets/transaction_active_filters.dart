import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/extensions/theme_extension.dart';
import 'package:intl/intl.dart';

/// * Active filters indicator with clear button (pure UI, no bloc logic)
class TransactionActiveFilters extends StatelessWidget {
  final bool hasActiveFilters;
  final VoidCallback onClearFilters;
  final String? assetName;
  final String? categoryName;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? minAmount;
  final double? maxAmount;
  final String sortLabel;
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  const TransactionActiveFilters({
    super.key,
    required this.hasActiveFilters,
    required this.onClearFilters,
    required this.isExpanded,
    required this.onToggleExpand,
    this.assetName,
    this.categoryName,
    this.startDate,
    this.endDate,
    this.minAmount,
    this.maxAmount,
    this.sortLabel = '',
  });

  @override
  Widget build(BuildContext context) {
    final activeFilterChips = <Widget>[];

    // * Add sorting chip (always shown)
    activeFilterChips.add(
      _buildChip(context, Icons.sort, sortLabel, isSort: true),
    );

    // * Add filter chips based on active filters
    if (assetName != null) {
      activeFilterChips.add(
        _buildChip(context, Icons.account_balance, assetName!),
      );
    }
    if (categoryName != null) {
      activeFilterChips.add(_buildChip(context, Icons.category, categoryName!));
    }
    if (startDate != null || endDate != null) {
      final dateText = _formatDateRange(context, startDate, endDate);
      activeFilterChips.add(_buildChip(context, Icons.date_range, dateText));
    }
    if (minAmount != null || maxAmount != null) {
      final amountText = _formatAmountRange(minAmount, maxAmount);
      activeFilterChips.add(
        _buildChip(context, Icons.attach_money, amountText),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggleExpand,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_list,
                    size: 16,
                    color: context.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasActiveFilters
                        ? 'Filter & Sorting aktif' // TODO: add key for this if needed
                        : LocaleKeys.transactionFilterSort.tr(),
                    style: TextStyle(
                      color: context.colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 16,
                    color: context.colorScheme.primary,
                  ),
                  const Spacer(),
                  if (hasActiveFilters)
                    TextButton(
                      onPressed: onClearFilters,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 32),
                      ),
                      child: Text(
                        LocaleKeys.transactionFilterReset.tr(),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // * Animated expand/collapse
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: activeFilterChips,
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context,
    IconData icon,
    String label, {
    bool isSort = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSort
            ? context.colorScheme.primaryContainer
            : context.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isSort
                ? context.colorScheme.onPrimaryContainer
                : context.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isSort
                  ? context.colorScheme.onPrimaryContainer
                  : context.colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateRange(
    BuildContext context,
    DateTime? start,
    DateTime? end,
  ) {
    if (start != null && end != null) {
      return '${_formatDate(context, start)} - ${_formatDate(context, end)}';
    } else if (start != null) {
      return '${LocaleKeys.transactionFilterFrom.tr()} ${_formatDate(context, start)}';
    } else if (end != null) {
      return '${LocaleKeys.transactionFilterTo.tr()} ${_formatDate(context, end)}';
    }
    return '';
  }

  String _formatDate(BuildContext context, DateTime date) {
    return DateFormat.yMd(context.locale.toString()).format(date);
  }

  String _formatAmountRange(double? min, double? max) {
    if (min != null && max != null) {
      return '${_formatAmount(min)} - ${_formatAmount(max)}';
    } else if (min != null) {
      return '${LocaleKeys.transactionFilterMin.tr()} ${_formatAmount(min)}';
    } else if (max != null) {
      return '${LocaleKeys.transactionFilterMax.tr()} ${_formatAmount(max)}';
    }
    return '';
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}jt';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}rb';
    }
    return amount.toStringAsFixed(0);
  }
}
