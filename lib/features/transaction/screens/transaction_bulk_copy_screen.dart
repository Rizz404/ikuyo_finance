import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:go_router/go_router.dart';
import 'package:ikuyo_finance/core/currency/currency.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/core/utils/toast_helper.dart';
import 'package:ikuyo_finance/features/asset/bloc/asset_bloc.dart';
import 'package:ikuyo_finance/features/category/bloc/category_bloc.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/transaction/bloc/transaction_bloc.dart';
import 'package:ikuyo_finance/features/transaction/models/create_transaction_params.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/shared/widgets/app_button.dart';
import 'package:ikuyo_finance/shared/widgets/app_date_time_picker.dart';
import 'package:ikuyo_finance/shared/widgets/app_multi_select_dropdown.dart';
import 'package:ikuyo_finance/shared/widgets/app_searchable_dropdown.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:ikuyo_finance/shared/widgets/app_text_field.dart';
import 'package:ikuyo_finance/shared/widgets/screen_wrapper.dart';

class _TransactionFormData {
  final String id;
  GlobalKey<FormBuilderState> formKey;
  final Transaction sourceTransaction;
  CategoryType categoryType;
  Asset? selectedAsset;
  Category? selectedCategory;
  String? assetUlid;
  String? assetName;
  String? categoryUlid;
  String? categoryName;
  double? amount;
  DateTime? transactionDate;
  String? description;
  int formKeyVersion = 0;

  _TransactionFormData({
    required this.id,
    required this.formKey,
    required this.sourceTransaction,
    required this.categoryType,
    this.selectedAsset,
    this.selectedCategory,
    this.assetUlid,
    this.assetName,
    this.categoryUlid,
    this.categoryName,
    this.amount,
    this.transactionDate,
    this.description,
  });
}

class TransactionBulkCopyScreen extends StatefulWidget {
  const TransactionBulkCopyScreen({super.key});

  @override
  State<TransactionBulkCopyScreen> createState() =>
      _TransactionBulkCopyScreenState();
}

class _TransactionBulkCopyScreenState extends State<TransactionBulkCopyScreen> {
  List<_TransactionFormData> _copyForms = [];

  List<Asset> _assets = [];
  bool _isSearchingAssets = false;

  List<Category> _categories = [];
  bool _isSearchingCategories = false;

  Future<List<Transaction>> _searchTransactions(String query) async {
    final bloc = context.read<TransactionBloc>();
    final transactions = await bloc.searchTransactionsForDropdown(
      query: query.isEmpty ? null : query,
    );

    if (!mounted) return [];

    return transactions;
  }

  Future<void> _searchAssets(String query) async {
    setState(() => _isSearchingAssets = true);
    try {
      final bloc = context.read<AssetBloc>();
      final assets = await bloc.searchAssetsForDropdown(
        query: query.isEmpty ? null : query,
      );

      if (mounted) {
        setState(() => _assets = assets);
      }
    } finally {
      if (mounted) {
        setState(() => _isSearchingAssets = false);
      }
    }
  }

  Future<void> _searchCategories(String query, CategoryType type) async {
    setState(() => _isSearchingCategories = true);
    try {
      final bloc = context.read<CategoryBloc>();
      final categories = await bloc.searchCategoriesForDropdown(
        query: query.isEmpty ? null : query,
        type: type,
      );

      if (mounted) {
        setState(() => _categories = categories);
      }
    } finally {
      if (mounted) {
        setState(() => _isSearchingCategories = false);
      }
    }
  }

  void _onTransactionsSelected(List<Transaction> transactions) {
    setState(() {
      if (transactions.isEmpty) {
        _copyForms = [];
        return;
      }

      _copyForms = transactions.map((trx) {
        return _TransactionFormData(
          id: trx.ulid,
          formKey: GlobalKey<FormBuilderState>(),
          sourceTransaction: trx,
          categoryType:
              trx.category.target?.categoryType ?? CategoryType.expense,
          selectedAsset: trx.asset.target,
          selectedCategory: trx.category.target,
          assetUlid: trx.asset.target?.ulid,
          assetName: trx.asset.target?.name,
          categoryUlid: trx.category.target?.ulid,
          categoryName: trx.category.target?.name,
          amount: trx.amount,
          transactionDate: DateTime.now(),
          description: trx.description,
        );
      }).toList();
    });
  }

