import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_group.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';

class AutoGroupTile extends StatelessWidget {
  final AutoTransactionGroup group;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onItemsTap;
  final VoidCallback onLogTap;

  const AutoGroupTile({
    super.key,
    required this.group,
    required this.onTap,
    required this.onToggle,
    required this.onItemsTap,
    required this.onLogTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPaused = group.isCurrentlyPaused();
    final statusColor = _statusColor(context, isPaused);
    final statusLabel = _statusLabel(isPaused);

    return GestureDetector(
      onTap: onTap,
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
            Row(
              children: [
                Expanded(
                  child: AppText(
                    group.name,
                    style: AppTextStyle.bodyLarge,
                    fontWeight: FontWeight.w600,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: AppText(
                    statusLabel,
                    style: AppTextStyle.labelSmall,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: group.isActive,
                  onChanged: onToggle,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            if (group.description != null && group.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              AppText(
                group.description!,
                style: AppTextStyle.bodySmall,
                color: context.colorScheme.outline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 14,
                  color: context.colorScheme.outline,
                ),
                const SizedBox(width: 4),
                AppText(
                  _scheduleLabel(),
                  style: AppTextStyle.bodySmall,
                  color: context.colorScheme.outline,
                ),
                const Spacer(),
                AppText(
                  LocaleKeys.autoTransactionTileItems.tr(
                    namedArgs: {'count': group.items.length.toString()},
                  ),
                  style: AppTextStyle.labelSmall,
                  color: context.colorScheme.outline,
                ),
              ],
            ),
            if (_pauseNote(isPaused) != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.pause_circle_outline,
                    size: 14,
                    color: context.semantic.warning,
                  ),
                  const SizedBox(width: 4),
                  AppText(
                    _pauseNote(isPaused)!,
                    style: AppTextStyle.bodySmall,
                    color: context.semantic.warning,
                  ),
                ],
              ),
            ],
            if (group.nextExecutedAt != null && !isPaused) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.arrow_forward,
                    size: 14,
                    color: context.colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  AppText(
                    LocaleKeys.autoTransactionTileNextRun.tr(
                      namedArgs: {
                        'time': DateFormat(
                          'dd MMM yyyy HH:mm',
                        ).format(group.nextExecutedAt!),
                      },
                    ),
                    style: AppTextStyle.bodySmall,
                    color: context.colorScheme.outline,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onItemsTap,
                  icon: const Icon(Icons.list, size: 16),
                  label: AppText('Items', style: AppTextStyle.labelSmall),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: onLogTap,
                  icon: const Icon(Icons.history, size: 16),
                  label: AppText('Log', style: AppTextStyle.labelSmall),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(BuildContext context, bool isPaused) {
    if (!group.isActive) return context.colorScheme.outline;
    if (isPaused) return context.semantic.warning;
    return context.semantic.success;
  }

  String _statusLabel(bool isPaused) {
    if (!group.isActive) {
      return LocaleKeys.autoTransactionTileInactive.tr();
    }
    if (isPaused) {
      return LocaleKeys.autoTransactionTileRunning.tr();
    }
    return LocaleKeys.autoTransactionTileActive.tr();
  }

  String _scheduleLabel() {
    final freq = group.scheduleFrequency.name;
    final time =
        '${group.scheduleHour.toString().padLeft(2, '0')}:${group.scheduleMinute.toString().padLeft(2, '0')}';
    return '$freq · $time';
  }

  String? _pauseNote(bool isPaused) {
    if (!isPaused) return null;
    if (group.pauseEndAt == null) {
      return LocaleKeys.autoTransactionTilePausedManually.tr();
    }
    return LocaleKeys.autoTransactionTilePausedUntil.tr(
      namedArgs: {'date': DateFormat('dd MMM yyyy').format(group.pauseEndAt!)},
    );
  }
}
