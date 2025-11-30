import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:go_router/go_router.dart';
import 'package:ikuyo_finance/core/router/app_navigator.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/core/utils/toast_helper.dart';
import 'package:ikuyo_finance/features/category/bloc/category_bloc.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/transaction/bloc/transaction_bloc.dart';
import 'package:ikuyo_finance/features/transaction/models/create_transaction_params.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/features/transaction/models/update_transaction_params.dart';
import 'package:ikuyo_finance/features/asset/bloc/asset_bloc.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/transaction/validators/create_transaction_validator.dart';
import 'package:ikuyo_finance/features/transaction/validators/update_transaction_validator.dart';
import 'package:ikuyo_finance/shared/widgets/app_button.dart';
import 'package:ikuyo_finance/shared/widgets/app_date_time_picker.dart';
import 'package:ikuyo_finance/shared/widgets/app_dropdown.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:ikuyo_finance/shared/widgets/app_text_field.dart';
import 'package:ikuyo_finance/shared/widgets/screen_wrapper.dart';

class TransactionUpsertScreen extends StatefulWidget {
  final Transaction? transaction;

  const TransactionUpsertScreen({super.key, this.transaction});

  bool get isEdit => transaction != null;

  @override
  State<TransactionUpsertScreen> createState() =>
      _TransactionUpsertScreenState();
}

