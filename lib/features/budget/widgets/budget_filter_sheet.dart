import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
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
  String sortLabel(BuildContext context) {
    final sortByLabel = switch (sortBy) {
      BudgetSortBy.createdAt => LocaleKeys.budgetFilterSortCreated.tr(),
      BudgetSortBy.amountLimit => LocaleKeys.budgetFilterSortAmountLimit.tr(),
      BudgetSortBy.startDate => LocaleKeys.budgetFilterSortStartDate.tr(),
      BudgetSortBy.endDate => LocaleKeys.budgetFilterSortEndDate.tr(),
    };
    final orderLabel = sortOrder == BudgetSortOrder.descending
        ? (sortBy == BudgetSortBy.amountLimit
              ? LocaleKeys.budgetFilterSortBiggest.tr()
              : LocaleKeys.budgetFilterSortNewest.tr())
        : (sortBy == BudgetSortBy.amountLimit
              ? LocaleKeys.budgetFilterSortSmallest.tr()
              : LocaleKeys.budgetFilterSortOldest.tr());
    return '$sortByLabel ($orderLabel)';
  }
}

/// * Bottom sheet untuk filter anggaran
class BudgetFilterSheet extends StatefulWidget {
  final List<Category> categories;
  final BudgetFilterData initialFilter;
  final ValueChanged<BudgetFilterData> onApplyFilter;
  final VoidCallback? onReset;

  const BudgetFilterSheet({
    super.key,
    required this.categories,
    required this.initialFilter,
    required this.onApplyFilter,
    this.onReset,
  });

  /// * Static method to show the filter sheet
  static Future<void> show({
    required BuildContext context,
    required List<Category> categories,
    required BudgetFilterData initialFilter,
    required ValueChanged<BudgetFilterData> onApplyFilter,
    VoidCallback? onReset,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BudgetFilterSheet(
        categories: categories,
        initialFilter: initialFilter,
        onApplyFilter: onApplyFilter,
        onReset: onReset,
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
    // * Validate categoryUlid exists in items list
    final categoryExists = widget.categories.any(
      (c) => c.ulid == widget.initialFilter.categoryUlid,
    );
    _selectedCategoryUlid = categoryExists
        ? widget.initialFilter.categoryUlid
        : null;
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
                      AppText(
                        LocaleKeys.budgetFilterTitle.tr(),
                        style: AppTextStyle.titleLarge,
                        fontWeight: FontWeight.bold,
                      ),
                      TextButton(
                        onPressed: _clearAllFilters,
                        child: Text(LocaleKeys.budgetFilterReset.tr()),
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
                        label: LocaleKeys.budgetFilterPeriodLabel.tr(),
                        hintText: LocaleKeys.budgetFilterPeriodAll.tr(),
                        initialValue: _selectedPeriod,
                        items: [
                          AppDropdownItem(
                            value: BudgetPeriod.monthly,
                            label: LocaleKeys.budgetFilterPeriodMonthly.tr(),
                          ),
                          AppDropdownItem(
                            value: BudgetPeriod.weekly,
                            label: LocaleKeys.budgetFilterPeriodWeekly.tr(),
                          ),
                          AppDropdownItem(
                            value: BudgetPeriod.yearly,
                            label: LocaleKeys.budgetFilterPeriodYearly.tr(),
                          ),
                          AppDropdownItem(
                            value: BudgetPeriod.custom,
                            label: LocaleKeys.budgetFilterPeriodCustom.tr(),
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
                        label: LocaleKeys.budgetFilterCategoryLabel.tr(),
                        hintText: LocaleKeys.budgetFilterCategoryAll.tr(),
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
                      AppText(
                        LocaleKeys.budgetFilterAmountRange.tr(),
                        style: AppTextStyle.labelLarge,
                        fontWeight: FontWeight.w600,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              name: 'min_amount_limit',
                              label: LocaleKeys.budgetFilterMin.tr(),
                              type: AppTextFieldType.number,
                              initialValue: _minAmountLimit?.toString(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              name: 'max_amount_limit',
                              label: LocaleKeys.budgetFilterMax.tr(),
                              type: AppTextFieldType.number,
                              initialValue: _maxAmountLimit?.toString(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // * Date range filter
                      AppText(
                        LocaleKeys.budgetFilterStartDateRange.tr(),
                        style: AppTextStyle.labelLarge,
                        fontWeight: FontWeight.w600,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: AppDateTimePicker(
                              name: 'start_date_from',
                              label: LocaleKeys.budgetFilterFrom.tr(),
                              initialValue: _startDateFrom,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppDateTimePicker(
                              name: 'start_date_to',
                              label: LocaleKeys.budgetFilterTo.tr(),
                              initialValue: _startDateTo,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // * Sort options
                      AppText(
                        LocaleKeys.budgetFilterSortSection.tr(),
                        style: AppTextStyle.labelLarge,
                        fontWeight: FontWeight.w600,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: AppDropdown<BudgetSortBy>(
                              name: 'sort_by',
                              label: LocaleKeys.budgetFilterSortBy.tr(),
                              initialValue: _sortBy,
                              items: [
                                AppDropdownItem(
                                  value: BudgetSortBy.createdAt,
                                  label: LocaleKeys.budgetFilterSortCreated
                                      .tr(),
                                ),
                                AppDropdownItem(
                                  value: BudgetSortBy.amountLimit,
                                  label: LocaleKeys.budgetFilterSortAmountLimit
                                      .tr(),
                                ),
                                AppDropdownItem(
                                  value: BudgetSortBy.startDate,
                                  label: LocaleKeys.budgetFilterSortStartDate
                                      .tr(),
                                ),
                                AppDropdownItem(
                                  value: BudgetSortBy.endDate,
                                  label: LocaleKeys.budgetFilterSortEndDate
                                      .tr(),
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
                              label: LocaleKeys.budgetFilterSortOrder.tr(),
                              initialValue: _sortOrder,
                              items: [
                                AppDropdownItem(
                                  value: BudgetSortOrder.descending,
                                  label: LocaleKeys.budgetFilterSortDesc.tr(),
                                ),
                                AppDropdownItem(
                                  value: BudgetSortOrder.ascending,
                                  label: LocaleKeys.budgetFilterSortAsc.tr(),
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
                    text: LocaleKeys.budgetFilterApply.tr(),
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
