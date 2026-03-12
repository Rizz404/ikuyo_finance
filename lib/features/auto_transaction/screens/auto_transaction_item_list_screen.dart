import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/extensions/navigator_extension.dart';
import 'package:ikuyo_finance/core/extensions/theme_extension.dart';
import 'package:ikuyo_finance/core/utils/toast_helper.dart';
import 'package:ikuyo_finance/features/auto_transaction/bloc/auto_transaction_bloc.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_group.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_item.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/update_auto_item_params.dart';
import 'package:ikuyo_finance/features/auto_transaction/widgets/auto_item_tile.dart';
import 'package:ikuyo_finance/shared/widgets/app_batch_delete_dialog.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:ikuyo_finance/shared/widgets/screen_wrapper.dart';

class AutoTransactionItemListScreen extends StatefulWidget {
  final AutoTransactionGroup group;

  const AutoTransactionItemListScreen({super.key, required this.group});

  @override
  State<AutoTransactionItemListScreen> createState() =>
      _AutoTransactionItemListScreenState();
}

class _AutoTransactionItemListScreenState
    extends State<AutoTransactionItemListScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AutoTransactionBloc>().add(
      AutoItemsFetched(groupUlid: widget.group.ulid),
    );
  }

  void _handleWriteStatus(BuildContext context, AutoTransactionState state) {
    // * Guard: skip if a child route is currently on top (prevents duplicate toasts)
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;

    if (state.writeStatus == AutoTransactionWriteStatus.success) {
      ToastHelper.instance.showSuccess(
        context: context,
        title: state.writeSuccessMessage ?? 'Done',
      );
      context.read<AutoTransactionBloc>().add(const AutoWriteStatusReset());
    } else if (state.writeStatus == AutoTransactionWriteStatus.failure) {
      ToastHelper.instance.showError(
        context: context,
        title:
            state.writeErrorMessage ??
            LocaleKeys.autoTransactionScreenErrorOccurred.tr(),
      );
      context.read<AutoTransactionBloc>().add(const AutoWriteStatusReset());
    }
  }

  void _openBatchDeleteDialog(
    BuildContext context,
    List<AutoTransactionItem> items,
    AutoTransactionItem initialSelected,
  ) {
    AppBatchDeleteDialog.show<AutoTransactionItem>(
      context: context,
      title: 'Hapus Auto Item',
      items: items,
      getId: (i) => i.ulid,
      searchStringOf: (i) => i.transaction.target?.description ?? i.ulid,
      initialSelectedId: initialSelected.ulid,
      searchHint: 'Cari item...',
      itemBuilder: (item, isSelected, onToggle) => AutoItemTile(
        key: ValueKey(item.ulid),
        item: item,
        onTap: onToggle,
        onToggle: (_) {},
      ),
      onDelete: (selected) {
        final ulids = selected.map((i) => i.ulid).toList();
        context.read<AutoTransactionBloc>().add(
          AutoItemBatchDeleted(ulids: ulids),
        );
      },
    );
  }

  void _onReorder(List<AutoTransactionItem> items, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final reordered = List<AutoTransactionItem>.from(items);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    context.read<AutoTransactionBloc>().add(
      AutoItemReordered(
        groupUlid: widget.group.ulid,
        orderedUlids: reordered.map((i) => i.ulid).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AutoTransactionBloc, AutoTransactionState>(
      listenWhen: (prev, curr) => prev.writeStatus != curr.writeStatus,
      listener: _handleWriteStatus,
      child: BlocBuilder<AutoTransactionBloc, AutoTransactionState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: AppText(
                LocaleKeys.autoTransactionItemListTitle.tr(),
                style: AppTextStyle.titleLarge,
                fontWeight: FontWeight.bold,
              ),
              centerTitle: true,
            ),
            body: ScreenWrapper(child: _buildBody(context, state)),
            floatingActionButton: FloatingActionButton(
              heroTag: 'auto_item_fab',
              onPressed: () => context.pushToAddAutoItem(widget.group),
              child: const Icon(Icons.add),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, AutoTransactionState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.currentItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.playlist_add_outlined,
              size: 64,
              color: context.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            AppText(
              LocaleKeys.autoTransactionItemListEmptyTitle.tr(),
              style: AppTextStyle.bodyLarge,
              fontWeight: FontWeight.w600,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            AppText(
              LocaleKeys.autoTransactionItemListEmptySubtitle.tr(),
              style: AppTextStyle.bodyMedium,
              color: context.colorScheme.outline,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      itemCount: state.currentItems.length,
      onReorder: (oldIndex, newIndex) =>
          _onReorder(state.currentItems, oldIndex, newIndex),
      itemBuilder: (context, index) {
        final item = state.currentItems[index];
        return AutoItemTile(
          key: ValueKey(item.ulid),
          item: item,
          onTap: () => context.pushToEditAutoItem(widget.group, item),
          onToggle: (isActive) => context.read<AutoTransactionBloc>().add(
            AutoItemUpdated(
              params: UpdateAutoItemParams(ulid: item.ulid, isActive: isActive),
            ),
          ),
          onLongPress: () =>
              _openBatchDeleteDialog(context, state.currentItems, item),
        );
      },
    );
  }
}