class _TransactionUpsertScreenState extends State<TransactionUpsertScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  CategoryType _selectedType = CategoryType.expense;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) {
      final category = widget.transaction!.category.target;
      if (category != null) {
        _selectedType = category.categoryType;
      }
    }
  }

  void _handleWriteStatus(BuildContext context, TransactionState state) {
    if (state.writeStatus == TransactionWriteStatus.success) {
      ToastHelper.instance.showSuccess(
        context: context,
        title: widget.isEdit
            ? 'Transaksi berhasil diperbarui'
            : 'Transaksi berhasil ditambahkan',
      );
      context.read<TransactionBloc>().add(const TransactionWriteStatusReset());
      context.pop(true);
    } else if (state.writeStatus == TransactionWriteStatus.failure) {
      ToastHelper.instance.showError(
        context: context,
        title: 'Gagal menyimpan transaksi',
        description: state.writeErrorMessage,
      );
      context.read<TransactionBloc>().add(const TransactionWriteStatusReset());
    }
  }

  void _onSubmit() {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      final values = _formKey.currentState!.value;
      final amountStr = (values['amount'] as String).replaceAll('.', '');
      final amount = double.tryParse(amountStr) ?? 0;

      if (widget.isEdit) {
        context.read<TransactionBloc>().add(
          TransactionUpdated(
            params: UpdateTransactionParams(
              ulid: widget.transaction!.ulid,
              assetUlid: values['assetUlid'] as String?,
              categoryUlid: values['categoryUlid'] as String?,
              amount: amount,
              transactionDate: values['transactionDate'] as DateTime?,
              description: values['description'] as String?,
            ),
          ),
        );
      } else {
        context.read<TransactionBloc>().add(
          TransactionCreated(
            params: CreateTransactionParams(
              assetUlid: values['assetUlid'] as String,
              categoryUlid: values['categoryUlid'] as String?,
              amount: amount,
              transactionDate: values['transactionDate'] as DateTime?,
              description: values['description'] as String?,
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
          'Hapus Transaksi',
          style: AppTextStyle.titleMedium,
          fontWeight: FontWeight.bold,
        ),
        content: const AppText(
          'Apakah Anda yakin ingin menghapus transaksi ini?',
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
              context.read<TransactionBloc>().add(
                TransactionDeleted(ulid: widget.transaction!.ulid),
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

  IconData _getAssetIcon(AssetType type) {
    switch (type) {
      case AssetType.cash:
        return Icons.money;
      case AssetType.bank:
        return Icons.account_balance;
      case AssetType.eWallet:
        return Icons.phone_android;
      case AssetType.stock:
        return Icons.trending_up;
      case AssetType.crypto:
        return Icons.connecting_airports_outlined;
    }
  }

  Color _getCategoryColor(Category category, BuildContext context) {
    if (category.color != null) {
      try {
        return Color(int.parse(category.color!.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    return category.categoryType == CategoryType.expense
        ? context.semantic.error
        : context.semantic.success;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TransactionBloc, TransactionState>(
      listenWhen: (prev, curr) => prev.writeStatus != curr.writeStatus,
      listener: _handleWriteStatus,
      child: Scaffold(
        appBar: AppBar(
          title: AppText(
            widget.isEdit ? 'Edit Transaksi' : 'Tambah Transaksi',
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
                  // * Transaction Type Selector
                  _TransactionTypeSelector(
                    selectedType: _selectedType,
                    onTypeChanged: (type) {
                      setState(() => _selectedType = type);
                      // * Reset category when type changes
                      _formKey.currentState?.fields['categoryUlid']?.didChange(
                        null,
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // * Amount Field
                  AppTextField(
                    name: 'amount',
                    label: 'Jumlah',
                    type: AppTextFieldType.number,
                    initialValue: widget.transaction?.amount.toStringAsFixed(0),
                    prefixText: 'Rp ',
                    validator: widget.isEdit
                        ? UpdateTransactionValidator.amount
                        : CreateTransactionValidator.amount,
                  ),
                  const SizedBox(height: 16),

                  // * Asset Dropdown
                  BlocBuilder<AssetBloc, AssetState>(
                    builder: (context, state) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: AppDropdown<String>(
                              name: 'assetUlid',
                              label: 'Asset',
                              hintText: state.assets.isEmpty
                                  ? 'Belum ada asset'
                                  : 'Pilih asset',
                              initialValue:
                                  widget.transaction?.asset.target?.ulid,
                              items: state.assets
                                  .map(
                                    (asset) => AppDropdownItem(
                                      value: asset.ulid,
                                      label: asset.name,
                                      imagePath: asset.icon,
                                      icon: Icon(
                                        _getAssetIcon(asset.assetType),
                                        size: 20,
                                        color: context.colorScheme.primary,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              validator: widget.isEdit
                                  ? UpdateTransactionValidator.assetUlid
                                  : CreateTransactionValidator.assetUlid,
                              prefixIcon: const Icon(
                                Icons.account_balance_wallet_outlined,
                              ),
                              imageColor: context.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: IconButton.filled(
                              onPressed: () => context.pushToAddAsset(),
                              icon: const Icon(Icons.add),
                              tooltip: 'Tambah Asset',
                              style: IconButton.styleFrom(
                                backgroundColor: context.colorScheme.primary,
                                foregroundColor: context.colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // * Category Dropdown
                  BlocBuilder<CategoryBloc, CategoryState>(
                    builder: (context, state) {
                      final filteredCategories = state.categories
                          .where((c) => c.categoryType == _selectedType)
                          .toList();

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: AppDropdown<String>(
                              name: 'categoryUlid',
                              label: 'Kategori',
                              hintText: filteredCategories.isEmpty
                                  ? 'Belum ada kategori'
                                  : 'Pilih kategori',
                              initialValue:
                                  widget.transaction?.category.target?.ulid,
                              items: filteredCategories
                                  .map(
                                    (c) => AppDropdownItem(
                                      value: c.ulid,
                                      label: c.name,
                                      imagePath: c.icon,
                                      icon: Icon(
                                        Icons.category_outlined,
                                        size: 20,
                                        color: _getCategoryColor(c, context),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              prefixIcon: const Icon(Icons.category_outlined),
                              imageColor: _selectedType == CategoryType.expense
                                  ? context.semantic.error
                                  : context.semantic.success,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: IconButton.filled(
                              onPressed: () => context.pushToAddCategory(),
                              icon: const Icon(Icons.add),
                              tooltip: 'Tambah Kategori',
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    _selectedType == CategoryType.expense
                                    ? context.semantic.error
                                    : context.semantic.success,
                                foregroundColor: context.colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // * Date Time Picker
                  AppDateTimePicker(
                    name: 'transactionDate',
                    label: 'Tanggal & Waktu',
                    inputType: InputType.both,
                    initialValue:
                        widget.transaction?.transactionDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  ),
                  const SizedBox(height: 16),

                  // * Description Field
                  AppTextField(
                    name: 'description',
                    label: 'Deskripsi',
                    type: AppTextFieldType.multiline,
                    maxLines: 3,
                    initialValue: widget.transaction?.description,
                    placeHolder: 'Tambahkan catatan (opsional)',
                  ),
                  const SizedBox(height: 32),

                  // * Submit Button
                  BlocBuilder<TransactionBloc, TransactionState>(
                    buildWhen: (prev, curr) =>
                        prev.writeStatus != curr.writeStatus,
                    builder: (context, state) {
                      return AppButton(
                        text: widget.isEdit
                            ? 'Simpan Perubahan'
                            : 'Tambah Transaksi',
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
                    BlocBuilder<TransactionBloc, TransactionState>(
                      buildWhen: (prev, curr) =>
                          prev.writeStatus != curr.writeStatus,
                      builder: (context, state) {
                        return AppButton(
                          text: 'Hapus Transaksi',
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
}

// * Transaction Type Selector Widget
class _TransactionTypeSelector extends StatelessWidget {
  final CategoryType selectedType;
  final ValueChanged<CategoryType> onTypeChanged;

  const _TransactionTypeSelector({
    required this.selectedType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.5,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TypeButton(
              label: 'Pengeluaran',
              icon: Icons.arrow_downward,
              isSelected: selectedType == CategoryType.expense,
              color: context.semantic.error,
              onTap: () => onTypeChanged(CategoryType.expense),
            ),
          ),
          Expanded(
            child: _TypeButton(
              label: 'Pemasukan',
              icon: Icons.arrow_upward,
              isSelected: selectedType == CategoryType.income,
              color: context.semantic.success,
              onTap: () => onTypeChanged(CategoryType.income),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: color, width: 1.5) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? color : context.colorScheme.outline,
            ),
            const SizedBox(width: 8),
            AppText(
              label,
              style: AppTextStyle.labelLarge,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? color : context.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}
