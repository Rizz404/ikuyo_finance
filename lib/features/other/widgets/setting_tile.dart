import 'package:flutter/material.dart';
import 'package:ikuyo_finance/core/currency/currency.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';

/// Widget tile untuk item pengaturan dengan berbagai tipe
class SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final bool showChevron;

  const SettingTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.iconBackgroundColor,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // * Icon container
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      iconBackgroundColor ??
                      colors.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor ?? colors.primary),
              ),
              const SizedBox(width: 16),
              // * Title & subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      title,
                      style: AppTextStyle.bodyMedium,
                      fontWeight: FontWeight.w500,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      AppText(
                        subtitle!,
                        style: AppTextStyle.bodySmall,
                        color: colors.textSecondary,
                      ),
                    ],
                  ],
                ),
              ),
              // * Trailing widget or chevron
              if (trailing != null) trailing!,
              if (trailing == null && showChevron)
                Icon(Icons.chevron_right, color: colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget tile dengan segmented button untuk pilihan tema
class ThemeSettingTile extends StatelessWidget {
  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onChanged;

  const ThemeSettingTile({
    super.key,
    required this.currentMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getThemeIcon(currentMode),
                  size: 20,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      'Tema Aplikasi',
                      style: AppTextStyle.bodyMedium,
                      fontWeight: FontWeight.w500,
                    ),
                    SizedBox(height: 2),
                    AppText(
                      'Pilih tampilan sesuai preferensi',
                      style: AppTextStyle.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // * Theme selector
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(
                  value: ThemeMode.light,
                  label: const AppText(
                    'Terang',
                    style: AppTextStyle.labelMedium,
                  ),
                  icon: const Icon(Icons.light_mode_outlined, size: 18),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: const AppText(
                    'Gelap',
                    style: AppTextStyle.labelMedium,
                  ),
                  icon: const Icon(Icons.dark_mode_outlined, size: 18),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  label: const AppText(
                    'Sistem',
                    style: AppTextStyle.labelMedium,
                  ),
                  icon: const Icon(Icons.brightness_auto_outlined, size: 18),
                ),
              ],
              selected: {currentMode},
              onSelectionChanged: (selection) => onChanged(selection.first),
              style: ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getThemeIcon(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => Icons.light_mode,
      ThemeMode.dark => Icons.dark_mode,
      ThemeMode.system => Icons.brightness_auto,
    };
  }
}

/// Widget tile untuk pilihan mata uang dengan dropdown
class CurrencySettingTile extends StatelessWidget {
  final CurrencyCode currentCurrency;
  final List<Currency> availableCurrencies;
  final ValueChanged<CurrencyCode> onChanged;

  const CurrencySettingTile({
    super.key,
    required this.currentCurrency,
    required this.availableCurrencies,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final current = Currency.getByCode(currentCurrency);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: AppText(
                    current.symbol,
                    style: AppTextStyle.titleMedium,
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      'Mata Uang',
                      style: AppTextStyle.bodyMedium,
                      fontWeight: FontWeight.w500,
                    ),
                    SizedBox(height: 2),
                    AppText(
                      'Semua nilai akan dikonversi',
                      style: AppTextStyle.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // * Currency dropdown
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: colors.border.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<CurrencyCode>(
                value: currentCurrency,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down),
                items: availableCurrencies.map((currency) {
                  return DropdownMenuItem(
                    value: currency.code,
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: AppText(
                              currency.symbol,
                              style: AppTextStyle.bodyMedium,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppText(
                                currency.name,
                                style: AppTextStyle.bodyMedium,
                              ),
                              AppText(
                                currency.code.name.toUpperCase(),
                                style: AppTextStyle.labelSmall,
                                color: colors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    onChanged(value);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
