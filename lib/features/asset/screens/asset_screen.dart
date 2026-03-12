import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/extensions/navigator_extension.dart';
import 'package:ikuyo_finance/core/extensions/theme_extension.dart';
import 'package:ikuyo_finance/core/utils/toast_helper.dart';
import 'package:ikuyo_finance/features/asset/bloc/asset_bloc.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/asset/widgets/asset_card.dart';
import 'package:ikuyo_finance/features/asset/widgets/asset_filter_sheet.dart';
import 'package:ikuyo_finance/shared/widgets/app_batch_delete_dialog.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:ikuyo_finance/shared/widgets/screen_wrapper.dart';

class AssetScreen extends StatefulWidget {
  const AssetScreen({super.key});

  @override
  State<AssetScreen> createState() => _AssetScreenState();
}

class _AssetScreenState extends State<AssetScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AssetBloc, AssetState>(
      listenWhen: (prev, curr) => curr.writeStatus != prev.writeStatus,
      listener: (context, state) {
        if (state.writeStatus == AssetWriteStatus.success) {
          ToastHelper.instance.showSuccess(
            context: context,
            title: state.writeSuccessMessage ?? 'Berhasil dihapus',
          );
          context.read<AssetBloc>().add(const AssetWriteStatusReset());
        } else if (state.writeStatus == AssetWriteStatus.failure) {
          ToastHelper.instance.showError(
            context: context,
            title: state.writeErrorMessage ?? 'Gagal menghapus',
          );
          context.read<AssetBloc>().add(const AssetWriteStatusReset());
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: AppText(
              LocaleKeys.assetScreenTitle.tr(),
              style: AppTextStyle.titleLarge,
              fontWeight: FontWeight.bold,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => context.pushToSearchAsset(),
              ),
              IconButton(
                icon: Badge(
                  isLabelVisible: state.hasActiveFilters,
                  child: const Icon(Icons.filter_list),
                ),
                onPressed: () => _showFilterSheet(context, state),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: LocaleKeys.assetScreenTabList.tr()),
                Tab(text: LocaleKeys.assetScreenTabStatistic.tr()),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // * Tab 1: Daftar Aset
              ScreenWrapper(child: _buildListView(context, state)),
              // * Tab 2: Statistik (Coming Soon)
              _buildStatisticView(context),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            heroTag: 'asset_fab',
            onPressed: () => context.pushToAddAsset(),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildListView(BuildContext context, AssetState state) {
    // * Handle loading state
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // * Handle error state
    if (state.status == AssetStatus.failure) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: context.colorScheme.error,
            ),
            const SizedBox(height: 16),
            AppText(
              state.errorMessage ?? LocaleKeys.assetScreenErrorOccurred.tr(),
              style: AppTextStyle.bodyMedium,
              color: context.colorScheme.error,
            ),
          ],
        ),
      );
    }

    // * Handle empty state
    if (state.assets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: context.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            AppText(
              LocaleKeys.assetScreenEmptyTitle.tr(),
              style: AppTextStyle.bodyLarge,
              color: context.colorScheme.outline,
            ),
            const SizedBox(height: 8),
            AppText(
              LocaleKeys.assetScreenEmptySubtitle.tr(),
              style: AppTextStyle.bodySmall,
              color: context.colorScheme.outline,
            ),
          ],
        ),
      );
    }

    // * Success state - ListView dengan AssetCard
    return RefreshIndicator(
      onRefresh: () async =>
          context.read<AssetBloc>().add(const AssetRefreshed()),
      child: ListView.separated(
        itemCount: state.assets.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final asset = state.assets[index];
          return AssetCard(
            asset: asset,
            onLongPress: () =>
                _openBatchDeleteDialog(context, state.assets, asset),
          );
        },
      ),
    );
  }

  void _openBatchDeleteDialog(
    BuildContext context,
    List<Asset> assets,
    Asset initialSelected,
  ) {
    AppBatchDeleteDialog.show<Asset>(
      context: context,
      title: 'Hapus Aset',
      items: assets,
      getId: (a) => a.ulid,
      searchStringOf: (a) => a.name,
      initialSelectedId: initialSelected.ulid,
      searchHint: 'Cari aset...',
      itemBuilder: (asset, isSelected, onToggle) =>
          AssetCard(asset: asset, onTap: onToggle),
      onDelete: (selected) {
        final ulids = selected.map((a) => a.ulid).toList();
        context.read<AssetBloc>().add(AssetBatchDeleted(ulids: ulids));
      },
    );
  }

  Widget _buildStatisticView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart_outlined,
            size: 80,
            color: context.colorScheme.outline.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 24),
          AppText(
            LocaleKeys.assetScreenStatisticTitle.tr(),
            style: AppTextStyle.headlineSmall,
            fontWeight: FontWeight.bold,
            color: context.colorScheme.outline,
          ),
          const SizedBox(height: 8),
          AppText(
            LocaleKeys.assetScreenComingSoon.tr(),
            style: AppTextStyle.bodyLarge,
            color: context.colorScheme.outline.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: context.colorScheme.primaryContainer.withValues(
                alpha: 0.3,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: AppText(
              LocaleKeys.assetScreenFeatureInDevelopment.tr(),
              style: AppTextStyle.bodySmall,
              color: context.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context, AssetState state) {
    AssetFilterSheet.show(
      context: context,
      initialFilter: AssetFilterData(
        type: state.currentTypeFilter,
        minBalance: state.currentMinBalance,
        maxBalance: state.currentMaxBalance,
        sortBy: state.currentSortBy,
        sortOrder: state.currentSortOrder,
      ),
      onApplyFilter: (filterData) {
        // * Apply filters
        context.read<AssetBloc>().add(
          AssetFiltered(
            type: filterData.type,
            minBalance: filterData.minBalance,
            maxBalance: filterData.maxBalance,
          ),
        );
        // * Apply sort
        context.read<AssetBloc>().add(
          AssetSorted(
            sortBy: filterData.sortBy,
            sortOrder: filterData.sortOrder,
          ),
        );
      },
      onReset: () {
        // * Clear all filters via bloc event
        context.read<AssetBloc>().add(const AssetFilterCleared());
      },
    );
  }
}
