import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';

/// Reusable bottom sheet for list options (create, select many, filter & sort, export)
class AppListOptionsBottomSheet extends StatelessWidget {
  final VoidCallback? onCreate;
  final VoidCallback onSelectMany;
  final Widget Function() filterSortWidgetBuilder;
  final Widget Function()? exportWidgetBuilder;
  final String? createTitle;
  final String? createSubtitle;
  final String? selectManyTitle;
  final String? selectManySubtitle;
  final String? filterSortTitle;
  final String? filterSortSubtitle;
  final String? exportTitle;
  final String? exportSubtitle;

  const AppListOptionsBottomSheet({
    super.key,
    this.onCreate,
    required this.onSelectMany,
    required this.filterSortWidgetBuilder,
    this.exportWidgetBuilder,
    this.createTitle,
    this.createSubtitle,
    this.selectManyTitle,
    this.selectManySubtitle,
    this.filterSortTitle,
    this.filterSortSubtitle,
    this.exportTitle,
    this.exportSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            AppText(
              LocaleKeys.sharedWidgetsListBottomSheetOptionsHeader.tr(),
              style: AppTextStyle.titleLarge,
              fontWeight: FontWeight.bold,
            ),
            const SizedBox(height: 24),
            if (onCreate != null) ...[
              _OptionTile(
                icon: Icons.add_circle_outline,
                title:
                    createTitle ??
                    LocaleKeys.sharedWidgetsListBottomSheetCreateTitle.tr(),
                subtitle:
                    createSubtitle ??
                    LocaleKeys.sharedWidgetsListBottomSheetCreateSubtitle.tr(),
                onTap: onCreate!,
              ),
              const SizedBox(height: 12),
            ],
            _OptionTile(
              icon: Icons.checklist,
              title:
                  selectManyTitle ??
                  LocaleKeys.sharedWidgetsListBottomSheetSelectManyTitle.tr(),
              subtitle:
                  selectManySubtitle ??
                  LocaleKeys.sharedWidgetsListBottomSheetSelectManySubtitle.tr(),
              onTap: onSelectMany,
            ),
            const SizedBox(height: 12),
            _OptionTile(
              icon: Icons.filter_list,
              title:
                  filterSortTitle ??
                  LocaleKeys.sharedWidgetsListBottomSheetFilterSortTitle.tr(),
              subtitle:
                  filterSortSubtitle ??
                  LocaleKeys.sharedWidgetsListBottomSheetFilterSortSubtitle.tr(),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: context.colors.surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  builder: (context) => filterSortWidgetBuilder(),
                );
              },
            ),
            const SizedBox(height: 12),
            if (exportWidgetBuilder != null) ...[
              _OptionTile(
                icon: Icons.download,
                title:
                    exportTitle ??
                    LocaleKeys.sharedWidgetsListBottomSheetExportTitle.tr(),
                subtitle:
                    exportSubtitle ??
                    LocaleKeys.sharedWidgetsListBottomSheetExportSubtitle.tr(),
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: context.colors.surface,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    builder: (context) => exportWidgetBuilder!(),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: context.colors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colorScheme.primaryContainer.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: context.colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    title,
                    style: AppTextStyle.bodyLarge,
                    fontWeight: FontWeight.w600,
                  ),
                  const SizedBox(height: 4),
                  AppText(
                    subtitle,
                    style: AppTextStyle.bodySmall,
                    color: context.colors.textSecondary,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: context.colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
