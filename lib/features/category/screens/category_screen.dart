import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/router/app_navigator.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/features/category/bloc/category_bloc.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/category/widgets/category_card.dart';
import 'package:ikuyo_finance/features/category/widgets/category_filter_sheet.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:ikuyo_finance/shared/widgets/screen_wrapper.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  CategoryType? _currentFilter;

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
    if (_tabController.indexIsChanging) return;

    final newFilter = switch (_tabController.index) {
      0 => null, // * Semua
      1 => CategoryType.expense,
      2 => CategoryType.income,
      _ => null,
    };

    if (newFilter != _currentFilter) {
      _currentFilter = newFilter;
      context.read<CategoryBloc>().add(CategoryFetched(type: newFilter));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CategoryBloc, CategoryState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: AppText(
              LocaleKeys.categoryScreenTitle.tr(),
              style: AppTextStyle.titleLarge,
              fontWeight: FontWeight.bold,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => context.pushToSearchCategory(),
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
                Tab(text: LocaleKeys.categoryScreenTabAll.tr()),
                Tab(text: LocaleKeys.categoryScreenTabExpense.tr()),
                Tab(text: LocaleKeys.categoryScreenTabIncome.tr()),
              ],
            ),
          ),
          body: ScreenWrapper(child: _buildBody(context, state)),
          floatingActionButton: FloatingActionButton(
            heroTag: 'category_fab',
            onPressed: () => context.pushToAddCategory(),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, CategoryState state) {
    // * Handle loading state
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // * Handle error state
    if (state.status == CategoryStatus.failure) {
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
              state.errorMessage ?? LocaleKeys.categoryScreenErrorOccurred.tr(),
              style: AppTextStyle.bodyMedium,
              color: context.colorScheme.error,
            ),
          ],
        ),
      );
    }

    // * Handle empty state
    if (state.categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 64,
              color: context.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            AppText(
              LocaleKeys.categoryScreenEmptyTitle.tr(),
              style: AppTextStyle.bodyLarge,
              color: context.colorScheme.outline,
            ),
            const SizedBox(height: 8),
            AppText(
              LocaleKeys.categoryScreenEmptySubtitle.tr(),
              style: AppTextStyle.bodySmall,
              color: context.colorScheme.outline,
            ),
          ],
        ),
      );
    }

    // * Success state - GridView dengan CategoryCard
    return RefreshIndicator(
      onRefresh: () async =>
          context.read<CategoryBloc>().add(const CategoryRefreshed()),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.95,
        ),
        itemCount: state.categories.length,
        itemBuilder: (context, index) {
          final category = state.categories[index];
          return CategoryCard(category: category);
        },
      ),
    );
  }

  void _showFilterSheet(BuildContext context, CategoryState state) {
    // * Get root categories for parent filter options
    final rootCategories = state.categories
        .where((c) => c.parent.target == null)
        .toList();

    CategoryFilterSheet.show(
      context: context,
      parentCategories: rootCategories,
      initialFilter: CategoryFilterData(
        type: state.currentTypeFilter,
        parentUlid: state.currentParentUlidFilter,
        isRootOnly: state.currentIsRootOnlyFilter,
        sortBy: state.currentSortBy,
        sortOrder: state.currentSortOrder,
      ),
      onApplyFilter: (filterData) {
        // * Apply filters
        context.read<CategoryBloc>().add(
          CategoryFiltered(
            type: filterData.type,
            parentUlid: filterData.parentUlid,
            isRootOnly: filterData.isRootOnly,
          ),
        );
        // * Apply sort
        context.read<CategoryBloc>().add(
          CategorySorted(
            sortBy: filterData.sortBy,
            sortOrder: filterData.sortOrder,
          ),
        );
      },
      onReset: () {
        // * Clear all filters via bloc event
        context.read<CategoryBloc>().add(const CategoryFilterCleared());
      },
    );
  }
}