  void _removeForm(int index) {
    setState(() {
      _copyForms.removeAt(index);
    });
  }

  void _handleWriteStatus(BuildContext context, TransactionState state) {
    if (state.writeStatus == TransactionWriteStatus.success) {
      final bulkResult = state.bulkCreateResult;
      if (bulkResult != null) {
        if (bulkResult.hasFailures) {
          ToastHelper.instance.showWarning(
            context: context,
            title:
                '${bulkResult.successCount} berhasil, ${bulkResult.failureCount} gagal',
            description: bulkResult.failedReasons.take(3).join('\n'),
          );
        } else {
          ToastHelper.instance.showSuccess(
            context: context,
            title: '${bulkResult.successCount} transaksi berhasil dibuat',
          );
        }
      } else {
        ToastHelper.instance.showSuccess(
          context: context,
          title: state.writeSuccessMessage ?? 'Berhasil',
        );
      }
      context.read<TransactionBloc>().add(const TransactionWriteStatusReset());
      context.pop(true);
    } else if (state.writeStatus == TransactionWriteStatus.failure) {
      ToastHelper.instance.showError(
        context: context,
        title: state.writeErrorMessage ?? 'Terjadi kesalahan',
      );
      context.read<TransactionBloc>().add(const TransactionWriteStatusReset());
    }
  }

