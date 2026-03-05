import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
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
      hintText: LocaleKeys.transactionSearchHint.tr(),
      initialValue: currentQuery,
      showClearButton: currentQuery != null && currentQuery!.isNotEmpty,
      onChanged: onChanged,
      onClear: onClear,
    );
  }
}
