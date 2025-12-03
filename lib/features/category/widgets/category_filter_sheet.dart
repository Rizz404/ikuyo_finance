import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/category/models/get_categories_params.dart';
import 'package:ikuyo_finance/shared/widgets/app_button.dart';
import 'package:ikuyo_finance/shared/widgets/app_dropdown.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';

/// * Data class untuk filter values
class CategoryFilterData {
  final CategoryType? type;
  final String? parentUlid;
  final bool? isRootOnly;
  final CategorySortBy sortBy;
  final CategorySortOrder sortOrder;

  const CategoryFilterData({
    this.type,
    this.parentUlid,
    this.isRootOnly,
    this.sortBy = CategorySortBy.createdAt,
    this.sortOrder = CategorySortOrder.descending,
  });

  /// * Get human-readable sort label
  String get sortLabel {
    final sortByLabel = switch (sortBy) {
      CategorySortBy.createdAt => 'Dibuat',
      CategorySortBy.name => 'Nama',
    };
    final orderLabel = sortOrder == CategorySortOrder.descending
        ? 'Terbaru'
        : 'Terlama';
    return '$sortByLabel ($orderLabel)';
  }
}

/// * Bottom sheet untuk filter kategori
class CategoryFilterSheet extends StatefulWidget {
  final List<Category> parentCategories;
  final CategoryFilterData initialFilter;
  final ValueChanged<CategoryFilterData> onApplyFilter;
  final VoidCallback? onReset;

  const CategoryFilterSheet({
    super.key,
    required this.parentCategories,
    required this.initialFilter,
    required this.onApplyFilter,
    this.onReset,
  });

  /// * Static method to show the filter sheet
  static Future<void> show({
    required BuildContext context,
    required List<Category> parentCategories,
    required CategoryFilterData initialFilter,
    required ValueChanged<CategoryFilterData> onApplyFilter,
    VoidCallback? onReset,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CategoryFilterSheet(
        parentCategories: parentCategories,
        initialFilter: initialFilter,
        onApplyFilter: onApplyFilter,
        onReset: onReset,
      ),
    );
  }

  @override
  State<CategoryFilterSheet> createState() => _CategoryFilterSheetState();
}

class _CategoryFilterSheetState extends State<CategoryFilterSheet> {
  final _formKey = GlobalKey<FormBuilderState>();
  CategoryType? _selectedType;
  String? _selectedParentUlid;
  bool? _isRootOnly;
  late CategorySortBy _sortBy;
  late CategorySortOrder _sortOrder;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialFilter.type;
    // * Validate parentUlid exists in items list
    final parentExists = widget.parentCategories.any(
      (c) => c.ulid == widget.initialFilter.parentUlid,
    );
    _selectedParentUlid = parentExists ? widget.initialFilter.parentUlid : null;
    _isRootOnly = widget.initialFilter.isRootOnly;
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
                        'Filter Kategori',
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
                      AppDropdown<CategoryType>(
                        name: 'type_filter',
                        label: 'Tipe Kategori',
                        hintText: 'Semua tipe',
                        initialValue: _selectedType,
                        items: const [
                          AppDropdownItem(
                            value: CategoryType.expense,
                            label: 'Pengeluaran',
                          ),
                          AppDropdownItem(
                            value: CategoryType.income,
                            label: 'Pemasukan',
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedType = value);
                        },
                      ),
                      const SizedBox(height: 16),
                      // * Parent category filter
                      AppDropdown<String>(
                        name: 'parent_filter',
                        label: 'Kategori Induk',
                        hintText: 'Semua kategori',
                        initialValue: _selectedParentUlid,
                        items: widget.parentCategories
                            .map(
                              (category) => AppDropdownItem(
                                value: category.ulid,
                                label: category.name,
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() => _selectedParentUlid = value);
                        },
                      ),
                      const SizedBox(height: 16),
                      // * Root only filter
                      FormBuilderCheckbox(
                        name: 'is_root_only',
                        title: const Text('Hanya kategori utama (tanpa induk)'),
                        initialValue: _isRootOnly ?? false,
                        onChanged: (value) {
                          setState(() => _isRootOnly = value);
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
                            child: AppDropdown<CategorySortBy>(
                              name: 'sort_by',
                              label: 'Berdasarkan',
                              initialValue: _sortBy,
                              items: const [
                                AppDropdownItem(
                                  value: CategorySortBy.createdAt,
                                  label: 'Dibuat',
                                ),
                                AppDropdownItem(
                                  value: CategorySortBy.name,
                                  label: 'Nama',
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
                            child: AppDropdown<CategorySortOrder>(
                              name: 'sort_order',
                              label: 'Urutan',
                              initialValue: _sortOrder,
                              items: const [
                                AppDropdownItem(
                                  value: CategorySortOrder.descending,
                                  label: 'Terbaru',
                                ),
                                AppDropdownItem(
                                  value: CategorySortOrder.ascending,
                                  label: 'Terlama',
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
    widget.onApplyFilter(
      CategoryFilterData(
        type: _selectedType,
        parentUlid: _selectedParentUlid,
        isRootOnly: _isRootOnly == true ? true : null,
        sortBy: _sortBy,
        sortOrder: _sortOrder,
      ),
    );
    Navigator.pop(context);
  }
}