  void _onSubmit() {
    final List<CreateTransactionParams> paramsList = [];
    bool allValid = true;

    for (final formData in _copyForms) {
      if (formData.formKey.currentState?.saveAndValidate() ?? false) {
        final values = formData.formKey.currentState!.value;
        final amountStr = (values['amount'] as String).replaceAll('.', '');
        final amount = double.tryParse(amountStr) ?? 0;

        paramsList.add(
          CreateTransactionParams(
            assetUlid: values['assetUlid'] as String,
            categoryUlid: values['categoryUlid'] as String?,
            amount: amount,
            transactionDate: values['transactionDate'] as DateTime?,
            description: values['description'] as String?,
          ),
        );
      } else {
        allValid = false;
      }
    }

    if (allValid && paramsList.isNotEmpty) {
      context.read<TransactionBloc>().add(
        TransactionBulkCreated(paramsList: paramsList),
      );
    } else if (!allValid) {
      ToastHelper.instance.showError(
        context: context,
        title: 'Periksa kembali data yang belum valid',
      );
    }
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
          title: const AppText(
            'Copy Banyak Transaksi',
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppMultiSelectDropdown<Transaction>(
                name: 'copyTransactions',
                label: 'Copy dari Transaksi',
                hintText: 'Pilih satu atau banyak transaksi',
                searchHintText: 'Cari transaksi...',
                prefixIcon: const Icon(Icons.copy_outlined),
                onSearch: _searchTransactions,
                onLoadInitial: () => _searchTransactions(''),
                itemDisplayMapper: (trx) =>
                    trx.description ?? 'Tanpa deskripsi',
                itemValueMapper: (trx) => trx.ulid,
                itemSubtitleMapper: (trx) =>
                    '${trx.category.target?.name ?? 'Tanpa kategori'} • ${trx.asset.target?.name ?? '-'}',
                itemLeadingMapper: (trx) => Icon(
                  trx.category.target?.categoryType == CategoryType.expense
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                  size: 24,
                  color:
                      trx.category.target?.categoryType == CategoryType.expense
                      ? context.semantic.error
                      : context.semantic.success,
                ),
                onChanged: _onTransactionsSelected,
                emptyMessage: 'Tidak ada transaksi ditemukan',
                initialValue: _copyForms
                    .map((f) => f.sourceTransaction)
                    .toList(),
              ),
              const SizedBox(height: 16),
              if (_copyForms.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.colorScheme.primaryContainer.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: context.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppText(
                          '${_copyForms.length} transaksi dipilih',
                          style: AppTextStyle.bodyMedium,
                          color: context.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      if (_copyForms.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => setState(() => _copyForms = []),
                          icon: Icon(
                            Icons.clear_all,
                            size: 18,
                            color: context.colorScheme.error,
                          ),
                          label: AppText(
                            'Hapus Semua',
                            style: AppTextStyle.labelMedium,
                            color: context.colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: _copyForms.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) => _buildForm(index),
                  ),
                ),
                const SizedBox(height: 16),
                BlocBuilder<TransactionBloc, TransactionState>(
                  buildWhen: (prev, curr) =>
                      prev.writeStatus != curr.writeStatus,
                  builder: (context, state) {
                    return AppButton(
                      text: 'Simpan ${_copyForms.length} Transaksi',
                      onPressed: _onSubmit,
                      isLoading:
                          state.writeStatus == TransactionWriteStatus.loading,
                      leadingIcon: const Icon(Icons.save_outlined),
                    );
                  },
                ),
              ] else
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.copy_all_outlined,
                          size: 64,
                          color: context.colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        AppText(
                          'Pilih transaksi untuk di-copy',
                          style: AppTextStyle.bodyLarge,
                          color: context.colorScheme.outline,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(int index) {
    final formData = _copyForms[index];
    final sourceTransaction = formData.sourceTransaction;
    final decimalDigits = context
        .read<CurrencyCubit>()
        .state
        .currency
        .decimalDigits;

    final uniqueFormKey = '${formData.id}_v${formData.formKeyVersion}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.3)),
      ),
      child: FormBuilder(
        key: formData.formKey,
        onChanged: () {
          final currentState = formData.formKey.currentState;
          if (currentState == null) return;

          final values = currentState.value;
          formData.assetUlid = values['assetUlid'] as String?;
          formData.categoryUlid = values['categoryUlid'] as String?;
          formData.transactionDate = values['transactionDate'] as DateTime?;
          formData.description = values['description'] as String?;

          final amountStr = values['amount'] as String?;
          if (amountStr != null && amountStr.isNotEmpty) {
            formData.amount =
                double.tryParse(amountStr.replaceAll('.', '')) ?? 0;
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: formData.categoryType == CategoryType.expense
                        ? context.semantic.error.withValues(alpha: 0.1)
                        : context.semantic.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    formData.categoryType == CategoryType.expense
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                    size: 20,
                    color: formData.categoryType == CategoryType.expense
                        ? context.semantic.error
                        : context.semantic.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        sourceTransaction.description ?? 'Tanpa deskripsi',
                        style: AppTextStyle.titleSmall,
                        fontWeight: FontWeight.bold,
                      ),
                      AppText(
                        'Original: ${sourceTransaction.category.target?.name ?? '-'}',
                        style: AppTextStyle.bodySmall,
                        color: context.colorScheme.outline,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _removeForm(index),
                  icon: Icon(
                    Icons.close,
                    size: 20,
                    color: context.colorScheme.error,
                  ),
                  tooltip: 'Hapus',
                ),
              ],
            ),
            const SizedBox(height: 16),
            const AppText(
              'Tipe Transaksi',
              style: AppTextStyle.labelMedium,
              fontWeight: FontWeight.bold,
            ),
            const SizedBox(height: 8),
            _TypeToggle(
              selectedType: formData.categoryType,
              onChanged: (type) {
                setState(() {
                  formData.categoryType = type;
                  formData.categoryUlid = null;
                  formData.categoryName = null;
                  formData.formKeyVersion++;
                });
              },
            ),
            const SizedBox(height: 16),
            AppTextField(
              key: Key('${uniqueFormKey}_amount'),
              name: 'amount',
              label: 'Jumlah',
              type: AppTextFieldType.currency,
              initialValue: formData.amount?.toStringAsFixed(decimalDigits),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Jumlah harus diisi';
                }
                final amount = double.tryParse(value.replaceAll('.', '')) ?? 0;
                if (amount <= 0) return 'Jumlah harus lebih dari 0';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppSearchableDropdown<Asset>(
                    key: Key('${uniqueFormKey}_asset'),
                    name: 'assetUlid',
                    label: 'Aset',
                    hintText: 'Pilih aset',
                    prefixIcon: const Icon(Icons.account_balance_wallet),
                    items: _assets,
                    isLoading: _isSearchingAssets,
                    onSearch: _searchAssets,
                    itemDisplayMapper: (asset) => asset.name,
                    itemValueMapper: (asset) => asset.ulid,
                    itemSubtitleMapper: (asset) => asset.assetType.name,
                    itemLeadingMapper: (asset) => Icon(
                      _getAssetIcon(asset.assetType),
                      size: 24,
                      color: context.colorScheme.primary,
                    ),
                    initialValue: formData.selectedAsset,
                    onChanged: (asset) {
                      formData.selectedAsset = asset;
                      formData.assetUlid = asset?.ulid;
                      formData.assetName = asset?.name;
                    },
                    validator: (value) =>
                        value == null ? 'Aset harus dipilih' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppSearchableDropdown<Category>(
                    key: Key('${uniqueFormKey}_category'),
                    name: 'categoryUlid',
                    label: 'Kategori',
                    hintText: 'Pilih kategori',
                    prefixIcon: const Icon(Icons.category_outlined),
                    items: _categories,
                    isLoading: _isSearchingCategories,
                    onSearch: (q) =>
                        _searchCategories(q, formData.categoryType),
                    itemDisplayMapper: (category) => category.name,
                    itemValueMapper: (category) => category.ulid,
                    itemSubtitleMapper: (category) =>
                        category.parent.target != null
                        ? '↳ Sub dari: ${category.parent.target!.name}'
                        : 'Kategori Utama',
                    itemLeadingMapper: (category) => Icon(
                      category.parent.target != null
                          ? Icons.subdirectory_arrow_right
                          : Icons.folder_outlined,
                      size: 24,
                      color: _getCategoryColor(category, context),
                    ),
                    initialValue: formData.selectedCategory,
                    onChanged: (category) {
                      formData.selectedCategory = category;
                      formData.categoryUlid = category?.ulid;
                      formData.categoryName = category?.name;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppDateTimePicker(
              key: Key('${uniqueFormKey}_date'),
              name: 'transactionDate',
              label: 'Tanggal',
              prefixIcon: const Icon(Icons.calendar_today_outlined),
              initialValue: formData.transactionDate ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            ),
            const SizedBox(height: 16),
            AppTextField(
              key: Key('${uniqueFormKey}_description'),
              name: 'description',
              label: 'Deskripsi',
              prefixIcon: const Icon(Icons.notes_outlined),
              initialValue: formData.description,
              placeHolder: 'Tambahkan catatan (opsional)',
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  final CategoryType selectedType;
  final ValueChanged<CategoryType> onChanged;

  const _TypeToggle({required this.selectedType, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TypeButton(
              label: 'Pengeluaran',
              icon: Icons.arrow_downward,
              isSelected: selectedType == CategoryType.expense,
              color: context.semantic.error,
              onTap: () => onChanged(CategoryType.expense),
            ),
          ),
          Expanded(
            child: _TypeButton(
              label: 'Pemasukan',
              icon: Icons.arrow_upward,
              isSelected: selectedType == CategoryType.income,
              color: context.semantic.success,
              onTap: () => onChanged(CategoryType.income),
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
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: color, width: 1.5) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? color : context.colorScheme.outline,
            ),
            const SizedBox(width: 6),
            AppText(
              label,
              style: AppTextStyle.labelMedium,
              color: isSelected ? color : context.colorScheme.outline,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ],
        ),
      ),
    );
  }
}
