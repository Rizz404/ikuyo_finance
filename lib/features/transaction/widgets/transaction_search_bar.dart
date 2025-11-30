import 'package:flutter/material.dart';
import 'package:ikuyo_finance/shared/widgets/app_search_field.dart';

/// * Search bar widget untuk transaksi (pure UI, no bloc logic)
class TransactionSearchBar extends StatelessWidget {
  final String? currentQuery;
  final ValueChanged<String?> onChanged;
  final VoidCallback onClear;

  const TransactionSearchBar({
    super.key,
    this.currentQuery,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return AppSearchField<String>(
      name: 'transaction_search',
      hintText: 'Cari transaksi...',
      initialValue: currentQuery,
      showClearButton: currentQuery != null && currentQuery!.isNotEmpty,
      onChanged: onChanged,
      onClear: onClear,
    );
  }
}
