import 'package:flutter/material.dart';
import 'package:ikuyo_finance/core/router/app_navigator.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/shared/utils/icon_registry.dart';
import 'package:ikuyo_finance/shared/widgets/app_image.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:intl/intl.dart';

class TransactionTile extends StatelessWidget {
  final Transaction transaction;

  const TransactionTile({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final category = transaction.category.target;
    final asset = transaction.asset.target;
    final isExpense = category?.categoryType == CategoryType.expense;

    return GestureDetector(
      onTap: () => context.pushToEditTransaction(transaction),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            // * Category Icon
            _buildCategoryIconContainer(category, context),
            const SizedBox(width: 12),
            // * Transaction Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    category?.name ?? 'Tanpa Kategori',
                    style: AppTextStyle.bodyMedium,
                    fontWeight: FontWeight.w600,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 14,
                        color: context.colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: AppText(
                          asset?.name ?? 'Unknown Asset',
                          style: AppTextStyle.labelSmall,
                          color: context.colorScheme.outline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (transaction.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    AppText(
                      transaction.description!,
                      style: AppTextStyle.labelSmall,
                      color: context.colorScheme.onSurfaceVariant,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // * Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AppText(
                  '${isExpense ? '-' : '+'}${_formatCurrency(transaction.amount)}',
                  style: AppTextStyle.bodyMedium,
                  fontWeight: FontWeight.bold,
                  color: isExpense
                      ? context.semantic.error
                      : context.semantic.success,
                ),
                const SizedBox(height: 4),
                AppText(
                  DateFormat('HH:mm').format(
                    transaction.transactionDate ?? transaction.createdAt,
                  ),
                  style: AppTextStyle.labelSmall,
                  color: context.colorScheme.outline,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(Category? category, BuildContext context) {
    if (category == null) return context.colorScheme.outline;
    if (category.color != null) {
      try {
        return Color(int.parse(category.color!.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    return category.categoryType == CategoryType.expense
        ? context.semantic.error
        : context.semantic.success;
  }

  /// * Check if icon is from registry (not a file path)
  bool _isRegistryIcon(String? iconData) {
    if (iconData == null || iconData.isEmpty) return true;
    return IconRegistry.isIconKey(iconData);
  }

  Widget _buildCategoryIconContainer(Category? category, BuildContext context) {
    final iconData = category?.icon;
    final color = _getCategoryColor(category, context);
    final isRegistryIcon = _isRegistryIcon(iconData);

    // * User uploaded image - show without colored background
    if (!isRegistryIcon && iconData != null && iconData.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 48,
          height: 48,
          child: AppImage.icon(iconData: iconData, size: 48),
        ),
      );
    }

    // * Flutter Icon - show with colored background
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: _buildCategoryIcon(category, context)),
    );
  }

  /// * Build icon widget dari registry key atau file path
  Widget _buildCategoryIcon(Category? category, BuildContext context) {
    final iconData = category?.icon;
    final color = _getCategoryColor(category, context);

    // * Jika ada icon data (registry key)
    if (iconData != null && iconData.isNotEmpty) {
      final icon = IconRegistry.getIcon(iconData);
      if (icon != null) {
        return Icon(icon, size: 24, color: color);
      }
    }

    // * Fallback ke icon default
    return Icon(Icons.category_outlined, color: color, size: 24);
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    ).format(amount);
  }
}
