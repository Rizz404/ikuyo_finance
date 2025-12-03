import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/currency/currency.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/shared/widgets/app_button.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';

/// Dialog for confirming and showing progress of currency migration
class CurrencyMigrationDialog extends StatefulWidget {
  final CurrencyCode fromCurrency;
  final CurrencyCode toCurrency;

  const CurrencyMigrationDialog({
    super.key,
    required this.fromCurrency,
    required this.toCurrency,
  });

  /// Show migration dialog and return true if migration succeeded
  static Future<bool> show(
    BuildContext context, {
    required CurrencyCode from,
    required CurrencyCode to,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          CurrencyMigrationDialog(fromCurrency: from, toCurrency: to),
    );
    return result ?? false;
  }

  @override
  State<CurrencyMigrationDialog> createState() =>
      _CurrencyMigrationDialogState();
}

class _CurrencyMigrationDialogState extends State<CurrencyMigrationDialog> {
  bool _isMigrating = false;
  String _statusMessage = '';
  double _progress = 0;
  CurrencyMigrationResult? _result;

  Future<void> _startMigration() async {
    setState(() {
      _isMigrating = true;
      _statusMessage = 'Memulai migrasi...';
      _progress = 0;
    });

    final currencyCubit = context.read<CurrencyCubit>();
    final result = await currencyCubit.setCurrency(
      widget.toCurrency,
      onProgress: (status, progress) {
        if (mounted) {
          setState(() {
            _statusMessage = status;
            _progress = progress;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _result = result;
        _isMigrating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _buildTitle(),
      content: _buildContent(),
      actions: _buildActions(),
    );
  }

  Widget _buildTitle() {
    if (_result != null) {
      return Row(
        children: [
          Icon(
            _result!.success ? Icons.check_circle : Icons.error,
            color: _result!.success
                ? context.semantic.success
                : context.semantic.error,
          ),
          const SizedBox(width: 8),
          AppText(
            _result!.success ? 'Migrasi Berhasil' : 'Migrasi Gagal',
            style: AppTextStyle.titleMedium,
            fontWeight: FontWeight.bold,
          ),
        ],
      );
    }

    if (_isMigrating) {
      return const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          AppText(
            'Migrasi Mata Uang',
            style: AppTextStyle.titleMedium,
            fontWeight: FontWeight.bold,
          ),
        ],
      );
    }

    return const AppText(
      'Konfirmasi Perubahan',
      style: AppTextStyle.titleMedium,
      fontWeight: FontWeight.bold,
    );
  }

  Widget _buildContent() {
    final fromCurrency = Currency.getByCode(widget.fromCurrency);
    final toCurrency = Currency.getByCode(widget.toCurrency);

    if (_result != null) {
      if (_result!.success) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              'Semua data keuangan berhasil dikonversi '
              'dari ${fromCurrency.name} ke ${toCurrency.name}.',
              style: AppTextStyle.bodyMedium,
            ),
            const SizedBox(height: 16),
            _buildResultStats(),
          ],
        );
      } else {
        return AppText(
          'Terjadi kesalahan saat migrasi: ${_result!.errorMessage}',
          style: AppTextStyle.bodyMedium,
          color: context.semantic.error,
        );
      }
    }

    if (_isMigrating) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            _statusMessage,
            style: AppTextStyle.bodyMedium,
            color: context.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: _progress),
          const SizedBox(height: 8),
          AppText(
            '${(_progress * 100).toStringAsFixed(0)}%',
            style: AppTextStyle.labelMedium,
            color: context.colorScheme.outline,
          ),
        ],
      );
    }

    // * Confirmation view
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCurrencyChange(fromCurrency, toCurrency),
        const SizedBox(height: 16),
        const AppText(
          'Semua nilai aset, transaksi, dan budget akan dikonversi ke mata uang baru.',
          style: AppTextStyle.bodyMedium,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.semantic.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: context.semantic.warning.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: context.semantic.warning,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppText(
                  'Proses ini tidak dapat dibatalkan. Pastikan Anda yakin.',
                  style: AppTextStyle.bodySmall,
                  color: context.semantic.warning,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCurrencyChange(Currency from, Currency to) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            children: [
              AppText(from.symbol, style: AppTextStyle.headlineMedium),
              AppText(
                from.code.name.toUpperCase(),
                style: AppTextStyle.labelSmall,
                color: context.colorScheme.outline,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Icon(
              Icons.arrow_forward,
              color: context.colorScheme.primary,
            ),
          ),
          Column(
            children: [
              AppText(to.symbol, style: AppTextStyle.headlineMedium),
              AppText(
                to.code.name.toUpperCase(),
                style: AppTextStyle.labelSmall,
                color: context.colorScheme.outline,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultStats() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildStatRow('Aset', _result!.assetsUpdated),
          _buildStatRow('Transaksi', _result!.transactionsUpdated),
          _buildStatRow('Budget', _result!.budgetsUpdated),
          const Divider(),
          _buildStatRow('Total', _result!.totalUpdated, isBold: true),
          const SizedBox(height: 4),
          AppText(
            'Selesai dalam ${_result!.duration.inMilliseconds}ms',
            style: AppTextStyle.labelSmall,
            color: context.colorScheme.outline,
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, int count, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AppText(
            label,
            style: AppTextStyle.bodySmall,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
          AppText(
            '$count records',
            style: AppTextStyle.bodySmall,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: context.colorScheme.outline,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions() {
    if (_result != null) {
      return [
        AppButton(
          text: 'Tutup',
          variant: AppButtonVariant.filled,
          onPressed: () => Navigator.pop(context, _result!.success),
        ),
      ];
    }

    if (_isMigrating) {
      return [];
    }

    return [
      AppButton(
        text: 'Batal',
        variant: AppButtonVariant.text,
        onPressed: () => Navigator.pop(context, false),
      ),
      AppButton(
        text: 'Lanjutkan',
        variant: AppButtonVariant.filled,
        onPressed: _startMigration,
      ),
    ];
  }
}
