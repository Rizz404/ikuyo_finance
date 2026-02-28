import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:go_router/go_router.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/core/utils/toast_helper.dart';
import 'package:ikuyo_finance/features/category/bloc/category_bloc.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/category/models/create_category_params.dart';
import 'package:ikuyo_finance/features/category/models/update_category_params.dart';
import 'package:ikuyo_finance/features/category/validators/create_category_validator.dart';
import 'package:ikuyo_finance/features/category/validators/update_category_validator.dart';
import 'package:ikuyo_finance/shared/utils/icon_registry.dart';
import 'package:ikuyo_finance/shared/widgets/app_button.dart';
import 'package:ikuyo_finance/shared/widgets/app_color_picker.dart';
import 'package:ikuyo_finance/shared/widgets/app_dropdown.dart';
import 'package:ikuyo_finance/shared/widgets/app_file_picker.dart';
import 'package:ikuyo_finance/shared/widgets/app_searchable_dropdown.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:ikuyo_finance/shared/widgets/app_text_field.dart';
import 'package:ikuyo_finance/shared/widgets/screen_wrapper.dart';

class CategoryUpsertScreen extends StatefulWidget {
  final Category? category;

  const CategoryUpsertScreen({super.key, this.category});

  bool get isEdit => category != null;

  @override
  State<CategoryUpsertScreen> createState() => _CategoryUpsertScreenState();
}

