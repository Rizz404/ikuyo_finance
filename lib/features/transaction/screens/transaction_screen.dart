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
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:ikuyo_finance/shared/widgets/screen_wrapper.dart';
import 'package:intl/intl.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;
  bool _isFilterExpanded = false;

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
    // * Update tab index reactively
    if (_tabController.indexIsChanging) return;
    setState(() {
      _currentTabIndex = _tabController.index;
    });
  }

  bool get _isDailyTab => _currentTabIndex == 0;
  bool get _isMonthlyTab => _currentTabIndex == 1;
  bool get _isDailyOrCalendarTab =>
      _currentTabIndex == 0 || _currentTabIndex == 2;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransactionBloc, TransactionState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: _isMonthlyTab
                ? _buildYearNavigator(context, state)
                : _buildMonthNavigator(context, state),
            actions: [
              // * Only show actions on Daily/Calendar tab
              if (_isDailyOrCalendarTab) ...[
                // * Search button - navigates to search screen
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => context.pushToSearchTransaction(),
                ),
                // * Filter button (includes sort options)
                IconButton(
                  icon: Badge(
                    isLabelVisible: state.hasActiveFilters,
                    child: const Icon(Icons.filter_list),
                  ),
                  onPressed: () => _showFilterSheet(context, state),
                ),
              ],
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Harian'),
                  Tab(text: 'Bulanan'),
                  Tab(text: 'Kalender'),
                ],
              ),
            ),
          ),
          body: ScreenWrapper(
            child: Column(
              children: [
                // * Active filters indicator (only on Daily tab)
                if (_isDailyTab)
                  Builder(
                    builder: (context) {
                      final assetState = context.read<AssetBloc>().state;
                      final categoryState = context.read<CategoryBloc>().state;

                      // * Find asset & category names
                      final assetName = state.currentAssetFilter != null
                          ? assetState.assets
                                .where(
                                  (a) => a.ulid == state.currentAssetFilter,
                                )
                                .map((a) => a.name)
                                .firstOrNull
                          : null;
                      final categoryName = state.currentCategoryFilter != null
                          ? categoryState.categories
                                .where(
                                  (c) => c.ulid == state.currentCategoryFilter,
                                )
                                .map((c) => c.name)
                                .firstOrNull
                          : null;

                      // * Build sort label
                      final sortLabel = TransactionFilterData(
                        sortBy: state.currentSortBy,
                        sortOrder: state.currentSortOrder,
                      ).sortLabel;

                      return TransactionActiveFilters(
                        hasActiveFilters: state.hasActiveFilters,
                        onClearFilters: () => context
                            .read<TransactionBloc>()
                            .add(const TransactionFilterCleared()),
                        isExpanded: _isFilterExpanded,
                        onToggleExpand: () => setState(() {
                          _isFilterExpanded = !_isFilterExpanded;
                        }),
                        assetName: assetName,
                        categoryName: categoryName,
                        startDate: state.currentStartDateFilter,
                        endDate: state.currentEndDateFilter,
                        minAmount: state.currentMinAmount,
                        maxAmount: state.currentMaxAmount,
                        sortLabel: sortLabel,
                      );
                    },
                  ),
                Expanded(child: _buildBody(context, state)),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            heroTag: 'transaction_fab',
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
        sortBy: state.currentSortBy,
        sortOrder: state.currentSortOrder,
      ),
      onApplyFilter: (filterData) {
        // * Apply filters
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
        // * Apply sort
        context.read<TransactionBloc>().add(
          TransactionSorted(
            sortBy: filterData.sortBy,
            sortOrder: filterData.sortOrder,
          ),
        );
      },
      onReset: () {
        // * Clear all filters via bloc event
        context.read<TransactionBloc>().add(const TransactionFilterCleared());
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
        MonthlyTransactionView(
          transactions: state.transactions,
          onRefresh: () =>
              context.read<TransactionBloc>().add(const TransactionRefreshed()),
          currentYear: state.currentYear,
          currentMonth: state.currentMonth.month,
        ),
        const CalendarTransactionView(),
      ],
    );
  }

  // * Month navigator widget with prev/next arrows
  Widget _buildMonthNavigator(BuildContext context, TransactionState state) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => _changeMonth(context, state.currentMonth, -1),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _showMonthPicker(context, state.currentMonth),
          child: AppText(
            DateFormat('MMMM yyyy', 'id_ID').format(state.currentMonth),
            style: AppTextStyle.titleMedium,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(Icons.chevron_right),
          onPressed: () => _changeMonth(context, state.currentMonth, 1),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  void _changeMonth(BuildContext context, DateTime current, int offset) {
    final newMonth = DateTime(current.year, current.month + offset, 1);
    context.read<TransactionBloc>().add(
      TransactionMonthChanged(month: newMonth),
    );
  }

  Future<void> _showMonthPicker(BuildContext context, DateTime current) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
    );

    if (selected != null && context.mounted) {
      context.read<TransactionBloc>().add(
        TransactionMonthChanged(month: selected),
      );
    }
  }

  // * Year navigator widget with prev/next arrows (for Monthly tab)
  Widget _buildYearNavigator(BuildContext context, TransactionState state) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => _changeYear(context, state.currentYear, -1),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _showYearPicker(context, state.currentYear),
          child: AppText(
            '${state.currentYear}',
            style: AppTextStyle.titleMedium,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => _changeYear(context, state.currentYear, 1),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  void _changeYear(BuildContext context, int currentYear, int offset) {
    context.read<TransactionBloc>().add(
      TransactionYearChanged(year: currentYear + offset),
    );
  }

  Future<void> _showYearPicker(BuildContext context, int currentYear) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(currentYear),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
    );

    if (selected != null && context.mounted) {
      context.read<TransactionBloc>().add(
        TransactionYearChanged(year: selected.year),
      );
    }
  }
}
