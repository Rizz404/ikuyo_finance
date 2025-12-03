import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/currency/currency.dart';
import 'package:ikuyo_finance/core/theme/cubit/theme_cubit.dart';
import 'package:ikuyo_finance/core/utils/toast_helper.dart';
import 'package:ikuyo_finance/features/asset/bloc/asset_bloc.dart';
import 'package:ikuyo_finance/features/budget/bloc/budget_bloc.dart';
import 'package:ikuyo_finance/features/other/widgets/setting_group.dart';
import 'package:ikuyo_finance/features/other/widgets/setting_tile.dart';
import 'package:ikuyo_finance/features/transaction/bloc/transaction_bloc.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:ikuyo_finance/shared/widgets/currency_migration_dialog.dart';
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

              // * Mata Uang Settings Group
              SettingGroup(
                title: 'MATA UANG',
                children: [
                  BlocBuilder<CurrencyCubit, CurrencyState>(
                    builder: (context, state) {
                      final currencyCubit = context.read<CurrencyCubit>();
                      return CurrencySettingTile(
                        currentCurrency: state.currentCurrency,
                        availableCurrencies: currencyCubit.availableCurrencies,
                        onChanged: (newCurrency) =>
                            _handleCurrencyChange(context, state, newCurrency),
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

  Future<void> _handleCurrencyChange(
    BuildContext context,
    CurrencyState currentState,
    CurrencyCode newCurrency,
  ) async {
    if (newCurrency == currentState.currentCurrency) return;

    // * Show confirmation & migration dialog
    final success = await CurrencyMigrationDialog.show(
      context,
      from: currentState.currentCurrency,
      to: newCurrency,
    );

    if (success && context.mounted) {
      // * Refresh all blocs to reload migrated data
      context.read<AssetBloc>().add(const AssetRefreshed());
      context.read<TransactionBloc>().add(const TransactionRefreshed());
      context.read<BudgetBloc>().add(const BudgetRefreshed());

      ToastHelper.instance.showSuccess(
        context: context,
        title: 'Mata uang berhasil diubah',
      );
    }
  }
}
