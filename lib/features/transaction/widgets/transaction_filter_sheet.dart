import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/transaction/models/get_transactions_params.dart';
import 'package:ikuyo_finance/shared/widgets/app_button.dart';
import 'package:ikuyo_finance/shared/widgets/app_date_time_picker.dart';
import 'package:ikuyo_finance/shared/widgets/app_dropdown.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:ikuyo_finance/shared/widgets/app_text_field.dart';

/// * Data class untuk filter values
class TransactionFilterData {
  final String? assetUlid;
  final String? categoryUlid;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? minAmount;
  final double? maxAmount;
  final TransactionSortBy sortBy;
  final SortOrder sortOrder;

  const TransactionFilterData({
    this.assetUlid,
    this.categoryUlid,
    this.startDate,
    this.endDate,
    this.minAmount,
    this.maxAmount,
    this.sortBy = TransactionSortBy.transactionDate,
    this.sortOrder = SortOrder.descending,
  });

  /// * Get human-readable sort label
  String get sortLabel {
    final sortByLabel = switch (sortBy) {
      TransactionSortBy.transactionDate => 'Tanggal',
      TransactionSortBy.amount => 'Jumlah',
      TransactionSortBy.createdAt => 'Dibuat',
    };
    final orderLabel = sortOrder == SortOrder.descending
        ? (sortBy == TransactionSortBy.amount ? 'Terbesar' : 'Terbaru')
        : (sortBy == TransactionSortBy.amount ? 'Terkecil' : 'Terlama');
    return '$sortByLabel ($orderLabel)';
  }
}

/// * Bottom sheet untuk filter transaksi (pure UI, no bloc logic)
class TransactionFilterSheet extends StatefulWidget {
  final List<Asset> assets;
  final List<Category> categories;
  final TransactionFilterData initialFilter;
  final ValueChanged<TransactionFilterData> onApplyFilter;
  final VoidCallback? onReset;

  const TransactionFilterSheet({
    super.key,
    required this.assets,
    required this.categories,
    required this.initialFilter,
    required this.onApplyFilter,
    this.onReset,
  });

  /// * Static method to show the filter sheet
  static Future<void> show({
    required BuildContext context,
    required List<Asset> assets,
    required List<Category> categories,
    required TransactionFilterData initialFilter,
    required ValueChanged<TransactionFilterData> onApplyFilter,
    VoidCallback? onReset,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TransactionFilterSheet(
        assets: assets,
        categories: categories,
        initialFilter: initialFilter,
        onApplyFilter: onApplyFilter,
        onReset: onReset,
      ),
    );
  }

  @override
  State<TransactionFilterSheet> createState() => _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends State<TransactionFilterSheet> {
  final _formKey = GlobalKey<FormBuilderState>();
  String? _selectedAssetUlid;
  String? _selectedCategoryUlid;
  DateTime? _startDate;
  DateTime? _endDate;
  double? _minAmount;
  double? _maxAmount;
  late TransactionSortBy _sortBy;
  late SortOrder _sortOrder;

  @override
  void initState() {
    super.initState();
    // * Validate assetUlid exists in items list
    final assetExists = widget.assets.any(
      (a) => a.ulid == widget.initialFilter.assetUlid,
    );
    _selectedAssetUlid = assetExists ? widget.initialFilter.assetUlid : null;
    // * Validate categoryUlid exists in items list
    final categoryExists = widget.categories.any(
      (c) => c.ulid == widget.initialFilter.categoryUlid,
    );
    _selectedCategoryUlid = categoryExists
        ? widget.initialFilter.categoryUlid
        : null;
    _startDate = widget.initialFilter.startDate;
    _endDate = widget.initialFilter.endDate;
    _minAmount = widget.initialFilter.minAmount;
    _maxAmount = widget.initialFilter.maxAmount;
    _sortBy = widget.initialFilter.sortBy;
    _sortOrder = widget.initialFilter.sortOrder;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
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
                        'Filter Transaksi',
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
                      // * Date range filter
                      const AppText(
                        'Rentang Tanggal',
                        style: AppTextStyle.labelLarge,
                        fontWeight: FontWeight.w600,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: AppDateTimePicker(
                              name: 'start_date',
                              label: 'Dari',
                              initialValue: _startDate,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppDateTimePicker(
                              name: 'end_date',
                              label: 'Sampai',
                              initialValue: _endDate,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // * Amount range filter
                      const AppText(
                        'Rentang Jumlah',
                        style: AppTextStyle.labelLarge,
                        fontWeight: FontWeight.w600,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              name: 'min_amount',
                              label: 'Min',
                              type: AppTextFieldType.number,
                              initialValue: _minAmount?.toString(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              name: 'max_amount',
                              label: 'Max',
                              type: AppTextFieldType.number,
                              initialValue: _maxAmount?.toString(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // * Asset filter
                      AppDropdown<String>(
                        name: 'asset_filter',
                        label: 'Aset',
                        hintText: 'Semua aset',
                        initialValue: _selectedAssetUlid,
                        items: widget.assets
                            .map(
                              (asset) => AppDropdownItem(
                                value: asset.ulid,
                                label: asset.name,
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() => _selectedAssetUlid = value);
                        },
                      ),
                      const SizedBox(height: 16),
                      // * Category filter
                      AppDropdown<String>(
                        name: 'category_filter',
                        label: 'Kategori',
                        hintText: 'Semua kategori',
                        initialValue: _selectedCategoryUlid,
                        items: widget.categories
                            .map(
                              (category) => AppDropdownItem(
                                value: category.ulid,
                                label: category.name,
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() => _selectedCategoryUlid = value);
                        },
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
                            child: AppDropdown<TransactionSortBy>(
                              name: 'sort_by',
                              label: 'Berdasarkan',
                              initialValue: _sortBy,
                              items: const [
                                AppDropdownItem(
                                  value: TransactionSortBy.transactionDate,
                                  label: 'Tanggal',
                                ),
                                AppDropdownItem(
                                  value: TransactionSortBy.amount,
                                  label: 'Jumlah',
                                ),
                                AppDropdownItem(
                                  value: TransactionSortBy.createdAt,
                                  label: 'Dibuat',
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
                            child: AppDropdown<SortOrder>(
                              name: 'sort_order',
                              label: 'Urutan',
                              initialValue: _sortOrder,
                              items: const [
                                AppDropdownItem(
                                  value: SortOrder.descending,
                                  label: 'Terbaru/Terbesar',
                                ),
                                AppDropdownItem(
                                  value: SortOrder.ascending,
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
      TransactionFilterData(
        assetUlid: _selectedAssetUlid,
        categoryUlid: _selectedCategoryUlid,
        startDate: formValues['start_date'] as DateTime?,
        endDate: formValues['end_date'] as DateTime?,
        minAmount: double.tryParse(formValues['min_amount'] ?? ''),
        maxAmount: double.tryParse(formValues['max_amount'] ?? ''),
        sortBy: _sortBy,
        sortOrder: _sortOrder,
      ),
    );
    Navigator.pop(context);
  }
}
