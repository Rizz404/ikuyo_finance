import 'dart:io';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ikuyo_finance/core/currency/currency.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/extensions/backup_frequency_extension.dart';
import 'package:ikuyo_finance/core/extensions/theme_extension.dart';
import 'package:ikuyo_finance/core/utils/toast_helper.dart';
import 'package:ikuyo_finance/features/backup/bloc/backup_bloc.dart';
import 'package:ikuyo_finance/features/backup/models/backup_data.dart';
import 'package:ikuyo_finance/features/backup/models/backup_schedule_settings.dart';
import 'package:ikuyo_finance/features/backup/services/backup_crypto.dart';
import 'package:ikuyo_finance/features/backup/widgets/backup_passphrase_dialog.dart';
import 'package:ikuyo_finance/shared/widgets/app_button.dart';
import 'package:ikuyo_finance/shared/widgets/app_file_picker.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:ikuyo_finance/shared/widgets/screen_wrapper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  /// Pembaca file impor; dapat diganti di test
  @visibleForTesting
  static Future<Uint8List> Function(String path) importFileReader = (path) {
    // * Batas 32 MiB dicek dari panjang file sebelum dibaca (F2)
    final file = File(path);
    return BackupCrypto.readBounded(
      length: file.length,
      openRead: file.openRead,
    );
  };

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  List<PlatformFile> _importFiles = [];
  String _exportDirectory = '';
  bool _isProcessing = false;

  // * Pilihan ekspor aktif; hanya di memori layar, dibuang setelah dipakai
  BackupExportChoice? _pendingExport;

  static const _exportDirPrefKey = 'export_directory';

  @override
  void initState() {
    super.initState();
    context.read<BackupBloc>().add(BackupSummaryRequested());
    _loadExportDirectory();
  }

  Future<void> _loadExportDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_exportDirPrefKey);
    if (saved != null) {
      if (mounted) setState(() => _exportDirectory = saved);
      return;
    }
    final dir = await _resolveDefaultDirectory();
    if (mounted) setState(() => _exportDirectory = dir);
  }

  Future<String> _resolveDefaultDirectory() async {
    try {
      // * Prefer external app-specific directory (visible in file manager, no special permission needed)
      final external = await getExternalStorageDirectory();
      if (external != null) return external.path;
    } catch (_) {}
    final internal = await getApplicationDocumentsDirectory();
    return internal.path;
  }

  Future<void> _pickExportDirectory() async {
    // * On Android 11+, MANAGE_EXTERNAL_STORAGE is required to write
    // * to user-chosen directories outside the app sandbox.
    if (Platform.isAndroid) {
      final status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        final requested = await Permission.manageExternalStorage.request();
        if (!requested.isGranted && mounted) {
          ToastHelper.instance.showError(
            context: context,
            title: 'Izin diperlukan',
            description:
                'Izin akses semua file diperlukan untuk menyimpan ke direktori yang dipilih.',
          );
          return;
        }
      }
    }

    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Pilih direktori ekspor',
      initialDirectory: _exportDirectory.isNotEmpty ? _exportDirectory : null,
    );
    if (result == null || !mounted) return;

    // * Validate that the picked directory is actually writable
    final testFile = File('$result/.ikuyo_test');
    try {
      await testFile.writeAsString('');
      await testFile.delete();
    } catch (_) {
      if (!mounted) return;
      ToastHelper.instance.showError(
        context: context,
        title: 'Tidak bisa diakses',
        description: 'Direktori ini tidak dapat ditulis. Pilih direktori lain.',
      );
      return;
    }

    if (!mounted) return;
    setState(() => _exportDirectory = result);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_exportDirPrefKey, result);
  }

  Future<void> _handleExport() async {
    // * Passphrase diminta dulu; enkripsi default, plaintext hanya opt-out (A14)
    final choice = await showBackupExportDialog(context);
    if (choice == null || !mounted) return;
    _pendingExport = choice;
    // * CurrencyCubit lazy: membacanya memastikan penanda mata uang DB sudah
    // *   ditetapkan (R03) sebelum ekspor, agar backup membawa mata uangnya
    context.read<CurrencyCubit>();
    context.read<BackupBloc>().add(BackupExportRequested());
  }

  Future<void> _handleImport() async {
    if (_importFiles.isEmpty || _isProcessing) return;
    try {
      final bytes = await BackupScreen.importFileReader(
        _importFiles.first.path!,
      );

      // * Dekripsi + validasi penuh sebelum DB disentuh (A14)
      String? passphrase;
      final format = BackupCrypto.detect(bytes);
      if (format == BackupFileFormat.encrypted) {
        if (!mounted) return;
        passphrase = await showBackupImportPassphraseDialog(context);
        if (passphrase == null || !mounted) return;
      }
      setState(() => _isProcessing = true);
      final DecodedBackup decoded;
      try {
        decoded = await BackupCrypto.decodeBackup(
          bytes,
          passphrase: passphrase,
        );
      } finally {
        passphrase = null;
        if (mounted) setState(() => _isProcessing = false);
      }

      if (!mounted) return;
      // * Metadata mata uang yang tidak didukung ditolak sebelum konfirmasi
      final currency = decoded.data.currency;
      if (currency != null && !currency.isSupported) {
        ToastHelper.instance.showError(
          context: context,
          title: LocaleKeys.backupScreenError.tr(),
          description: LocaleKeys.backupScreenCurrencyUnsupported.tr(
            namedArgs: {'code': currency.code},
          ),
        );
        return;
      }
      final toImport = await _showImportConfirmDialog(
        decoded.data,
        legacyPlaintext: !decoded.wasEncrypted,
      );

      if (toImport != null && mounted) {
        context.read<BackupBloc>().add(BackupImportRequested(toImport));
      }
    } on BackupCryptoException catch (e) {
      if (!mounted) return;
      ToastHelper.instance.showError(
        context: context,
        title: LocaleKeys.backupScreenError.tr(),
        description: backupCryptoErrorMessage(e.error),
      );
    } catch (e) {
      if (!mounted) return;
      ToastHelper.instance.showError(
        context: context,
        title: LocaleKeys.backupScreenError.tr(),
        description: LocaleKeys.backupScreenReadBackupFailed.tr(
          namedArgs: {'error': e.toString()},
        ),
      );
    }
  }

  /// Mengembalikan data yang akan diimpor, atau null bila dibatalkan.
  /// * Backup tanpa metadata mata uang: pengguna wajib memilih mata uang
  ///   backup secara eksplisit; tidak ditebak dari mata uang DB saat ini
  Future<BackupData?> _showImportConfirmDialog(
    BackupData backupData, {
    bool legacyPlaintext = false,
  }) {
    final needsCurrency = backupData.currency == null;
    CurrencyCode? declared;
    return showDialog<BackupData>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: AppText(
            LocaleKeys.backupScreenImportConfirmTitle.tr(),
            style: AppTextStyle.titleLarge,
            fontWeight: FontWeight.bold,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                LocaleKeys.backupScreenImportDataLabel.tr(),
                style: AppTextStyle.bodyMedium,
              ),
              if (legacyPlaintext) ...[
                const SizedBox(height: 8),
                AppText(
                  LocaleKeys.backupEncryptionLegacyWarning.tr(),
                  key: const Key('backup_legacy_warning'),
                  style: AppTextStyle.bodySmall,
                  color: context.semantic.warning,
                ),
              ],
              if (needsCurrency) ...[
                const SizedBox(height: 8),
                AppText(
                  LocaleKeys.backupScreenCurrencyLegacyWarning.tr(),
                  style: AppTextStyle.bodySmall,
                  color: context.semantic.warning,
                ),
                DropdownButton<CurrencyCode>(
                  key: const Key('backup_currency_picker'),
                  isExpanded: true,
                  value: declared,
                  hint: Text(LocaleKeys.backupScreenCurrencyPickLabel.tr()),
                  items: [
                    for (final code in CurrencyCode.values)
                      DropdownMenuItem(
                        value: code,
                        child: Text(Currency.getByCode(code).name),
                      ),
                  ],
                  onChanged: (code) => setDialogState(() => declared = code),
                ),
              ],
              const SizedBox(height: 12),
              _buildSummaryItem(
                LocaleKeys.backupScreenCategories.tr(),
                backupData.categories.length,
                context,
              ),
              _buildSummaryItem(
                LocaleKeys.backupScreenAssets.tr(),
                backupData.assets.length,
                context,
              ),
              _buildSummaryItem(
                LocaleKeys.backupScreenTransactions.tr(),
                backupData.transactions.length,
                context,
              ),
              _buildSummaryItem(
                LocaleKeys.backupScreenBudgets.tr(),
                backupData.budgets.length,
                context,
              ),
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
                        LocaleKeys.backupScreenImportWarning.tr(),
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
              onPressed: () => Navigator.pop(context),
              child: Text(LocaleKeys.backupScreenImportCancel.tr()),
            ),
            FilledButton(
              onPressed: needsCurrency && declared == null
                  ? null
                  : () => Navigator.pop(
                      context,
                      needsCurrency
                          ? backupData.withCurrency(
                              BackupCurrency.of(declared!),
                            )
                          : backupData,
                    ),
              style: FilledButton.styleFrom(
                backgroundColor: context.semantic.error,
              ),
              child: Text(LocaleKeys.backupScreenImportConfirmButton.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveExportedFile(BackupData backupData) async {
    final choice = _pendingExport;
    _pendingExport = null;
    if (choice == null) return;
    setState(() => _isProcessing = true);
    final Uint8List bytes;
    try {
      bytes = await BackupCrypto.encodeBackup(
        backupData,
        passphrase: choice.passphrase,
      );
    } on BackupCryptoException catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ToastHelper.instance.showError(
          context: context,
          title: LocaleKeys.backupScreenError.tr(),
          description: backupCryptoErrorMessage(e.error),
        );
      }
      return;
    }
    if (mounted) setState(() => _isProcessing = false);
    final extension = choice.encrypted ? BackupCrypto.fileExtension : 'json';
    try {
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'ikuyo_backup_$timestamp.$extension';

      // * Ensure the target directory exists
      final dir = Directory(_exportDirectory);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final filePath = '$_exportDirectory/$fileName';
      await File(filePath).writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      ToastHelper.instance.showSuccess(
        context: context,
        title: LocaleKeys.backupScreenSuccess.tr(),
        description: LocaleKeys.backupScreenBackupSavedTo.tr(
          namedArgs: {'path': filePath},
        ),
      );
    } catch (e) {
      // * If the selected directory is not writable, fall back to internal storage
      try {
        final fallbackDir = await getApplicationDocumentsDirectory();
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final fileName = 'ikuyo_backup_$timestamp.$extension';
        final filePath = '${fallbackDir.path}/$fileName';
        await File(filePath).writeAsBytes(bytes, flush: true);

        if (!mounted) return;
        // * Reset saved directory to fallback so next export works
        setState(() => _exportDirectory = fallbackDir.path);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_exportDirPrefKey, fallbackDir.path);

        if (!mounted) return;
        ToastHelper.instance.showSuccess(
          context: context,
          title: LocaleKeys.backupScreenSuccess.tr(),
          description: LocaleKeys.backupScreenBackupSavedTo.tr(
            namedArgs: {'path': filePath},
          ),
        );
      } catch (fallbackError) {
        if (!mounted) return;
        ToastHelper.instance.showError(
          context: context,
          title: LocaleKeys.backupScreenError.tr(),
          description: LocaleKeys.backupScreenSaveFileFailed.tr(
            namedArgs: {'error': fallbackError.toString()},
          ),
        );
      }
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
      // * Hanya bereaksi pada transisi status, bukan setiap emit (BKSEC-5)
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == BackupStatus.success) {
          if (state.exportedData != null) {
            // * Export success - save file
            _saveExportedFile(state.exportedData!);
          } else if (state.isImport) {
            // * Import success - reset selected file
            setState(() => _importFiles = []);
            // * Penanda mata uang sudah commit bersama data; selaraskan cubit
            context.read<CurrencyCubit>().reloadFromStore();
            ToastHelper.instance.showSuccess(
              context: context,
              title: LocaleKeys.backupScreenSuccess.tr(),
              description:
                  state.message ?? LocaleKeys.backupScreenImportSuccess.tr(),
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
            title: LocaleKeys.backupScreenError.tr(),
            description:
                state.message ?? LocaleKeys.backupScreenErrorOccurred.tr(),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: AppText(
            LocaleKeys.backupScreenTitle.tr(),
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
                          LocaleKeys.backupScreenInfoDescription.tr(),
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
                  LocaleKeys.backupScreenCurrentData.tr(),
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
                            LocaleKeys.backupScreenCategories.tr(),
                            summary?['categories'] ?? 0,
                            Icons.category_outlined,
                          ),
                          const Divider(height: 24),
                          _buildDataRow(
                            LocaleKeys.backupScreenAssets.tr(),
                            summary?['assets'] ?? 0,
                            Icons.account_balance_wallet_outlined,
                          ),
                          const Divider(height: 24),
                          _buildDataRow(
                            LocaleKeys.backupScreenTransactions.tr(),
                            summary?['transactions'] ?? 0,
                            Icons.receipt_long_outlined,
                          ),
                          const Divider(height: 24),
                          _buildDataRow(
                            LocaleKeys.backupScreenBudgets.tr(),
                            summary?['budgets'] ?? 0,
                            Icons.savings_outlined,
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              AppText(
                                LocaleKeys.backupScreenTotal.tr(),
                                style: AppTextStyle.titleSmall,
                                fontWeight: FontWeight.bold,
                              ),
                              AppText(
                                LocaleKeys.backupScreenTotalItems.tr(
                                  namedArgs: {'count': '${state.totalItems}'},
                                ),
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
                _buildExportCard(),
                const SizedBox(height: 16),

                // * Import Section
                _buildImportCard(),
                const SizedBox(height: 24),

                // * Auto Backup Schedule Section
                _buildScheduleCard(),
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

  Widget _buildImportCard() {
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
                  color: context.semantic.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.cloud_download_outlined,
                  color: context.semantic.warning,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppText(
                  LocaleKeys.backupScreenImportTitle.tr(),
                  style: AppTextStyle.titleSmall,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppText(
            LocaleKeys.backupScreenImportDescription.tr(),
            style: AppTextStyle.bodySmall,
            color: colors.textSecondary,
          ),
          const SizedBox(height: 16),
          AppFilePicker(
            name: 'import_backup',
            // * .ikuyo tidak dikenal MimeTypeMap Android → picker jatuh ke */*;
            //   format diverifikasi dari isi file, bukan ekstensi
            fileType: FileType.custom,
            allowedExtensions: const [BackupCrypto.fileExtension, 'json'],
            maxFiles: 1,
            hintText: LocaleKeys.backupEncryptionPickerHint.tr(),
            onChanged: (files) => setState(() => _importFiles = files ?? []),
          ),
          const SizedBox(height: 12),
          BlocBuilder<BackupBloc, BackupState>(
            builder: (context, state) {
              return AppButton(
                text: LocaleKeys.backupScreenImportButton.tr(),
                color: AppButtonColor.secondary,
                isLoading:
                    state.status == BackupStatus.loading || _isProcessing,
                onPressed:
                    (state.status == BackupStatus.loading ||
                        _isProcessing ||
                        _importFiles.isEmpty)
                    ? null
                    : _handleImport,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExportCard() {
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
                  color: colors.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.cloud_upload_outlined,
                  color: colors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppText(
                  LocaleKeys.backupScreenExportTitle.tr(),
                  style: AppTextStyle.titleSmall,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppText(
            LocaleKeys.backupScreenExportDescription.tr(),
            style: AppTextStyle.bodySmall,
            color: colors.textSecondary,
          ),
          const SizedBox(height: 16),
          // * Directory picker
          AppText(
            'Simpan ke direktori',
            style: AppTextStyle.bodySmall,
            color: colors.textSecondary,
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: _pickExportDirectory,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.border.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.folder_outlined, size: 18, color: colors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppText(
                      _exportDirectory.isEmpty
                          ? 'Pilih direktori...'
                          : _exportDirectory,
                      style: AppTextStyle.bodySmall,
                      color: _exportDirectory.isEmpty
                          ? colors.textSecondary
                          : colors.textPrimary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: colors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          BlocBuilder<BackupBloc, BackupState>(
            builder: (context, state) {
              return AppButton(
                text: LocaleKeys.backupScreenExportButton.tr(),
                color: AppButtonColor.primary,
                isLoading:
                    state.status == BackupStatus.loading || _isProcessing,
                onPressed:
                    (state.status == BackupStatus.loading ||
                        _isProcessing ||
                        _exportDirectory.isEmpty)
                    ? null
                    : _handleExport,
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handlePickTime(BackupScheduleSettings current) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked != null && mounted) {
      context.read<BackupBloc>().add(
        BackupScheduleTimeChanged(hour: picked.hour, minute: picked.minute),
      );
    }
  }

  Widget _buildScheduleCard() {
    final colors = context.colors;

    return BlocBuilder<BackupBloc, BackupState>(
      buildWhen: (previous, current) => previous.schedule != current.schedule,
      builder: (context, state) {
        final schedule = state.schedule;

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
              // * Header + toggle
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.schedule_rounded,
                      color: colors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          LocaleKeys.backupScreenAutoTitle.tr(),
                          style: AppTextStyle.titleSmall,
                          fontWeight: FontWeight.bold,
                        ),
                        AppText(
                          LocaleKeys.backupScreenAutoDescription.tr(),
                          style: AppTextStyle.bodySmall,
                          color: colors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: schedule.isEnabled,
                    onChanged: (v) => context.read<BackupBloc>().add(
                      BackupScheduleToggled(v),
                    ),
                  ),
                ],
              ),

              if (schedule.isEnabled) ...[
                const Divider(height: 28),

                // * Time picker row
                InkWell(
                  onTap: () => _handlePickTime(schedule),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 18,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppText(
                            LocaleKeys.backupScreenAutoTime.tr(),
                            style: AppTextStyle.bodyMedium,
                          ),
                        ),
                        AppText(
                          schedule.formattedTime,
                          style: AppTextStyle.bodyMedium,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: colors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // * Frequency selector
                AppText(
                  LocaleKeys.backupScreenAutoFrequency.tr(),
                  style: AppTextStyle.bodySmall,
                  color: colors.textSecondary,
                ),
                const SizedBox(height: 8),
                _buildFrequencyChips(schedule),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFrequencyChips(BackupScheduleSettings schedule) {
    return Wrap(
      spacing: 8,
      children: BackupFrequency.values.map((freq) {
        final isSelected = schedule.frequency == freq;
        return ChoiceChip(
          label: Text(freq.label),
          selected: isSelected,
          onSelected: (_) => context.read<BackupBloc>().add(
            BackupScheduleFrequencyChanged(freq),
          ),
          selectedColor: context.colorScheme.primary,
          labelStyle: TextStyle(
            color: isSelected
                ? context.colorScheme.onPrimary
                : context.colors.textPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        );
      }).toList(),
    );
  }
}
