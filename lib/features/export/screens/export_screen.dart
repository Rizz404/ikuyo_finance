import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/extensions/currency_extension.dart';
import 'package:ikuyo_finance/core/extensions/theme_extension.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/theme/app_colors.dart';
import 'package:ikuyo_finance/core/utils/toast_helper.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/export/bloc/export_bloc.dart';
import 'package:ikuyo_finance/features/export/models/export_params.dart';
import 'package:ikuyo_finance/shared/widgets/app_button.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:ikuyo_finance/shared/widgets/screen_wrapper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _exportDirectory = '';

  // * Set ULID asset/category yang DIKELUARKAN
  final Set<String> _excludedAssetUlids = {};
  final Set<String> _excludedCategoryUlids = {};

  static const _exportDirPrefKey = 'export_excel_directory';

  @override
  void initState() {
    super.initState();
    context.read<ExportBloc>()
      ..add(ExportAssetsLoaded())
      ..add(ExportCategoriesLoaded());
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
      final external = await getExternalStorageDirectory();
      if (external != null) return external.path;
    } catch (_) {}
    final internal = await getApplicationDocumentsDirectory();
    return internal.path;
  }

  Future<void> _pickExportDirectory() async {
    if (Platform.isAndroid) {
      final status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        final requested = await Permission.manageExternalStorage.request();
        if (!requested.isGranted && mounted) {
          ToastHelper.instance.showError(
            context: context,
            title: LocaleKeys.exportScreenDirectoryPermissionRequired.tr(),
            description: LocaleKeys.exportScreenDirectoryPermissionDesc.tr(),
          );
          return;
        }
      }
    }

    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: LocaleKeys.exportScreenSaveToDirectory.tr(),
      initialDirectory: _exportDirectory.isNotEmpty ? _exportDirectory : null,
    );
    if (result == null || !mounted) return;

    final testFile = File('$result/.ikuyo_test');
    try {
      await testFile.writeAsString('');
      await testFile.delete();
    } catch (_) {
      if (!mounted) return;
      ToastHelper.instance.showError(
        context: context,
        title: LocaleKeys.exportScreenDirectoryNotWritable.tr(),
        description: LocaleKeys.exportScreenDirectoryNotWritableDesc.tr(),
      );
      return;
    }

    setState(() => _exportDirectory = result);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_exportDirPrefKey, result);
  }

  void _handleExport() {
    // * Kumpulkan localized labels untuk column headers di Excel
    final labels = _buildLabels();

    context.read<ExportBloc>().add(
      ExportExcelRequested(
        params: ExportParams(
          startDate: _startDate,
          endDate: _endDate,
          excludedAssetUlids: _excludedAssetUlids.toList(),
          excludedCategoryUlids: _excludedCategoryUlids.toList(),
        ),
        exportDirectory: _exportDirectory,
        labels: labels,
        currencySymbol: context.currencySymbol,
      ),
    );
  }

  Map<String, String> _buildLabels() {
    return {
      'sheet.transactions': LocaleKeys.exportExcelSheetTransactions.tr(),
      'sheet.assets': LocaleKeys.exportExcelSheetAssets.tr(),
      'sheet.categories': LocaleKeys.exportExcelSheetCategories.tr(),
      'col.no': LocaleKeys.exportExcelColNo.tr(),
      'col.date': LocaleKeys.exportExcelColDate.tr(),
      'col.asset': LocaleKeys.exportExcelColAsset.tr(),
      'col.assetType': LocaleKeys.exportExcelColAssetType.tr(),
      'col.category': LocaleKeys.exportExcelColCategory.tr(),
      'col.categoryType': LocaleKeys.exportExcelColCategoryType.tr(),
      'col.parentCategory': LocaleKeys.exportExcelColParentCategory.tr(),
      'col.amount': LocaleKeys.exportExcelColAmount.tr(),
      'col.description': LocaleKeys.exportExcelColDescription.tr(),
      'col.createdAt': LocaleKeys.exportExcelColCreatedAt.tr(),
      'col.name': LocaleKeys.exportExcelColName.tr(),
      'col.type': LocaleKeys.exportExcelColType.tr(),
      'col.balance': LocaleKeys.exportExcelColBalance.tr(),
      'col.icon': LocaleKeys.exportExcelColIcon.tr(),
      'col.color': LocaleKeys.exportExcelColColor.tr(),
      'summary.totalIncome': LocaleKeys.exportExcelSummaryTotalIncome.tr(),
      'summary.totalExpense': LocaleKeys.exportExcelSummaryTotalExpense.tr(),
      'summary.net': LocaleKeys.exportExcelSummaryNet.tr(),
      'summary.totalBalance': LocaleKeys.exportExcelSummaryTotalBalance.tr(),
      'assetType.cash': LocaleKeys.exportExcelAssetTypeCash.tr(),
      'assetType.bank': LocaleKeys.exportExcelAssetTypeBank.tr(),
      'assetType.eWallet': LocaleKeys.exportExcelAssetTypeEWallet.tr(),
      'assetType.stock': LocaleKeys.exportExcelAssetTypeStock.tr(),
      'assetType.crypto': LocaleKeys.exportExcelAssetTypeCrypto.tr(),
      'categoryType.income': LocaleKeys.exportExcelCategoryTypeIncome.tr(),
      'categoryType.expense': LocaleKeys.exportExcelCategoryTypeExpense.tr(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExportBloc, ExportState>(
      listener: (context, state) {
        if (state.status == ExportStatus.success && state.savedPath != null) {
          ToastHelper.instance.showSuccess(
            context: context,
            title: LocaleKeys.exportScreenExportSuccess.tr(),
            description: LocaleKeys.exportScreenExportSuccessDesc.tr(
              namedArgs: {'path': state.savedPath!},
            ),
          );
        } else if (state.status == ExportStatus.failure) {
          ToastHelper.instance.showError(
            context: context,
            title: LocaleKeys.exportScreenExportError.tr(),
            description: state.message ?? '',
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: AppText(
            LocaleKeys.exportScreenTitle.tr(),
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
                _buildInfoCard(),
                const SizedBox(height: 24),
                _buildDateRangeSection(),
                const SizedBox(height: 16),
                _buildDirectorySection(),
                const SizedBox(height: 16),
                _buildAssetFilterSection(),
                const SizedBox(height: 16),
                _buildCategoryFilterSection(),
                const SizedBox(height: 24),
                _buildExportButton(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: colors.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: AppText(
              LocaleKeys.exportScreenInfoDescription.tr(),
              style: AppTextStyle.bodySmall,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeSection() {
    final colors = context.colors;
    final dateFormat = DateFormat('dd MMM yyyy');
    return _buildSectionCard(
      title: LocaleKeys.exportScreenDateRange.tr(),
      icon: Icons.date_range_outlined,
      child: Column(
        children: [
          _DatePickerField(
            label: LocaleKeys.exportScreenStartDate.tr(),
            value: _startDate,
            dateFormat: dateFormat,
            colors: colors,
            onPicked: (date) => setState(() => _startDate = date),
          ),
          const SizedBox(height: 12),
          _DatePickerField(
            label: LocaleKeys.exportScreenEndDate.tr(),
            value: _endDate,
            dateFormat: dateFormat,
            colors: colors,
            onPicked: (date) => setState(() => _endDate = date),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectorySection() {
    final colors = context.colors;
    return _buildSectionCard(
      title: LocaleKeys.exportScreenSaveToDirectory.tr(),
      icon: Icons.folder_outlined,
      child: InkWell(
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
                      ? LocaleKeys.exportScreenPickDirectory.tr()
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
              Icon(Icons.edit_outlined, size: 16, color: colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssetFilterSection() {
    return BlocBuilder<ExportBloc, ExportState>(
      buildWhen: (prev, curr) => prev.assets != curr.assets,
      builder: (context, state) {
        final assets = state.assets;
        return _buildSectionCard(
          title: LocaleKeys.exportScreenFilterAssets.tr(),
          icon: Icons.account_balance_wallet_outlined,
          headerTrailing: _buildSelectAllRow(
            allUlids: assets.map((a) => a.ulid).toSet(),
            excludedUlids: _excludedAssetUlids,
            onSelectAll: () =>
                setState(() => _excludedAssetUlids.clear()),
            onDeselectAll: () => setState(
              () => _excludedAssetUlids
                ..clear()
                ..addAll(assets.map((a) => a.ulid)),
            ),
          ),
          child: Column(
            children: [
              AppText(
                LocaleKeys.exportScreenFilterAssetHint.tr(),
                style: AppTextStyle.bodySmall,
                color: context.colors.textSecondary,
              ),
              const SizedBox(height: 8),
              ...assets.map((asset) => _buildAssetCheckItem(asset)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryFilterSection() {
    return BlocBuilder<ExportBloc, ExportState>(
      buildWhen: (prev, curr) => prev.categories != curr.categories,
      builder: (context, state) {
        final categories = state.categories;
        return _buildSectionCard(
          title: LocaleKeys.exportScreenFilterCategories.tr(),
          icon: Icons.category_outlined,
          headerTrailing: _buildSelectAllRow(
            allUlids: categories.map((c) => c.ulid).toSet(),
            excludedUlids: _excludedCategoryUlids,
            onSelectAll: () =>
                setState(() => _excludedCategoryUlids.clear()),
            onDeselectAll: () => setState(
              () => _excludedCategoryUlids
                ..clear()
                ..addAll(categories.map((c) => c.ulid)),
            ),
          ),
          child: Column(
            children: [
              AppText(
                LocaleKeys.exportScreenFilterCategoryHint.tr(),
                style: AppTextStyle.bodySmall,
                color: context.colors.textSecondary,
              ),
              const SizedBox(height: 8),
              ...categories.map((cat) => _buildCategoryCheckItem(cat)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAssetCheckItem(Asset asset) {
    final isIncluded = !_excludedAssetUlids.contains(asset.ulid);
    return CheckboxListTile(
      value: isIncluded,
      onChanged: (checked) {
        setState(() {
          if (checked == true) {
            _excludedAssetUlids.remove(asset.ulid);
          } else {
            _excludedAssetUlids.add(asset.ulid);
          }
        });
      },
      title: AppText(asset.name, style: AppTextStyle.bodyMedium),
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildCategoryCheckItem(Category category) {
    final isIncluded = !_excludedCategoryUlids.contains(category.ulid);
    return CheckboxListTile(
      value: isIncluded,
      onChanged: (checked) {
        setState(() {
          if (checked == true) {
            _excludedCategoryUlids.remove(category.ulid);
          } else {
            _excludedCategoryUlids.add(category.ulid);
          }
        });
      },
      title: Row(
        children: [
          Expanded(
            child: AppText(category.name, style: AppTextStyle.bodyMedium),
          ),
          if (category.parent.target != null)
            AppText(
              '← ${category.parent.target!.name}',
              style: AppTextStyle.bodySmall,
              color: context.colors.textSecondary,
            ),
        ],
      ),
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildSelectAllRow({
    required Set<String> allUlids,
    required Set<String> excludedUlids,
    required VoidCallback onSelectAll,
    required VoidCallback onDeselectAll,
  }) {
    final allSelected = excludedUlids.isEmpty;
    return TextButton(
      onPressed: allSelected ? onDeselectAll : onSelectAll,
      child: AppText(
        allSelected
            ? LocaleKeys.exportScreenDeselectAll.tr()
            : LocaleKeys.exportScreenSelectAll.tr(),
        style: AppTextStyle.bodySmall,
        color: context.colorScheme.primary,
      ),
    );
  }

  Widget _buildExportButton() {
    return BlocBuilder<ExportBloc, ExportState>(
      builder: (context, state) {
        return AppButton(
          text: LocaleKeys.exportScreenExportButton.tr(),
          color: AppButtonColor.primary,
          isLoading: state.status == ExportStatus.loading,
          onPressed:
              (state.status == ExportStatus.loading ||
                  _exportDirectory.isEmpty)
              ? null
              : _handleExport,
        );
      },
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? headerTrailing,
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: colors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppText(
                  title,
                  style: AppTextStyle.titleSmall,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (headerTrailing != null) headerTrailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// * Tier 2: independent props + lifecycle → private class
class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final DateFormat dateFormat;
  final AppColorsTheme colors;
  final ValueChanged<DateTime?> onPicked;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.dateFormat,
    required this.colors,
    required this.onPicked,
  });

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: colors.primaryContainer.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.border.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: colors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppText(
                value != null ? dateFormat.format(value!) : label,
                style: AppTextStyle.bodyMedium,
                color: value != null ? colors.textPrimary : colors.textSecondary,
              ),
            ),
            if (value != null)
              GestureDetector(
                onTap: () => onPicked(null),
                child: Icon(
                  Icons.clear,
                  size: 16,
                  color: colors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
