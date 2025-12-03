import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/budget/models/get_budgets_params.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/shared/widgets/app_button.dart';
import 'package:ikuyo_finance/shared/widgets/app_date_time_picker.dart';
import 'package:ikuyo_finance/shared/widgets/app_dropdown.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:ikuyo_finance/shared/widgets/app_text_field.dart';

/// * Data class untuk filter values
class BudgetFilterData {
  final BudgetPeriod? period;
  final String? categoryUlid;
  final double? minAmountLimit;
  final double? maxAmountLimit;
  final DateTime? startDateFrom;
  final DateTime? startDateTo;
  final BudgetSortBy sortBy;
  final BudgetSortOrder sortOrder;

  const BudgetFilterData({
    this.period,
    this.categoryUlid,
    this.minAmountLimit,
    this.maxAmountLimit,
    this.startDateFrom,
    this.startDateTo,
    this.sortBy = BudgetSortBy.createdAt,
    this.sortOrder = BudgetSortOrder.descending,
  });

  /// * Get human-readable sort label
  String get sortLabel {
    final sortByLabel = switch (sortBy) {
      BudgetSortBy.createdAt => 'Dibuat',
      BudgetSortBy.amountLimit => 'Limit',
      BudgetSortBy.startDate => 'Mulai',
      BudgetSortBy.endDate => 'Selesai',
    };
    final orderLabel = sortOrder == BudgetSortOrder.descending
        ? (sortBy == BudgetSortBy.amountLimit ? 'Terbesar' : 'Terbaru')
        : (sortBy == BudgetSortBy.amountLimit ? 'Terkecil' : 'Terlama');
    return '$sortByLabel ($orderLabel)';
  }
}

/// * Bottom sheet untuk filter anggaran
class BudgetFilterSheet extends StatefulWidget {
  final List<Category> categories;
  final BudgetFilterData initialFilter;
  final ValueChanged<BudgetFilterData> onApplyFilter;

  const BudgetFilterSheet({
    super.key,
    required this.categories,
    required this.initialFilter,
    required this.onApplyFilter,
  });

  /// * Static method to show the filter sheet
  static Future<void> show({
    required BuildContext context,
    required List<Category> categories,
    required BudgetFilterData initialFilter,
    required ValueChanged<BudgetFilterData> onApplyFilter,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BudgetFilterSheet(
        categories: categories,
        initialFilter: initialFilter,
        onApplyFilter: onApplyFilter,
      ),
    );
  }

  @override
  State<BudgetFilterSheet> createState() => _BudgetFilterSheetState();
}

class _BudgetFilterSheetState extends State<BudgetFilterSheet> {
  final _formKey = GlobalKey<FormBuilderState>();
  BudgetPeriod? _selectedPeriod;
  String? _selectedCategoryUlid;
  double? _minAmountLimit;
  double? _maxAmountLimit;
  DateTime? _startDateFrom;
  DateTime? _startDateTo;
  late BudgetSortBy _sortBy;
  late BudgetSortOrder _sortOrder;

  @override
  void initState() {
    super.initState();
    _selectedPeriod = widget.initialFilter.period;
    _selectedCategoryUlid = widget.initialFilter.categoryUlid;
    _minAmountLimit = widget.initialFilter.minAmountLimit;
    _maxAmountLimit = widget.initialFilter.maxAmountLimit;
    _startDateFrom = widget.initialFilter.startDateFrom;
    _startDateTo = widget.initialFilter.startDateTo;
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
                        'Filter Anggaran',
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
                      // * Period filter
                      AppDropdown<BudgetPeriod>(
                        name: 'period_filter',
                        label: 'Periode',
                        hintText: 'Semua periode',
                        initialValue: _selectedPeriod,
                        items: const [
                          AppDropdownItem(
                            value: BudgetPeriod.monthly,
                            label: 'Bulanan',
                          ),
                          AppDropdownItem(
                            value: BudgetPeriod.weekly,
                            label: 'Mingguan',
                          ),
                          AppDropdownItem(
                            value: BudgetPeriod.yearly,
                            label: 'Tahunan',
                          ),
                          AppDropdownItem(
                            value: BudgetPeriod.custom,
                            label: 'Kustom',
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedPeriod = value);
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
                      // * Amount limit range filter
                      const AppText(
                        'Rentang Limit',
                        style: AppTextStyle.labelLarge,
                        fontWeight: FontWeight.w600,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              name: 'min_amount_limit',
                              label: 'Min',
                              type: AppTextFieldType.number,
                              initialValue: _minAmountLimit?.toString(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              name: 'max_amount_limit',
                              label: 'Max',
                              type: AppTextFieldType.number,
                              initialValue: _maxAmountLimit?.toString(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // * Date range filter
                      const AppText(
                        'Rentang Tanggal Mulai',
                        style: AppTextStyle.labelLarge,
                        fontWeight: FontWeight.w600,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: AppDateTimePicker(
                              name: 'start_date_from',
                              label: 'Dari',
                              initialValue: _startDateFrom,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppDateTimePicker(
                              name: 'start_date_to',
                              label: 'Sampai',
                              initialValue: _startDateTo,
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
                            child: AppDropdown<BudgetSortBy>(
                              name: 'sort_by',
                              label: 'Berdasarkan',
                              initialValue: _sortBy,
                              items: const [
                                AppDropdownItem(
                                  value: BudgetSortBy.createdAt,
                                  label: 'Dibuat',
                                ),
                                AppDropdownItem(
                                  value: BudgetSortBy.amountLimit,
                                  label: 'Limit',
                                ),
                                AppDropdownItem(
                                  value: BudgetSortBy.startDate,
                                  label: 'Mulai',
                                ),
                                AppDropdownItem(
                                  value: BudgetSortBy.endDate,
                                  label: 'Selesai',
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
                            child: AppDropdown<BudgetSortOrder>(
                              name: 'sort_order',
                              label: 'Urutan',
                              initialValue: _sortOrder,
                              items: const [
                                AppDropdownItem(
                                  value: BudgetSortOrder.descending,
                                  label: 'Terbaru/Terbesar',
                                ),
                                AppDropdownItem(
                                  value: BudgetSortOrder.ascending,
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
    setState(() {
      _selectedPeriod = null;
      _selectedCategoryUlid = null;
      _minAmountLimit = null;
      _maxAmountLimit = null;
      _startDateFrom = null;
      _startDateTo = null;
      _sortBy = BudgetSortBy.createdAt;
      _sortOrder = BudgetSortOrder.descending;
    });
    _formKey.currentState?.reset();
  }

  void _applyFilters() {
    final formValues = _formKey.currentState?.instantValue ?? {};

    widget.onApplyFilter(
      BudgetFilterData(
        period: _selectedPeriod,
        categoryUlid: _selectedCategoryUlid,
        minAmountLimit: double.tryParse(formValues['min_amount_limit'] ?? ''),
        maxAmountLimit: double.tryParse(formValues['max_amount_limit'] ?? ''),
        startDateFrom: formValues['start_date_from'] as DateTime?,
        startDateTo: formValues['start_date_to'] as DateTime?,
        sortBy: _sortBy,
        sortOrder: _sortOrder,
      ),
    );
    Navigator.pop(context);
  }
}
