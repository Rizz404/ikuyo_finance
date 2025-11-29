import 'package:flutter/material.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';

class CalendarTransactionView extends StatelessWidget {
  const CalendarTransactionView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 64,
            color: context.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          AppText(
            'Tampilan Kalender',
            style: AppTextStyle.bodyLarge,
            color: context.colorScheme.outline,
          ),
          const SizedBox(height: 8),
          AppText(
            'Coming Soon',
            style: AppTextStyle.bodySmall,
            color: context.colorScheme.outline,
          ),
        ],
      ),
    );
  }
}
