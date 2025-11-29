import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/features/transaction/bloc/transaction_bloc.dart';
import 'package:ikuyo_finance/features/transaction/widgets/calendar_transaction_view.dart';
import 'package:ikuyo_finance/features/transaction/widgets/daily_transaction_view.dart';
import 'package:ikuyo_finance/features/transaction/widgets/monthly_transaction_view.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransactionBloc, TransactionState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const AppText(
              'Transaksi',
              style: AppTextStyle.titleLarge,
              fontWeight: FontWeight.bold,
            ),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Harian'),
                Tab(text: 'Bulanan'),
                Tab(text: 'Kalender'),
              ],
            ),
          ),
          body: _buildBody(context, state),
          floatingActionButton: FloatingActionButton(
            onPressed: () => context.go('/transaction/add'),
            child: const Icon(Icons.add),
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
        ),
        const MonthlyTransactionView(),
        const CalendarTransactionView(),
      ],
    );
  }
}
