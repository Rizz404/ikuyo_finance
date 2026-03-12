import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/extensions/navigator_extension.dart';
import 'package:ikuyo_finance/core/extensions/theme_extension.dart';
import 'package:ikuyo_finance/core/utils/toast_helper.dart';
import 'package:ikuyo_finance/features/auto_transaction/bloc/auto_transaction_bloc.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_group.dart';
import 'package:ikuyo_finance/features/auto_transaction/widgets/auto_group_tile.dart';
import 'package:ikuyo_finance/shared/widgets/app_batch_delete_dialog.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:ikuyo_finance/shared/widgets/screen_wrapper.dart';

class AutoTransactionScreen extends StatefulWidget {
  const AutoTransactionScreen({super.key});

  @override
  State<AutoTransactionScreen> createState() => _AutoTransactionScreenState();
}

class _AutoTransactionScreenState extends State<AutoTransactionScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AutoTransactionBloc>().add(const AutoGroupFetched());
  }

  void _openBatchDeleteDialog(
    BuildContext context,
    List<AutoTransactionGroup> groups,
    AutoTransactionGroup initialSelected,
  ) {
    AppBatchDeleteDialog.show<AutoTransactionGroup>(
      context: context,
      title: 'Hapus Auto Transaction',
      items: groups,
      getId: (g) => g.ulid,
      searchStringOf: (g) => g.name,
      initialSelectedId: initialSelected.ulid,
      searchHint: 'Cari nama grup...',
      itemBuilder: (group, isSelected, onToggle) => AutoGroupTile(
        group: group,
        onTap: onToggle,
        onToggle: (_) {},
        onItemsTap: () {},
        onLogTap: () {},
      ),
      onDelete: (selected) {
        final ulids = selected.map((g) => g.ulid).toList();
        context.read<AutoTransactionBloc>().add(
          AutoGroupBatchDeleted(ulids: ulids),
        );
      },
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
                LocaleKeys.autoTransactionScreenTitle.tr(),
                style: AppTextStyle.titleLarge,
                fontWeight: FontWeight.bold,
              ),
            ),
            body: ScreenWrapper(child: _buildBody(context, state)),
            floatingActionButton: FloatingActionButton(
              heroTag: 'auto_tx_fab',
              onPressed: () => context.pushToAddAutoGroup(),
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

    if (state.status == AutoTransactionStatus.failure) {
      return Center(
        child: AppText(
          state.errorMessage ??
              LocaleKeys.autoTransactionScreenErrorOccurred.tr(),
          style: AppTextStyle.bodyMedium,
          color: context.semantic.error,
          textAlign: TextAlign.center,
        ),
      );
    }

    if (state.groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.schedule_outlined,
              size: 64,
              color: context.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            AppText(
              LocaleKeys.autoTransactionScreenEmptyTitle.tr(),
              style: AppTextStyle.bodyLarge,
              fontWeight: FontWeight.w600,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            AppText(
              LocaleKeys.autoTransactionScreenEmptySubtitle.tr(),
              style: AppTextStyle.bodyMedium,
              color: context.colorScheme.outline,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: state.groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final group = state.groups[index];
        return AutoGroupTile(
          group: group,
          onTap: () => context.pushToEditAutoGroup(group),
          onToggle: (isActive) => context.read<AutoTransactionBloc>().add(
            AutoGroupToggled(ulid: group.ulid, isActive: isActive),
          ),
          onItemsTap: () => context.pushToAutoItemList(group),
          onLogTap: () => context.pushToAutoLog(group),
          onLongPress: () =>
              _openBatchDeleteDialog(context, state.groups, group),
        );
      },
    );
  }
}
