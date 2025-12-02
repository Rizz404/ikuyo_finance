import 'package:flutter/material.dart';
import 'package:ikuyo_finance/core/router/app_navigator.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/shared/utils/icon_registry.dart';
import 'package:ikuyo_finance/shared/widgets/app_image.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';

class CategoryCard extends StatelessWidget {
  final Category category;
  final VoidCallback? onTap;

  const CategoryCard({super.key, required this.category, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isExpense = category.categoryType == CategoryType.expense;
    final color = _getCategoryColor(context);

    return GestureDetector(
      onTap: onTap ?? () => context.pushToEditCategory(category),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // * Category Icon
            _buildCategoryIconContainer(context, color),
            const SizedBox(height: 12),
            // * Category Name
            AppText(
              category.name,
              style: AppTextStyle.bodyMedium,
              fontWeight: FontWeight.w600,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            // * Category Type Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: AppText(
                isExpense ? 'Pengeluaran' : 'Pemasukan',
                style: AppTextStyle.labelSmall,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(BuildContext context) {
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

  Widget _buildCategoryIconContainer(BuildContext context, Color color) {
    final iconData = category.icon;
    final isRegistryIcon = _isRegistryIcon(iconData);

    // * User uploaded image - show without colored background
    if (!isRegistryIcon && iconData != null && iconData.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 56,
          height: 56,
          child: AppImage.icon(iconData: iconData, size: 56),
        ),
      );
    }

    // * Flutter Icon - show with colored background
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(child: _buildCategoryIcon(context, color)),
    );
  }

  Widget _buildCategoryIcon(BuildContext context, Color color) {
    final iconData = category.icon;

    // * Jika ada icon data (registry key)
    if (iconData != null && iconData.isNotEmpty) {
      final icon = IconRegistry.getIcon(iconData);
      if (icon != null) {
        return Icon(icon, size: 28, color: color);
      }
    }

    // * Fallback ke icon default
    return Icon(Icons.category_outlined, color: color, size: 28);
  }
}
