import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/extensions/theme_extension.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_log.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_log_status.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';

class AutoLogTile extends StatelessWidget {
  final AutoTransactionLog log;

  const AutoLogTile({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy HH:mm');
    final statusColor = _statusColor(context);
    final statusLabel = _statusLabel();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
              const SizedBox(height: 4),
              AppText(
                LocaleKeys.autoTransactionLogScheduledAt.tr(
                  namedArgs: {'time': fmt.format(log.scheduledAt)},
                ),
                style: AppTextStyle.bodySmall,
                color: context.colorScheme.outline,
              ),
              AppText(
                LocaleKeys.autoTransactionLogExecutedAt.tr(
                  namedArgs: {'time': fmt.format(log.executedAt)},
                ),
                style: AppTextStyle.bodySmall,
                color: context.colorScheme.outline,
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (log.successCount > 0)
                AppText(
                  LocaleKeys.autoTransactionLogSuccessCount.tr(
                    namedArgs: {'count': log.successCount.toString()},
                  ),
                  style: AppTextStyle.bodySmall,
                  color: context.semantic.success,
                ),
              if (log.failureCount > 0)
                AppText(
                  LocaleKeys.autoTransactionLogFailureCount.tr(
                    namedArgs: {'count': log.failureCount.toString()},
                  ),
                  style: AppTextStyle.bodySmall,
                  color: context.semantic.error,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(BuildContext context) => switch (log.logStatus) {
    AutoTransactionLogStatus.success => context.semantic.success,
    AutoTransactionLogStatus.partial => context.semantic.warning,
    AutoTransactionLogStatus.failed => context.semantic.error,
    AutoTransactionLogStatus.skipped => context.colorScheme.outline,
  };

  String _statusLabel() => switch (log.logStatus) {
    AutoTransactionLogStatus.success =>
      LocaleKeys.autoTransactionLogStatusSuccess.tr(),
    AutoTransactionLogStatus.partial =>
      LocaleKeys.autoTransactionLogStatusPartial.tr(),
    AutoTransactionLogStatus.failed =>
      LocaleKeys.autoTransactionLogStatusFailed.tr(),
    AutoTransactionLogStatus.skipped =>
      LocaleKeys.autoTransactionLogStatusSkipped.tr(),
  };
}
