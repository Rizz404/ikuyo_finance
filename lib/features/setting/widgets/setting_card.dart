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
        child: Column(
          children: [Icon(icon), SizedBox(height: 4), AppText(text)],
        ),
      ),
    );
  }
}
