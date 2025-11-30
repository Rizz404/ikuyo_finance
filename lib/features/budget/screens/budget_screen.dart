import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/features/budget/bloc/budget_bloc.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/budget/widgets/budget_card.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:ikuyo_finance/shared/widgets/screen_wrapper.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  BudgetPeriod? _currentFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
      1 => BudgetPeriod.monthly,
      2 => BudgetPeriod.weekly,
      3 => BudgetPeriod.yearly,
      4 => BudgetPeriod.custom,
      _ => null,
    };

    if (newFilter != _currentFilter) {
      _currentFilter = newFilter;
      context.read<BudgetBloc>().add(BudgetFetched(period: newFilter));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BudgetBloc, BudgetState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const AppText(
              'Anggaran',
              style: AppTextStyle.titleLarge,
              fontWeight: FontWeight.bold,
            ),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Semua'),
                Tab(text: 'Bulanan'),
                Tab(text: 'Mingguan'),
                Tab(text: 'Tahunan'),
                Tab(text: 'Kustom'),
              ],
            ),
          ),
          body: ScreenWrapper(child: _buildBody(context, state)),
          floatingActionButton: FloatingActionButton(
            onPressed: () => context.go('/budget/add'),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, BudgetState state) {
    // * Handle loading state
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // * Handle error state
    if (state.status == BudgetStatus.failure) {
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
    if (state.budgets.isEmpty) {
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
              'Belum ada anggaran',
              style: AppTextStyle.bodyLarge,
              color: context.colorScheme.outline,
            ),
            const SizedBox(height: 8),
            AppText(
              'Tekan + untuk menambah anggaran baru',
              style: AppTextStyle.bodySmall,
              color: context.colorScheme.outline,
            ),
          ],
        ),
      );
    }

    // * Success state - ListView dengan BudgetCard
    return RefreshIndicator(
      onRefresh: () async =>
          context.read<BudgetBloc>().add(const BudgetRefreshed()),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: state.budgets.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final budget = state.budgets[index];
          return BudgetCard(budget: budget);
        },
      ),
    );
  }
}
