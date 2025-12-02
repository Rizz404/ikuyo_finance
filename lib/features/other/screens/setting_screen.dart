import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/core/theme/cubit/theme_cubit.dart';
import 'package:ikuyo_finance/features/other/widgets/setting_group.dart';
import 'package:ikuyo_finance/features/other/widgets/setting_tile.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:ikuyo_finance/shared/widgets/screen_wrapper.dart';

class SettingScreen extends StatelessWidget {
  const SettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppText(
          'Pengaturan',
          style: AppTextStyle.titleLarge,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: true,
      ),
      body: ScreenWrapper(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // * Tampilan Settings Group
              SettingGroup(
                title: 'TAMPILAN',
                children: [
                  BlocBuilder<ThemeCubit, ThemeState>(
                    builder: (context, state) {
                      return ThemeSettingTile(
                        currentMode: state.themeMode,
                        onChanged: (mode) {
                          context.read<ThemeCubit>().setThemeMode(mode);
                        },
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // TODO: Tambahkan group pengaturan lainnya di sini
              // * Contoh: Notifikasi, Keamanan, Data, dll
            ],
          ),
        ),
      ),
    );
  }
}
