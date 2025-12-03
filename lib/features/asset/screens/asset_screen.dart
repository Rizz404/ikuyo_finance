import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/router/app_navigator.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/features/asset/bloc/asset_bloc.dart';
import 'package:ikuyo_finance/features/asset/widgets/asset_card.dart';
import 'package:ikuyo_finance/features/asset/widgets/asset_filter_sheet.dart';
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
    return BlocBuilder<AssetBloc, AssetState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const AppText(
              'Aset',
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
              tabs: const [
                Tab(text: 'Daftar'),
                Tab(text: 'Statistik'),
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
              state.errorMessage ?? 'Terjadi kesalahan',
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
              'Belum ada aset',
              style: AppTextStyle.bodyLarge,
              color: context.colorScheme.outline,
            ),
            const SizedBox(height: 8),
            AppText(
              'Tekan + untuk menambah aset baru',
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
          return AssetCard(asset: asset);
        },
      ),
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
            'Statistik',
            style: AppTextStyle.headlineSmall,
            fontWeight: FontWeight.bold,
            color: context.colorScheme.outline,
          ),
          const SizedBox(height: 8),
          AppText(
            'Coming Soon',
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
              'Fitur ini sedang dalam pengembangan',
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
