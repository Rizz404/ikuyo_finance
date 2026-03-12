import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/currency/currency.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/extensions/theme_extension.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_schedule_frequency.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_group.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';

class AutoGroupTile extends StatelessWidget {
  final AutoTransactionGroup group;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onItemsTap;
  final VoidCallback onLogTap;
  final VoidCallback? onLongPress;

  const AutoGroupTile({
    super.key,
    required this.group,
    required this.onTap,
    required this.onToggle,
    required this.onItemsTap,
    required this.onLogTap,
    this.onLongPress,
  });

  bool get _isSingleItem => group.items.length == 1;

  @override
  Widget build(BuildContext context) {
    final isPaused = group.isCurrentlyPaused();
    final statusColor = _statusColor(context, isPaused);
    final statusLabel = _statusLabel(isPaused);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(_isSingleItem ? 20 : 16, 16, 16, 16),
            decoration: BoxDecoration(
              color: _isSingleItem
                  ? context.colorScheme.primaryContainer.withValues(alpha: 0.15)
                  : context.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isSingleItem
                    ? context.colorScheme.primary.withValues(alpha: 0.35)
                    : context.colorScheme.outlineVariant.withValues(alpha: 0.5),
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
                        group.name.isNotEmpty ? group.name : '—',
                        style: AppTextStyle.bodyLarge,
                        fontWeight: FontWeight.w600,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        color: group.name.isEmpty
                            ? context.colorScheme.outline
                            : null,
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
                if (group.description != null &&
                    group.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  AppText(
                    group.description!,
                    style: AppTextStyle.bodySmall,
                    color: context.colorScheme.outline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (_isSingleItem) ...[
                  const SizedBox(height: 6),
                  _buildSingleItemInfo(context),
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
                    if (_isSingleItem)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: context.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: AppText(
                          LocaleKeys.autoTransactionTileSingleItem.tr(),
                          style: AppTextStyle.labelSmall,
                          color: context.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
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
          if (_isSingleItem)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                child: Container(width: 4, color: context.colorScheme.primary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSingleItemInfo(BuildContext context) {
    final tx = group.items.first.transaction.target;
    if (tx == null) return const SizedBox.shrink();

    final txName = tx.description ?? '—';
    final category = tx.category.target?.name;
    final amount = tx.amount;
    final currencySymbol = context.read<CurrencyCubit>().symbol;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.colorScheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 14,
            color: context.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  txName,
                  style: AppTextStyle.bodySmall,
                  fontWeight: FontWeight.w500,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (category != null)
                  AppText(
                    category,
                    style: AppTextStyle.labelSmall,
                    color: context.colorScheme.outline,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AppText(
            '$currencySymbol${amount.toStringAsFixed(0)}',
            style: AppTextStyle.bodySmall,
            fontWeight: FontWeight.w600,
            color: context.colorScheme.primary,
          ),
        ],
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
    final time =
        '${group.scheduleHour.toString().padLeft(2, '0')}:${group.scheduleMinute.toString().padLeft(2, '0')}';
    final freqLabel = switch (group.scheduleFrequency) {
      AutoScheduleFrequency.daily =>
        LocaleKeys.autoTransactionFrequencyDaily.tr(),
      AutoScheduleFrequency.everyNDays =>
        LocaleKeys.autoTransactionTileEveryNDays.tr(
          namedArgs: {'n': group.intervalDays.toString()},
        ),
      AutoScheduleFrequency.weekly =>
        LocaleKeys.autoTransactionFrequencyWeekly.tr(),
      AutoScheduleFrequency.monthly =>
        LocaleKeys.autoTransactionFrequencyMonthly.tr(),
      AutoScheduleFrequency.yearly =>
        LocaleKeys.autoTransactionFrequencyYearly.tr(),
    };
    return '$freqLabel · $time';
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
