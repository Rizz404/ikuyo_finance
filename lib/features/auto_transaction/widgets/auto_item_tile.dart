import 'package:flutter/material.dart';
import 'package:ikuyo_finance/core/currency/currency.dart';
import 'package:ikuyo_finance/core/extensions/theme_extension.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_item.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AutoItemTile extends StatelessWidget {
  final AutoTransactionItem item;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onLongPress;

  const AutoItemTile({
    super.key,
    required this.item,
    required this.onTap,
    required this.onToggle,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final tx = item.transaction.target;
    final description = tx?.description ?? 'Unnamed Transaction';
    final category = tx?.category.target?.name;
    final amount = tx?.amount ?? 0;
    final currencySymbol = context.read<CurrencyCubit>().symbol;

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: ReorderableDragStartListener(
        index: item.sortOrder,
        child: const Icon(Icons.drag_handle),
      ),
      title: AppText(
        description,
        style: AppTextStyle.bodyMedium,
        fontWeight: FontWeight.w500,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: category != null
          ? AppText(
              category,
              style: AppTextStyle.bodySmall,
              color: context.colorScheme.outline,
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppText(
            '$currencySymbol${amount.toStringAsFixed(0)}',
            style: AppTextStyle.bodySmall,
            color: context.colorScheme.outline,
          ),
          const SizedBox(width: 8),
          Switch(
            value: item.isActive,
            onChanged: onToggle,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
