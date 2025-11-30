import 'package:flutter/material.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';

class SettingCard extends StatelessWidget {
  final GestureTapCallback? onTap;
  final IconData icon;
  final String text;

  const SettingCard({
    super.key,
    required this.icon,
    required this.text,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32),
              SizedBox(height: 8),
              AppText(text, style: AppTextStyle.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}
