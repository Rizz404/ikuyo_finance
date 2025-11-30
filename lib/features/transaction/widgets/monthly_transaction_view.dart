import 'package:flutter/material.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:intl/intl.dart';

/// * Widget untuk menampilkan transaksi yang dikelompokkan berdasarkan bulan
/// * Pure UI widget, no bloc logic - all callbacks handled by parent
class MonthlyTransactionView extends StatefulWidget {
  final List<Transaction> transactions;
  final VoidCallback onRefresh;
  final int currentYear;
  final int currentMonth;

  const MonthlyTransactionView({
    super.key,
    required this.transactions,
    required this.onRefresh,
    required this.currentYear,
    required this.currentMonth,
  });

  @override
  State<MonthlyTransactionView> createState() => _MonthlyTransactionViewState();
}

class _MonthlyTransactionViewState extends State<MonthlyTransactionView> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    // * Initialize scroll controller with initial offset to center current month
    final initialIndex = widget.currentMonth - 1;
    _scrollController = ScrollController(
      initialScrollOffset: initialIndex * 80.0, // * Approximate card height
    );
  }

  @override
  void didUpdateWidget(covariant MonthlyTransactionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // * Scroll to current month when year changes
    if (oldWidget.currentYear != widget.currentYear) {
      _scrollToCurrentMonth();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentMonth() {
    if (!_scrollController.hasClients) return;
    final targetIndex = widget.currentMonth - 1;
    final targetOffset = targetIndex * 80.0;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    // * Group transactions by month
    final groupedTransactions = _groupTransactionsByMonth(widget.transactions);

    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: 12, // * Show 12 months (January - December)
        itemBuilder: (context, index) {
          final month = index + 1;
          final transactions = groupedTransactions[month] ?? [];
          return _monthlyTransactionCard(
            context: context,
            month: month,
            transactions: transactions,
          );
        },
      ),
    );
  }

  Map<int, List<Transaction>> _groupTransactionsByMonth(
    List<Transaction> txns,
  ) {
    final Map<int, List<Transaction>> grouped = {};

    for (final transaction in txns) {
      final date = transaction.transactionDate ?? transaction.createdAt;
      final month = date.month;

      if (grouped.containsKey(month)) {
        grouped[month]!.add(transaction);
      } else {
        grouped[month] = [transaction];
      }
    }

    // * Sort by month descending (newest first)
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Map.fromEntries(
      sortedKeys.map((key) => MapEntry(key, grouped[key]!)),
    );
  }

  Widget _monthlyTransactionCard({
    required BuildContext context,
    required int month,
    required List<Transaction> transactions,
  }) {
    final totalIncome = transactions
        .where((t) => t.category.target?.categoryType == CategoryType.income)
        .fold<double>(0, (sum, t) => sum + t.amount);

    final totalExpense = transactions
        .where((t) => t.category.target?.categoryType == CategoryType.expense)
        .fold<double>(0, (sum, t) => sum + t.amount);

    final balance = totalIncome - totalExpense;
    final transactionCount = transactions.length;
    final hasTransactions = transactions.isNotEmpty;

    // * Get month name
    final monthDate = DateTime(widget.currentYear, month);
    final monthName = DateFormat('MMMM', 'id_ID').format(monthDate);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: context.colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // * Month header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hasTransactions
                  ? context.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    )
                  : context.colorScheme.surfaceContainerLow.withValues(
                      alpha: 0.3,
                    ),
              borderRadius: hasTransactions
                  ? const BorderRadius.vertical(top: Radius.circular(16))
                  : BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      monthName,
                      style: AppTextStyle.titleMedium,
                      fontWeight: FontWeight.w600,
                      color: hasTransactions
                          ? null
                          : context.colorScheme.outline,
                    ),
                    const SizedBox(height: 2),
                    AppText(
                      hasTransactions
                          ? '$transactionCount transaksi'
                          : 'Belum ada transaksi',
                      style: AppTextStyle.labelSmall,
                      color: context.colorScheme.outline,
                    ),
                  ],
                ),
                // * Balance indicator (only show if has transactions)
                if (hasTransactions)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: balance >= 0
                          ? context.semantic.success.withValues(alpha: 0.15)
                          : context.semantic.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: AppText(
                      '${balance >= 0 ? '+' : ''}${_formatCurrency(balance)}',
                      style: AppTextStyle.labelMedium,
                      fontWeight: FontWeight.w600,
                      color: balance >= 0
                          ? context.semantic.success
                          : context.semantic.error,
                    ),
                  ),
              ],
            ),
          ),
          // * Income & Expense summary (only show if has transactions)
          if (hasTransactions)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _summaryItem(
                      context: context,
                      icon: Icons.arrow_downward_rounded,
                      label: 'Pemasukan',
                      amount: totalIncome,
                      color: context.semantic.success,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: context.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                  Expanded(
                    child: _summaryItem(
                      context: context,
                      icon: Icons.arrow_upward_rounded,
                      label: 'Pengeluaran',
                      amount: totalExpense,
                      color: context.semantic.error,
                    ),
                  ),
                ],
              ),
            ),
          // * Category breakdown (top 3)
          if (hasTransactions) _buildCategoryBreakdown(context, transactions),
        ],
      ),
    );
  }

  Widget _summaryItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required double amount,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            AppText(
              label,
              style: AppTextStyle.labelSmall,
              color: context.colorScheme.outline,
            ),
          ],
        ),
        const SizedBox(height: 4),
        AppText(
          _formatCurrency(amount),
          style: AppTextStyle.bodyMedium,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ],
    );
  }

  Widget _buildCategoryBreakdown(
    BuildContext context,
    List<Transaction> transactions,
  ) {
    // * Group by category and sum amounts (only expenses)
    final expenseTransactions = transactions.where(
      (t) => t.category.target?.categoryType == CategoryType.expense,
    );

    if (expenseTransactions.isEmpty) return const SizedBox.shrink();

    final Map<String, double> categoryTotals = {};
    final Map<String, Category> categoryMap = {};

    for (final t in expenseTransactions) {
      final category = t.category.target;
      final key = category?.ulid ?? 'unknown';
      categoryTotals[key] = (categoryTotals[key] ?? 0) + t.amount;
      if (category != null) categoryMap[key] = category;
    }

    // * Sort by amount and take top 3
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topCategories = sortedCategories.take(3).toList();
    final totalExpense = expenseTransactions.fold<double>(
      0,
      (sum, t) => sum + t.amount,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 8),
          AppText(
            'Top Pengeluaran',
            style: AppTextStyle.labelSmall,
            color: context.colorScheme.outline,
          ),
          const SizedBox(height: 8),
          ...topCategories.map((entry) {
            final category = categoryMap[entry.key];
            final percentage = (entry.value / totalExpense * 100).round();

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  // * Category color indicator
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _getCategoryColor(category, context),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppText(
                      category?.name ?? 'Tanpa Kategori',
                      style: AppTextStyle.labelMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AppText(
                    '$percentage%',
                    style: AppTextStyle.labelSmall,
                    color: context.colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  AppText(
                    _formatCurrency(entry.value),
                    style: AppTextStyle.labelMedium,
                    fontWeight: FontWeight.w600,
                  ),
                ],
              ),
            );
          }),
        ],
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
    return context.semantic.error;
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    ).format(amount);
  }
}
