import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/core/utils/toast_helper.dart';
import 'package:ikuyo_finance/features/backup/bloc/backup_bloc.dart';
import 'package:ikuyo_finance/features/backup/models/backup_data.dart';
import 'package:ikuyo_finance/shared/widgets/app_button.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:ikuyo_finance/shared/widgets/screen_wrapper.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  @override
  void initState() {
    super.initState();
    context.read<BackupBloc>().add(BackupSummaryRequested());
  }

  Future<void> _handleExport() async {
    // * Request export dari bloc
    context.read<BackupBloc>().add(BackupExportRequested());
  }

  Future<void> _handleImport() async {
    try {
      // * Pick JSON file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();

      // * Parse backup data
      final backupData = BackupData.fromJsonString(jsonString);

      // * Show confirmation dialog
      if (!mounted) return;
      final confirmed = await _showImportConfirmDialog(backupData);

      if (confirmed == true && mounted) {
        context.read<BackupBloc>().add(BackupImportRequested(backupData));
      }
    } catch (e) {
      if (!mounted) return;
      ToastHelper.instance.showError(
        context: context,
        title: 'Error',
        description: 'Gagal membaca file backup: ${e.toString()}',
      );
    }
  }

  Future<bool?> _showImportConfirmDialog(BackupData backupData) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText(
          'Konfirmasi Import',
          style: AppTextStyle.titleLarge,
          fontWeight: FontWeight.bold,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText(
              'Data yang akan diimport:',
              style: AppTextStyle.bodyMedium,
            ),
            const SizedBox(height: 12),
            _buildSummaryItem(
              'Kategori',
              backupData.categories.length,
              context,
            ),
            _buildSummaryItem('Aset', backupData.assets.length, context),
            _buildSummaryItem(
              'Transaksi',
              backupData.transactions.length,
              context,
            ),
            _buildSummaryItem('Budget', backupData.budgets.length, context),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.semantic.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.semantic.warning),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: context.semantic.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppText(
                      'Semua data yang ada saat ini akan dihapus dan diganti dengan data backup!',
                      style: AppTextStyle.bodySmall,
                      color: context.semantic.warning,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: context.semantic.error,
            ),
            child: const Text('Import & Ganti Data'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveExportedFile(BackupData backupData) async {
    try {
      // * Generate filename with timestamp
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'ikuyo_backup_$timestamp.json';

      // * Get directory untuk save
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';

      // * Write file
      final file = File(filePath);
      await file.writeAsString(backupData.toJsonString());

      // * Let user choose where to save using file_picker
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Simpan File Backup',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: file.readAsBytesSync(),
      );

      if (!mounted) return;

      if (result != null) {
        ToastHelper.instance.showSuccess(
          context: context,
          title: 'Berhasil',
          description: 'Backup disimpan ke: $result',
        );
      }

      // * Clean temp file
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      if (!mounted) return;
      ToastHelper.instance.showError(
        context: context,
        title: 'Error',
        description: 'Gagal menyimpan file: ${e.toString()}',
      );
    }
  }

  Widget _buildSummaryItem(String label, int count, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AppText(label, style: AppTextStyle.bodyMedium),
          AppText(
            count.toString(),
            style: AppTextStyle.bodyMedium,
            fontWeight: FontWeight.bold,
            color: context.colorScheme.primary,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return BlocListener<BackupBloc, BackupState>(
      listener: (context, state) {
        if (state.status == BackupStatus.success) {
          if (state.exportedData != null) {
            // * Export success - save file
            _saveExportedFile(state.exportedData!);
          } else {
            // * Import success
            ToastHelper.instance.showSuccess(
              context: context,
              title: 'Berhasil',
              description: state.message ?? 'Data berhasil diimpor',
            );
            // * Refresh summary
            context.read<BackupBloc>().add(BackupSummaryRequested());
            // * Navigate back - check if can pop first
            if (context.canPop()) {
              context.pop();
            } else {
              // * If can't pop (root route), go to main screen
              context.go('/');
            }
          }
        } else if (state.status == BackupStatus.failure) {
          ToastHelper.instance.showError(
            context: context,
            title: 'Error',
            description: state.message ?? 'Terjadi kesalahan',
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const AppText(
            'Cadangan Data',
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
                // * Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: colors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppText(
                          'Backup data disimpan dalam format JSON yang bisa diimpor kembali kapan saja.',
                          style: AppTextStyle.bodySmall,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // * Current Data Summary
                AppText(
                  'Data Saat Ini',
                  style: AppTextStyle.titleMedium,
                  fontWeight: FontWeight.bold,
                ),
                const SizedBox(height: 12),
                BlocBuilder<BackupBloc, BackupState>(
                  builder: (context, state) {
                    final summary = state.summary;
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colors.border.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildDataRow(
                            'Kategori',
                            summary?['categories'] ?? 0,
                            Icons.category_outlined,
                          ),
                          const Divider(height: 24),
                          _buildDataRow(
                            'Aset',
                            summary?['assets'] ?? 0,
                            Icons.account_balance_wallet_outlined,
                          ),
                          const Divider(height: 24),
                          _buildDataRow(
                            'Transaksi',
                            summary?['transactions'] ?? 0,
                            Icons.receipt_long_outlined,
                          ),
                          const Divider(height: 24),
                          _buildDataRow(
                            'Budget',
                            summary?['budgets'] ?? 0,
                            Icons.savings_outlined,
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              AppText(
                                'Total',
                                style: AppTextStyle.titleSmall,
                                fontWeight: FontWeight.bold,
                              ),
                              AppText(
                                '${state.totalItems} item',
                                style: AppTextStyle.titleSmall,
                                fontWeight: FontWeight.bold,
                                color: colors.primary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // * Export Section
                _buildActionCard(
                  icon: Icons.cloud_upload_outlined,
                  title: 'Export Data',
                  description:
                      'Simpan semua data ke file JSON yang bisa disimpan di penyimpanan perangkat.',
                  buttonText: 'Export Sekarang',
                  buttonColor: AppButtonColor.primary,
                  onPressed: _handleExport,
                ),
                const SizedBox(height: 16),

                // * Import Section
                _buildActionCard(
                  icon: Icons.cloud_download_outlined,
                  title: 'Import Data',
                  description:
                      'Pulihkan data dari file backup JSON. Data yang ada saat ini akan diganti.',
                  buttonText: 'Pilih File Backup',
                  buttonColor: AppButtonColor.secondary,
                  onPressed: _handleImport,
                  isWarning: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, int count, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: context.colors.textSecondary),
        const SizedBox(width: 12),
        Expanded(child: AppText(label, style: AppTextStyle.bodyMedium)),
        AppText(
          count.toString(),
          style: AppTextStyle.bodyMedium,
          fontWeight: FontWeight.bold,
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String description,
    required String buttonText,
    required AppButtonColor buttonColor,
    required VoidCallback onPressed,
    bool isWarning = false,
  }) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isWarning
                      ? context.semantic.warning.withValues(alpha: 0.1)
                      : colors.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isWarning ? context.semantic.warning : colors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      title,
                      style: AppTextStyle.titleSmall,
                      fontWeight: FontWeight.bold,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppText(
            description,
            style: AppTextStyle.bodySmall,
            color: colors.textSecondary,
          ),
          const SizedBox(height: 16),
          BlocBuilder<BackupBloc, BackupState>(
            builder: (context, state) {
              return AppButton(
                text: buttonText,
                color: buttonColor,
                isLoading: state.status == BackupStatus.loading,
                onPressed: state.status == BackupStatus.loading
                    ? null
                    : onPressed,
              );
            },
          ),
        ],
      ),
    );
  }
}
