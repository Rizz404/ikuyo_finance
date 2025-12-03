import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/asset/models/get_assets_params.dart';
import 'package:ikuyo_finance/shared/widgets/app_button.dart';
import 'package:ikuyo_finance/shared/widgets/app_dropdown.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:ikuyo_finance/shared/widgets/app_text_field.dart';

/// * Data class untuk filter values
class AssetFilterData {
  final AssetType? type;
  final double? minBalance;
  final double? maxBalance;
  final AssetSortBy sortBy;
  final AssetSortOrder sortOrder;

  const AssetFilterData({
    this.type,
    this.minBalance,
    this.maxBalance,
    this.sortBy = AssetSortBy.createdAt,
    this.sortOrder = AssetSortOrder.descending,
  });

  /// * Get human-readable sort label
  String get sortLabel {
    final sortByLabel = switch (sortBy) {
      AssetSortBy.createdAt => 'Dibuat',
      AssetSortBy.name => 'Nama',
      AssetSortBy.balance => 'Saldo',
    };
    final orderLabel = sortOrder == AssetSortOrder.descending
        ? (sortBy == AssetSortBy.balance ? 'Terbesar' : 'Terbaru')
        : (sortBy == AssetSortBy.balance ? 'Terkecil' : 'Terlama');
    return '$sortByLabel ($orderLabel)';
  }
}

/// * Bottom sheet untuk filter aset
class AssetFilterSheet extends StatefulWidget {
  final AssetFilterData initialFilter;
  final ValueChanged<AssetFilterData> onApplyFilter;
  final VoidCallback? onReset;

  const AssetFilterSheet({
    super.key,
    required this.initialFilter,
    required this.onApplyFilter,
    this.onReset,
  });

  /// * Static method to show the filter sheet
  static Future<void> show({
    required BuildContext context,
    required AssetFilterData initialFilter,
    required ValueChanged<AssetFilterData> onApplyFilter,
    VoidCallback? onReset,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AssetFilterSheet(
        initialFilter: initialFilter,
        onApplyFilter: onApplyFilter,
        onReset: onReset,
      ),
    );
  }

  @override
  State<AssetFilterSheet> createState() => _AssetFilterSheetState();
}

class _AssetFilterSheetState extends State<AssetFilterSheet> {
  final _formKey = GlobalKey<FormBuilderState>();
  AssetType? _selectedType;
  double? _minBalance;
  double? _maxBalance;
  late AssetSortBy _sortBy;
  late AssetSortOrder _sortOrder;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialFilter.type;
    _minBalance = widget.initialFilter.minBalance;
    _maxBalance = widget.initialFilter.maxBalance;
    _sortBy = widget.initialFilter.sortBy;
    _sortOrder = widget.initialFilter.sortOrder;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: FormBuilder(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // * Handle bar
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // * Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const AppText(
                        'Filter Aset',
                        style: AppTextStyle.titleLarge,
                        fontWeight: FontWeight.bold,
                      ),
                      TextButton(
                        onPressed: _clearAllFilters,
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // * Filter options
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      // * Type filter
                      AppDropdown<AssetType>(
                        name: 'type_filter',
                        label: 'Tipe Aset',
                        hintText: 'Semua tipe',
                        initialValue: _selectedType,
                        items: const [
                          AppDropdownItem(value: AssetType.cash, label: 'Kas'),
                          AppDropdownItem(value: AssetType.bank, label: 'Bank'),
                          AppDropdownItem(
                            value: AssetType.eWallet,
                            label: 'E-Wallet',
                          ),
                          AppDropdownItem(
                            value: AssetType.stock,
                            label: 'Saham',
                          ),
                          AppDropdownItem(
                            value: AssetType.crypto,
                            label: 'Crypto',
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedType = value);
                        },
                      ),
                      const SizedBox(height: 24),
                      // * Balance range filter
                      const AppText(
                        'Rentang Saldo',
                        style: AppTextStyle.labelLarge,
                        fontWeight: FontWeight.w600,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              name: 'min_balance',
                              label: 'Min',
                              type: AppTextFieldType.number,
                              initialValue: _minBalance?.toString(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              name: 'max_balance',
                              label: 'Max',
                              type: AppTextFieldType.number,
                              initialValue: _maxBalance?.toString(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // * Sort options
                      const AppText(
                        'Urutkan',
                        style: AppTextStyle.labelLarge,
                        fontWeight: FontWeight.w600,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: AppDropdown<AssetSortBy>(
                              name: 'sort_by',
                              label: 'Berdasarkan',
                              initialValue: _sortBy,
                              items: const [
                                AppDropdownItem(
                                  value: AssetSortBy.createdAt,
                                  label: 'Dibuat',
                                ),
                                AppDropdownItem(
                                  value: AssetSortBy.name,
                                  label: 'Nama',
                                ),
                                AppDropdownItem(
                                  value: AssetSortBy.balance,
                                  label: 'Saldo',
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _sortBy = value);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppDropdown<AssetSortOrder>(
                              name: 'sort_order',
                              label: 'Urutan',
                              initialValue: _sortOrder,
                              items: const [
                                AppDropdownItem(
                                  value: AssetSortOrder.descending,
                                  label: 'Terbaru/Terbesar',
                                ),
                                AppDropdownItem(
                                  value: AssetSortOrder.ascending,
                                  label: 'Terlama/Terkecil',
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _sortOrder = value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // * Apply button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: AppButton(
                    text: 'Terapkan Filter',
                    onPressed: _applyFilters,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _clearAllFilters() {
    // * Call onReset callback to trigger bloc event
    widget.onReset?.call();
    Navigator.pop(context);
  }

  void _applyFilters() {
    final formValues = _formKey.currentState?.instantValue ?? {};

    widget.onApplyFilter(
      AssetFilterData(
        type: _selectedType,
        minBalance: double.tryParse(formValues['min_balance'] ?? ''),
        maxBalance: double.tryParse(formValues['max_balance'] ?? ''),
        sortBy: _sortBy,
        sortOrder: _sortOrder,
      ),
    );
    Navigator.pop(context);
  }
}
