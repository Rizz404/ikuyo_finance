import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:go_router/go_router.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/core/utils/toast_helper.dart';
import 'package:ikuyo_finance/features/auto_transaction/bloc/auto_transaction_bloc.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_group.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_item.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/create_auto_item_params.dart';
import 'package:ikuyo_finance/features/auto_transaction/validators/create_auto_item_validator.dart';
import 'package:ikuyo_finance/features/transaction/bloc/transaction_bloc.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/shared/widgets/app_button.dart';
import 'package:ikuyo_finance/shared/widgets/app_searchable_dropdown.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:ikuyo_finance/shared/widgets/screen_wrapper.dart';

class AutoTransactionItemUpsertScreen extends StatefulWidget {
  final AutoTransactionGroup group;
  final AutoTransactionItem? item;

  const AutoTransactionItemUpsertScreen({
    super.key,
    required this.group,
    this.item,
  });

  bool get isEdit => item != null;

  @override
  State<AutoTransactionItemUpsertScreen> createState() =>
      _AutoTransactionItemUpsertScreenState();
}

class _AutoTransactionItemUpsertScreenState
    extends State<AutoTransactionItemUpsertScreen> {
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  void initState() {
    super.initState();
    // * Load all transactions with a broad date range for picking
    context.read<TransactionBloc>().add(
      TransactionFetched(startDate: DateTime(2000), endDate: DateTime(2099)),
    );
  }

  void _handleWriteStatus(BuildContext context, AutoTransactionState state) {
    if (state.writeStatus == AutoTransactionWriteStatus.success) {
      ToastHelper.instance.showSuccess(
        context: context,
        title:
            state.writeSuccessMessage ??
            LocaleKeys.autoTransactionItemUpsertUpsertSuccess.tr(),
      );
      context.read<AutoTransactionBloc>().add(const AutoWriteStatusReset());
      context.pop(true);
    } else if (state.writeStatus == AutoTransactionWriteStatus.failure) {
      ToastHelper.instance.showError(
        context: context,
        title:
            state.writeErrorMessage ??
            LocaleKeys.autoTransactionItemUpsertUpsertError.tr(),
      );
      context.read<AutoTransactionBloc>().add(const AutoWriteStatusReset());
    }
  }

  void _onSubmit() {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;

    final values = _formKey.currentState!.value;
    final transactionUlid = values['transactionUlid'] as String?;
    if (transactionUlid == null) return;

    final autoState = context.read<AutoTransactionBloc>().state;
    final nextSortOrder = autoState.currentItems.length;

    context.read<AutoTransactionBloc>().add(
      AutoItemCreated(
        params: CreateAutoItemParams(
          groupUlid: widget.group.ulid,
          transactionUlid: transactionUlid,
          sortOrder: nextSortOrder,
        ),
      ),
    );
  }

  void _onDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: AppText(
          LocaleKeys.autoTransactionItemUpsertDeleteTitle.tr(),
          style: AppTextStyle.titleMedium,
          fontWeight: FontWeight.bold,
        ),
        content: AppText(
          LocaleKeys.autoTransactionItemUpsertDeleteConfirm.tr(),
          style: AppTextStyle.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: AppText('Cancel', color: context.colorScheme.outline),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<AutoTransactionBloc>().add(
                AutoItemDeleted(ulid: widget.item!.ulid),
              );
            },
            child: AppText(
              LocaleKeys.autoTransactionItemUpsertDelete.tr(),
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
    return BlocListener<AutoTransactionBloc, AutoTransactionState>(
      listenWhen: (prev, curr) => prev.writeStatus != curr.writeStatus,
      listener: _handleWriteStatus,
      child: Scaffold(
        appBar: AppBar(
          title: AppText(
            widget.isEdit
                ? LocaleKeys.autoTransactionItemUpsertEditTitle.tr()
                : LocaleKeys.autoTransactionItemUpsertAddTitle.tr(),
            style: AppTextStyle.titleLarge,
            fontWeight: FontWeight.bold,
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          actions: [
            if (widget.isEdit)
              IconButton(
                icon: Icon(Icons.delete_outline, color: context.semantic.error),
                onPressed: _onDelete,
              ),
          ],
        ),
        body: BlocBuilder<AutoTransactionBloc, AutoTransactionState>(
          buildWhen: (prev, curr) => prev.isWriting != curr.isWriting,
          builder: (context, autoState) {
            return BlocBuilder<TransactionBloc, TransactionState>(
              builder: (context, txState) {
                final initialTx = widget.item?.transaction.target;
                return ScreenWrapper(
                  child: FormBuilder(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppSearchableDropdown<Transaction>(
                          name: 'transactionUlid',
                          label: LocaleKeys
                              .autoTransactionItemUpsertTransactionLabel
                              .tr(),
                          hintText: LocaleKeys
                              .autoTransactionItemUpsertTransactionHint
                              .tr(),
                          initialValue: initialTx,
                          items: txState.transactions,
                          isLoading:
                              txState.status == TransactionStatus.loading,
                          isLoadingMore:
                              txState.status == TransactionStatus.loadingMore,
                          hasMore: !txState.hasReachedMax,
                          onSearch: (query) => context
                              .read<TransactionBloc>()
                              .add(TransactionSearched(query: query)),
                          onLoadMore: () => context.read<TransactionBloc>().add(
                            const TransactionFetchedMore(),
                          ),
                          itemDisplayMapper: (tx) =>
                              tx.description ?? 'Unnamed',
                          itemValueMapper: (tx) => tx.ulid,
                          itemSubtitleMapper: (tx) {
                            final date = tx.transactionDate != null
                                ? DateFormat(
                                    'dd MMM yyyy',
                                  ).format(tx.transactionDate!)
                                : null;
                            final cat = tx.category.target?.name;
                            final parts = [
                              cat,
                              date,
                            ].whereType<String>().toList();
                            return parts.isEmpty ? null : parts.join(' · ');
                          },
                          validator: (value) =>
                              CreateAutoItemValidator.transactionUlid(value),
                          prefixIcon: const Icon(Icons.receipt_outlined),
                        ),
                        const SizedBox(height: 32),
                        AppButton(
                          text: LocaleKeys.autoTransactionItemUpsertSave.tr(),
                          isLoading: autoState.isWriting,
                          onPressed: _onSubmit,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
