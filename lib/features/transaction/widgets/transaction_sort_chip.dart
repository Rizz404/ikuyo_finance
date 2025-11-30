import 'package:flutter/material.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/features/transaction/models/get_transactions_params.dart';

/// * Sort options chip widget (pure UI, no bloc logic)
class TransactionSortChip extends StatelessWidget {
  final TransactionSortBy currentSortBy;
  final SortOrder currentSortOrder;
  final void Function(TransactionSortBy sortBy, SortOrder sortOrder)
  onSortChanged;

  const TransactionSortChip({
    super.key,
    required this.currentSortBy,
    required this.currentSortOrder,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<TransactionSortBy>(
      initialValue: currentSortBy,
      onSelected: (sortBy) {
        // * Toggle order if same sortBy selected
        final newOrder = currentSortBy == sortBy
            ? (currentSortOrder == SortOrder.descending
                  ? SortOrder.ascending
                  : SortOrder.descending)
            : SortOrder.descending;

        onSortChanged(sortBy, newOrder);
      },
      itemBuilder: (context) => [
        _buildSortMenuItem(
          context,
          TransactionSortBy.transactionDate,
          'Tanggal Transaksi',
        ),
        _buildSortMenuItem(context, TransactionSortBy.amount, 'Jumlah'),
        _buildSortMenuItem(
          context,
          TransactionSortBy.createdAt,
          'Tanggal Dibuat',
        ),
      ],
      child: Chip(
        avatar: Icon(
          currentSortOrder == SortOrder.descending
              ? Icons.arrow_downward
              : Icons.arrow_upward,
          size: 16,
          color: context.colorScheme.primary,
        ),
        label: Text(_getSortLabel(currentSortBy)),
        backgroundColor: context.colorScheme.surfaceContainerHighest,
      ),
    );
  }

  PopupMenuItem<TransactionSortBy> _buildSortMenuItem(
    BuildContext context,
    TransactionSortBy sortBy,
    String label,
  ) {
    final isSelected = currentSortBy == sortBy;
    return PopupMenuItem(
      value: sortBy,
      child: Row(
        children: [
          if (isSelected) ...[
            Icon(
              currentSortOrder == SortOrder.descending
                  ? Icons.arrow_downward
                  : Icons.arrow_upward,
              size: 16,
              color: context.colorScheme.primary,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? context.colorScheme.primary : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSortLabel(TransactionSortBy sortBy) {
    switch (sortBy) {
      case TransactionSortBy.transactionDate:
        return 'Tanggal';
      case TransactionSortBy.amount:
        return 'Jumlah';
      case TransactionSortBy.createdAt:
        return 'Dibuat';
    }
  }
}
