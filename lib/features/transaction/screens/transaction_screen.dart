import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/transaction/bloc/transaction_bloc.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:intl/intl.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const AppText(
          'Transaksi',
          style: AppTextStyle.titleLarge,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Harian'),
            Tab(text: 'Bulanan'),
            Tab(text: 'Kalender'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _DailyTransactionView(),
          _MonthlyTransactionView(),
          _CalendarTransactionView(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/transaction/add'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// * Daily Transaction View - Groups transactions by day
class _DailyTransactionView extends StatelessWidget {
  const _DailyTransactionView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransactionBloc, TransactionState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

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

        if (state.transactions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 64,
                  color: context.colorScheme.outline,
                ),
                const SizedBox(height: 16),
                AppText(
                  'Belum ada transaksi',
                  style: AppTextStyle.bodyLarge,
                  color: context.colorScheme.outline,
                ),
              ],
            ),
          );
        }

        // * Group transactions by date
        final groupedTransactions = _groupTransactionsByDate(
          state.transactions,
        );

        return RefreshIndicator(
          onRefresh: () async {
            context.read<TransactionBloc>().add(const TransactionRefreshed());
          },
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: groupedTransactions.length,
            itemBuilder: (context, index) {
              final entry = groupedTransactions.entries.elementAt(index);
              return _DailyTransactionGroup(
                date: entry.key,
                transactions: entry.value,
              );
            },
          ),
        );
      },
    );
  }

  Map<DateTime, List<Transaction>> _groupTransactionsByDate(
    List<Transaction> transactions,
  ) {
    final Map<DateTime, List<Transaction>> grouped = {};

    for (final transaction in transactions) {
      final date = transaction.transactionDate ?? transaction.createdAt;
      final dateOnly = DateTime(date.year, date.month, date.day);

      if (grouped.containsKey(dateOnly)) {
        grouped[dateOnly]!.add(transaction);
      } else {
        grouped[dateOnly] = [transaction];
      }
    }

    // * Sort by date descending (newest first)
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Map.fromEntries(
      sortedKeys.map((key) => MapEntry(key, grouped[key]!)),
    );
  }
}

// * Daily Transaction Group - Shows date header and list of transactions
class _DailyTransactionGroup extends StatelessWidget {
  final DateTime date;
  final List<Transaction> transactions;

  const _DailyTransactionGroup({
    required this.date,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    final totalIncome = transactions
        .where((t) => t.category.target?.categoryType == CategoryType.income)
        .fold<double>(0, (sum, t) => sum + t.amount);

    final totalExpense = transactions
        .where((t) => t.category.target?.categoryType == CategoryType.expense)
        .fold<double>(0, (sum, t) => sum + t.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // * Date header
        _DateHeader(
          date: date,
          totalIncome: totalIncome,
          totalExpense: totalExpense,
        ),
        // * Transaction items
        ...transactions.map(
          (transaction) => _TransactionItem(transaction: transaction),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// * Date Header with totals
class _DateHeader extends StatelessWidget {
  final DateTime date;
  final double totalIncome;
  final double totalExpense;

  const _DateHeader({
    required this.date,
    required this.totalIncome,
    required this.totalExpense,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    String dateText;
    if (date == today) {
      dateText = 'Hari Ini';
    } else if (date == yesterday) {
      dateText = 'Kemarin';
    } else {
      dateText = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: AppText(
              dateText,
              style: AppTextStyle.titleSmall,
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            children: [
              if (totalIncome > 0) ...[
                AppText(
                  '+${_formatCurrency(totalIncome)}',
                  style: AppTextStyle.labelMedium,
                  color: context.semantic.success,
                  fontWeight: FontWeight.w600,
                ),
                const SizedBox(width: 12),
              ],
              if (totalExpense > 0)
                AppText(
                  '-${_formatCurrency(totalExpense)}',
                  style: AppTextStyle.labelMedium,
                  color: context.semantic.error,
                  fontWeight: FontWeight.w600,
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    ).format(amount);
  }
}

// * Single Transaction Item
class _TransactionItem extends StatelessWidget {
  final Transaction transaction;

  const _TransactionItem({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final category = transaction.category.target;
    final wallet = transaction.wallet.target;
    final isExpense = category?.categoryType == CategoryType.expense;

    return GestureDetector(
      onTap: () => context.go('/transaction/edit', extra: transaction),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            // * Category Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getCategoryColor(
                  category,
                  context,
                ).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getCategoryIcon(category),
                color: _getCategoryColor(category, context),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            // * Transaction Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    category?.name ?? 'Tanpa Kategori',
                    style: AppTextStyle.bodyMedium,
                    fontWeight: FontWeight.w600,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 14,
                        color: context.colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: AppText(
                          wallet?.name ?? 'Unknown Wallet',
                          style: AppTextStyle.labelSmall,
                          color: context.colorScheme.outline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (transaction.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    AppText(
                      transaction.description!,
                      style: AppTextStyle.labelSmall,
                      color: context.colorScheme.onSurfaceVariant,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // * Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AppText(
                  '${isExpense ? '-' : '+'}${_formatCurrency(transaction.amount)}',
                  style: AppTextStyle.bodyMedium,
                  fontWeight: FontWeight.bold,
                  color: isExpense
                      ? context.semantic.error
                      : context.semantic.success,
                ),
                const SizedBox(height: 4),
                AppText(
                  DateFormat('HH:mm').format(
                    transaction.transactionDate ?? transaction.createdAt,
                  ),
                  style: AppTextStyle.labelSmall,
                  color: context.colorScheme.outline,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(Category? category, BuildContext context) {
    if (category == null) return context.colorScheme.outline;
    if (category.color != null) {
      try {
        return Color(int.parse(category.color!.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    return category.categoryType == CategoryType.expense
        ? context.semantic.error
        : context.semantic.success;
  }

  IconData _getCategoryIcon(Category? category) {
    if (category?.icon != null) {
      // TODO: Map icon string to IconData
      return Icons.category_outlined;
    }
    return Icons.category_outlined;
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    ).format(amount);
  }
}

// * Monthly Transaction View - Placeholder
class _MonthlyTransactionView extends StatelessWidget {
  const _MonthlyTransactionView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_month_outlined,
            size: 64,
            color: context.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          AppText(
            'Tampilan Bulanan',
            style: AppTextStyle.bodyLarge,
            color: context.colorScheme.outline,
          ),
          const SizedBox(height: 8),
          AppText(
            'Coming Soon',
            style: AppTextStyle.bodySmall,
            color: context.colorScheme.outline,
          ),
        ],
      ),
    );
  }
}

// * Calendar Transaction View - Placeholder
class _CalendarTransactionView extends StatelessWidget {
  const _CalendarTransactionView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 64,
            color: context.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          AppText(
            'Tampilan Kalender',
            style: AppTextStyle.bodyLarge,
            color: context.colorScheme.outline,
          ),
          const SizedBox(height: 8),
          AppText(
            'Coming Soon',
            style: AppTextStyle.bodySmall,
            color: context.colorScheme.outline,
          ),
        ],
      ),
    );
  }
}