class _CategoryUpsertScreenState extends State<CategoryUpsertScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  final _filePickerKey = GlobalKey<AppFilePickerState>();
  String? _selectedColor;
  late CategoryType _selectedType;

  List<Category?> _parentCategories = [];
  bool _isSearchingParents = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.category?.categoryType ?? CategoryType.expense;

    if (widget.isEdit) {
      _selectedColor = widget.category!.color;
      // * Check if editing category has children
      context.read<CategoryBloc>().add(
        CategoryHasChildrenChecked(ulid: widget.category!.ulid),
      );
    }

    _fetchValidParentCategories('');
  }

  Future<void> _fetchValidParentCategories(String query) async {
    setState(() => _isSearchingParents = true);
    try {
      final bloc = context.read<CategoryBloc>();
      final categories = await bloc.searchParentCategoriesForDropdown(
        query: query.isEmpty ? null : query,
        type: _selectedType,
        excludeUlid: widget.category?.ulid,
      );
      if (mounted) {
        setState(() {
          // Add 'null' as the "No parent" option
          _parentCategories = [null, ...categories];
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSearchingParents = false);
      }
    }
  }

  void _onTypeChanged(int? typeIndex) {
    if (typeIndex != null) {
      setState(() {
        _selectedType = CategoryType.values[typeIndex];
      });
      _fetchValidParentCategories('');
    }
  }

  /// * Check if parent dropdown should be shown
  /// * Hide if: category already has parent (is a child) OR has children (is a parent)
  bool _shouldShowParentDropdown(CategoryState state) {
    // * For new categories, always show
    if (!widget.isEdit) return true;

    // * If still loading children check, don't show yet
    if (state.editingCategoryHasChildren == null) return false;

    // * If category has children, it's a parent - can't become child
    if (state.editingCategoryHasChildren == true) return false;

    // * If category already has a parent, it's a child - can't nest deeper
    if (widget.category?.parent.target != null) return false;

    return true;
  }

  Widget _buildParentCategoryDropdown() {
    return BlocBuilder<CategoryBloc, CategoryState>(
      buildWhen: (prev, curr) =>
          prev.editingCategoryHasChildren != curr.editingCategoryHasChildren,
      builder: (context, state) {
        // * Don't show if shouldn't
        if (!_shouldShowParentDropdown(state)) {
          // * Show info if category is a parent (has children)
          if (widget.isEdit && state.editingCategoryHasChildren == true) {
            return _buildInfoCard(
              icon: Icons.folder_outlined,
              message: 'Kategori induk tidak dapat menjadi sub-kategori',
            );
          }
          // * Show info if category is already a child
          if (widget.isEdit && widget.category?.parent.target != null) {
            return _buildInfoCard(
              icon: Icons.subdirectory_arrow_right,
              message:
                  'Sub-kategori dari: ${widget.category!.parent.target!.name}',
            );
          }
          return const SizedBox.shrink();
        }

        return AppSearchableDropdown<Category?>(
          key: ValueKey(_selectedType), // * Reset when type changes
          name: 'parentUlid',
          label: 'Kategori Induk (Opsional)',
          hintText: 'Tidak ada (Kategori Utama)',
          items: _parentCategories,
          isLoading: _isSearchingParents,
          onSearch: _fetchValidParentCategories,
          itemDisplayMapper: (cat) => cat?.name ?? 'Tidak ada (Kategori Utama)',
          itemValueMapper: (cat) => cat?.ulid ?? '',
          itemSubtitleMapper: (cat) => cat != null
              ? 'Kategori Induk'
              : 'Jadikan kategori utama tanpa induk',
          itemLeadingMapper: (cat) => cat?.icon != null
              ? _buildIconPreview(cat!.icon!, size: 24)
              : Icon(
                  Icons.folder_outlined,
                  size: 24,
                  color: cat == null
                      ? context.colorScheme.outline
                      : context.colorScheme.primary,
                ),
          initialValue: widget.category?.parent.target,
          prefixIcon: const Icon(Icons.account_tree_outlined),
        );
      },
    );
  }

  Widget _buildInfoCard({required IconData icon, required String message}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colorScheme.outline.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.colorScheme.outline),
          const SizedBox(width: 12),
          Expanded(
            child: AppText(
              message,
              style: AppTextStyle.bodySmall,
              color: context.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  void _handleWriteStatus(BuildContext context, CategoryState state) {
    if (state.writeStatus == CategoryWriteStatus.success) {
      ToastHelper.instance.showSuccess(
        context: context,
        title: state.writeSuccessMessage ?? 'Berhasil',
      );
      context.read<CategoryBloc>().add(const CategoryWriteStatusReset());
      context.pop(true);
    } else if (state.writeStatus == CategoryWriteStatus.failure) {
      ToastHelper.instance.showError(
        context: context,
        title: state.writeErrorMessage ?? 'Terjadi kesalahan',
      );
      context.read<CategoryBloc>().add(const CategoryWriteStatusReset());
    }
  }

  void _onSubmit() {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      final values = _formKey.currentState!.value;
      final name = values['name'] as String;
      final type = CategoryType.values[values['type'] as int];
      final color = values['color'] as String?;
      final parentUlid = values['parentUlid'] as String?;

      // * Get icon path from file picker
      String? iconPath;
      final iconFiles = values['icon'] as List<PlatformFile>?;
      if (iconFiles != null && iconFiles.isNotEmpty) {
        iconPath = iconFiles.first.path;
      }

      if (widget.isEdit) {
        context.read<CategoryBloc>().add(
          CategoryUpdated(
            params: UpdateCategoryParams(
              ulid: widget.category!.ulid,
              name: name,
              type: type,
              icon: iconPath ?? widget.category!.icon,
              color: color,
              parentUlid: parentUlid,
            ),
          ),
        );
      } else {
        context.read<CategoryBloc>().add(
          CategoryCreated(
            params: CreateCategoryParams(
              name: name,
              type: type,
              icon: iconPath,
              color: color,
              parentUlid: parentUlid,
            ),
          ),
        );
      }
    }
  }

  void _onDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText(
          'Hapus Kategori',
          style: AppTextStyle.titleMedium,
          fontWeight: FontWeight.bold,
        ),
        content: const AppText(
          'Apakah Anda yakin ingin menghapus kategori ini? '
          'Transaksi yang menggunakan kategori ini akan kehilangan kategorinya.',
          style: AppTextStyle.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: AppText('Batal', color: context.colorScheme.outline),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<CategoryBloc>().add(
                CategoryDeleted(ulid: widget.category!.ulid),
              );
            },
            child: AppText(
              'Hapus',
              color: context.semantic.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CategoryBloc, CategoryState>(
      listenWhen: (prev, curr) => prev.writeStatus != curr.writeStatus,
      listener: _handleWriteStatus,
      child: Scaffold(
        appBar: AppBar(
          title: AppText(
            widget.isEdit ? 'Edit Kategori' : 'Tambah Kategori',
            style: AppTextStyle.titleLarge,
            fontWeight: FontWeight.bold,
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: ScreenWrapper(
          child: FormBuilder(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // * Category Type Dropdown
                  AppDropdown<int>(
                    name: 'type',
                    label: 'Tipe Kategori',
                    hintText: 'Pilih tipe kategori',
                    initialValue:
                        widget.category?.type ?? CategoryType.expense.index,
                    prefixIcon: const Icon(Icons.category_outlined),
                    onChanged: _onTypeChanged,
                    items: [
                      AppDropdownItem(
                        value: CategoryType.expense.index,
                        label: 'Pengeluaran',
                        icon: Icon(
                          Icons.arrow_downward,
                          size: 20,
                          color: context.semantic.error,
                        ),
                      ),
                      AppDropdownItem(
                        value: CategoryType.income.index,
                        label: 'Pemasukan',
                        icon: Icon(
                          Icons.arrow_upward,
                          size: 20,
                          color: context.semantic.success,
                        ),
                      ),
                    ],
                    validator: widget.isEdit
                        ? UpdateCategoryValidator.type
                        : CreateCategoryValidator.type,
                  ),
                  const SizedBox(height: 24),

                  // * Parent Category Dropdown
                  _buildParentCategoryDropdown(),
                  const SizedBox(height: 24),

                  // * Name Field
                  AppTextField(
                    name: 'name',
                    label: 'Nama Kategori',
                    initialValue: widget.category?.name,
                    placeHolder: 'Contoh: Makan & Minum',
                    validator: widget.isEdit
                        ? UpdateCategoryValidator.name
                        : CreateCategoryValidator.name,
                    prefixIcon: const Icon(Icons.label_outline),
                  ),
                  const SizedBox(height: 24),

                  // * Icon File Picker with current preview
                  if (widget.isEdit && widget.category?.icon != null) ...[
                    const AppText(
                      'Ikon Saat Ini',
                      style: AppTextStyle.labelMedium,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: context.colorScheme.outline.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildIconPreview(widget.category!.icon!, size: 48),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppText(
                              widget.category!.icon!.split('/').last,
                              style: AppTextStyle.bodySmall,
                              color: context.colorScheme.outline,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  AppFilePicker(
                    key: _filePickerKey,
                    name: 'icon',
                    label: widget.isEdit ? 'Ganti Ikon' : 'Ikon Kategori',
                    hintText: 'Pilih gambar ikon (opsional)',
                    fileType: FileType.image,
                    allowMultiple: false,
                    maxFiles: 1,
                    maxSizeInMB: 2,
                  ),
                  const SizedBox(height: 24),

                  // * Color Picker
                  AppColorPicker(
                    name: 'color',
                    label: 'Warna Kategori',
                    initialValue: _selectedColor,
                    onChanged: (color) =>
                        setState(() => _selectedColor = color),
                  ),
                  const SizedBox(height: 32),

                  // * Submit Button
                  BlocBuilder<CategoryBloc, CategoryState>(
                    buildWhen: (prev, curr) =>
                        prev.writeStatus != curr.writeStatus,
                    builder: (context, state) {
                      return AppButton(
                        text: widget.isEdit
                            ? 'Simpan Perubahan'
                            : 'Tambah Kategori',
                        isLoading: state.isWriting,
                        onPressed: state.isWriting ? null : _onSubmit,
                        leadingIcon: Icon(
                          widget.isEdit ? Icons.save_outlined : Icons.add,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // * Delete Button (only for edit mode)
                  if (widget.isEdit) ...[
                    BlocBuilder<CategoryBloc, CategoryState>(
                      buildWhen: (prev, curr) =>
                          prev.writeStatus != curr.writeStatus,
                      builder: (context, state) {
                        return AppButton(
                          text: 'Hapus Kategori',
                          variant: AppButtonVariant.outlined,
                          color: AppButtonColor.error,
                          isLoading: state.isWriting,
                          onPressed: state.isWriting ? null : _onDelete,
                          leadingIcon: const Icon(Icons.delete_outline),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// * Adaptive icon preview - handles icon key or file images
  Widget _buildIconPreview(String iconData, {double size = 48}) {
    // * Try getting icon from registry
    final icon = IconRegistry.getIcon(iconData);
    if (icon != null) {
      return Icon(icon, size: size, color: context.colorScheme.primary);
    }

    // * Skip old asset paths (no longer supported)
    if (iconData.startsWith('assets/')) {
      return Icon(
        Icons.image_outlined,
        size: size,
        color: context.colorScheme.primary,
      );
    }

    // * Otherwise treat as file path (user uploaded image)
    final file = File(iconData);
    return Image.file(
      file,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.broken_image_outlined,
        size: size,
        color: context.colorScheme.error,
      ),
    );
  }
}
