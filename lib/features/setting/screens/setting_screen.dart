import 'package:flutter/material.dart';
import 'package:ikuyo_finance/core/utils/toast_helper.dart';
import 'package:ikuyo_finance/features/setting/widgets/setting_card.dart';
import 'package:ikuyo_finance/shared/widgets/screen_wrapper.dart';

class SettingScreen extends StatelessWidget {
  const SettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ScreenWrapper(
        child: GridView(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          children: [
            SettingCard(
              icon: Icons.settings,
              text: "Pengaturan",
              onTap: () => ToastHelper.instance.showInfo(
                context: context,
                title: "Belum di implementasikan",
              ),
            ),
            SettingCard(
              icon: Icons.settings,
              text: "Pengaturan",
              onTap: () => ToastHelper.instance.showInfo(
                context: context,
                title: "Belum di implementasikan",
              ),
            ),
            SettingCard(
              icon: Icons.settings,
              text: "Pengaturan",
              onTap: () => ToastHelper.instance.showInfo(
                context: context,
                title: "Belum di implementasikan",
              ),
            ),
            SettingCard(
              icon: Icons.settings,
              text: "Pengaturan",
              onTap: () => ToastHelper.instance.showInfo(
                context: context,
                title: "Belum di implementasikan",
              ),
            ),
            SettingCard(
              icon: Icons.settings,
              text: "Pengaturan",
              onTap: () => ToastHelper.instance.showInfo(
                context: context,
                title: "Belum di implementasikan",
              ),
            ),
          ],
        ),
      ),
    );
  }
}
