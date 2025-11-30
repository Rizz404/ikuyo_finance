import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/router/app_navigator.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/features/asset/bloc/asset_bloc.dart';
import 'package:ikuyo_finance/features/category/bloc/category_bloc.dart';
import 'package:ikuyo_finance/features/transaction/bloc/transaction_bloc.dart';
import 'package:ikuyo_finance/features/transaction/widgets/calendar_transaction_view.dart';
import 'package:ikuyo_finance/features/transaction/widgets/daily_transaction_view.dart';
import 'package:ikuyo_finance/features/transaction/widgets/monthly_transaction_view.dart';
import 'package:ikuyo_finance/features/transaction/widgets/transaction_active_filters.dart';
import 'package:ikuyo_finance/features/transaction/widgets/transaction_filter_sheet.dart';
import 'package:ikuyo_finance/features/transaction/widgets/transaction_search_bar.dart';
import 'package:ikuyo_finance/features/transaction/widgets/transaction_sort_chip.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:ikuyo_finance/shared/widgets/screen_wrapper.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    // * Hide search when switching away from Daily tab
    if (_tabController.index != 0 && _isSearchVisible) {
      setState(() => _isSearchVisible = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransactionBloc, TransactionState>(
      builder: (context, state) {
        final isDailyTab = _tabController.index == 0;

        return Scaffold(
          appBar: AppBar(
            title: _isSearchVisible
                ? TransactionSearchBar(
                    currentQuery: state.currentSearchQuery,
                    onChanged: (value) => context.read<TransactionBloc>().add(
                      TransactionSearched(query: value ?? ''),
                    ),
                    onClear: () => context.read<TransactionBloc>().add(
                      const TransactionSearched(query: ''),
                    ),
                  )
                : const AppText(
                    'Transaksi',
                    style: AppTextStyle.titleLarge,
                    fontWeight: FontWeight.bold,
                  ),
            actions: [
              // * Only show actions on Daily tab
              if (isDailyTab) ...[
                // * Search toggle
                IconButton(
                  icon: Icon(_isSearchVisible ? Icons.close : Icons.search),
                  onPressed: () {
                    setState(() => _isSearchVisible = !_isSearchVisible);
                    if (!_isSearchVisible && state.currentSearchQuery != null) {
                      // * Clear search when closing
                      context.read<TransactionBloc>().add(
                        const TransactionSearched(query: ''),
                      );
                    }
                  },
                ),
                // * Sort chip
                TransactionSortChip(
                  currentSortBy: state.currentSortBy,
                  currentSortOrder: state.currentSortOrder,
                  onSortChanged: (sortBy, sortOrder) {
                    context.read<TransactionBloc>().add(
                      TransactionSorted(sortBy: sortBy, sortOrder: sortOrder),
                    );
                  },
                ),
                // * Filter button
                IconButton(
                  icon: Badge(
                    isLabelVisible: state.hasActiveFilters,
                    child: const Icon(Icons.filter_list),
                  ),
                  onPressed: () => _showFilterSheet(context, state),
                ),
              ],
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Harian'),
                Tab(text: 'Bulanan'),
                Tab(text: 'Kalender'),
              ],
            ),
          ),
          body: ScreenWrapper(
            child: Column(
              children: [
                // * Active filters indicator (only on Daily tab)
                if (isDailyTab)
                  TransactionActiveFilters(
                    hasActiveFilters: state.hasActiveFilters,
                    onClearFilters: () => context.read<TransactionBloc>().add(
                      const TransactionFilterCleared(),
                    ),
                  ),
                Expanded(child: _buildBody(context, state)),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => context.pushToAddTransaction(),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  void _showFilterSheet(BuildContext context, TransactionState state) {
    final assetState = context.read<AssetBloc>().state;
    final categoryState = context.read<CategoryBloc>().state;

    TransactionFilterSheet.show(
      context: context,
      assets: assetState.assets,
      categories: categoryState.categories,
      initialFilter: TransactionFilterData(
        assetUlid: state.currentAssetFilter,
        categoryUlid: state.currentCategoryFilter,
        startDate: state.currentStartDateFilter,
        endDate: state.currentEndDateFilter,
        minAmount: state.currentMinAmount,
        maxAmount: state.currentMaxAmount,
      ),
      onApplyFilter: (filterData) {
        context.read<TransactionBloc>().add(
          TransactionFiltered(
            assetUlid: filterData.assetUlid,
            categoryUlid: filterData.categoryUlid,
            startDate: filterData.startDate,
            endDate: filterData.endDate,
            minAmount: filterData.minAmount,
            maxAmount: filterData.maxAmount,
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, TransactionState state) {
    // * Handle loading state
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // * Handle error state
    if (state.status == TransactionStatus.failure) {
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

    // * Success state - pass data to child views
    return TabBarView(
      controller: _tabController,
      children: [
        DailyTransactionView(
          transactions: state.transactions,
          onRefresh: () =>
              context.read<TransactionBloc>().add(const TransactionRefreshed()),
          onLoadMore: () => context.read<TransactionBloc>().add(
            const TransactionFetchedMore(),
          ),
          hasReachedMax: state.hasReachedMax,
          isLoadingMore: state.isLoadingMore,
        ),
        const MonthlyTransactionView(),
        const CalendarTransactionView(),
      ],
    );
  }
}
