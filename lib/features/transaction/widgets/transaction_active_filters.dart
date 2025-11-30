import 'package:flutter/material.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';

/// * Active filters indicator with clear button (pure UI, no bloc logic)
class TransactionActiveFilters extends StatelessWidget {
  final bool hasActiveFilters;
  final VoidCallback onClearFilters;

  const TransactionActiveFilters({
    super.key,
    required this.hasActiveFilters,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasActiveFilters) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.filter_list, size: 16, color: context.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            'Filter aktif',
            style: TextStyle(color: context.colorScheme.primary, fontSize: 12),
          ),
          const Spacer(),
          TextButton(
            onPressed: onClearFilters,
            child: const Text('Hapus semua'),
          ),
        ],
      ),
    );
  }
}
