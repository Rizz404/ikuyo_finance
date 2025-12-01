import 'package:flutter/material.dart';
import 'package:ikuyo_finance/core/router/app_navigator.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/core/utils/toast_helper.dart';
import 'package:ikuyo_finance/features/setting/widgets/setting_card.dart';
import 'package:ikuyo_finance/shared/widgets/app_image.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:ikuyo_finance/shared/widgets/screen_wrapper.dart';

class SettingScreen extends StatelessWidget {
  const SettingScreen({super.key});

  void _showComingSoon(BuildContext context) {
    ToastHelper.instance.showInfo(
      context: context,
      title: "Coming Soon",
      description: "Fitur ini sedang dalam pengembangan",
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final semantic = context.semantic;

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan'), centerTitle: true),
      body: ScreenWrapper(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // * Brand Image Header
              const SizedBox(height: 8),
              AppImage(
                assetPath: 'assets/images/brand-img.png',
                size: ImageSize.fullWidth,
                shape: ImageShape.rectangle,
                fit: BoxFit.cover,
                showBorder: false,
              ),
              const SizedBox(height: 32),

              // * Settings Grid
              GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 0.95,
                children: [
                  SettingCard(
                    icon: Icons.settings_outlined,
                    text: "Pengaturan",
                    iconColor: colors.secondary,
                    iconBackgroundColor: colors.secondaryContainer.withValues(
                      alpha: 0.5,
                    ),
                    onTap: () => _showComingSoon(context),
                  ),
                  SettingCard(
                    icon: Icons.account_balance_wallet_outlined,
                    text: "Kelola Aset",
                    iconColor: colors.secondary,
                    iconBackgroundColor: colors.secondaryContainer.withValues(
                      alpha: 0.5,
                    ),
                    onTap: () => context.goToAsset(),
                  ),
                  SettingCard(
                    icon: Icons.category_outlined,
                    text: "Kelola Kategori",
                    iconColor: colors.secondary,
                    iconBackgroundColor: colors.secondaryContainer.withValues(
                      alpha: 0.5,
                    ),
                    onTap: () => context.pushToCategory(),
                  ),
                  SettingCard(
                    icon: Icons.lock_outline,
                    text: "Kata Sandi",
                    iconColor: colors.secondary,
                    iconBackgroundColor: colors.secondaryContainer.withValues(
                      alpha: 0.5,
                    ),
                    onTap: () => _showComingSoon(context),
                  ),
                  SettingCard(
                    icon: Icons.cloud_upload_outlined,
                    text: "Cadangan",
                    iconColor: colors.secondary,
                    iconBackgroundColor: colors.secondaryContainer.withValues(
                      alpha: 0.5,
                    ),
                    onTap: () => _showComingSoon(context),
                  ),
                  SettingCard(
                    icon: Icons.help_outline,
                    text: "Bantuan",
                    iconColor: colors.secondary,
                    iconBackgroundColor: colors.secondaryContainer.withValues(
                      alpha: 0.5,
                    ),
                    onTap: () => _showComingSoon(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
