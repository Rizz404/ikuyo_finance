import 'package:flutter/material.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/features/transaction/widgets/transaction_tile.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:intl/intl.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';

/// * Widget untuk menampilkan transaksi yang dikelompokkan berdasarkan hari
/// * Menerima data transactions melalui constructor (tidak langsung akses Bloc)
class DailyTransactionView extends StatelessWidget {
  const DailyTransactionView({
    super.key,
    required this.transactions,
    required this.onRefresh,
  });

  final List<Transaction> transactions;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
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
    final groupedTransactions = _groupTransactionsByDate(transactions);

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: groupedTransactions.length,
        itemBuilder: (context, index) {
          final entry = groupedTransactions.entries.elementAt(index);
          return _dailyTransactionGroup(
            context: context,
            date: entry.key,
            transactions: entry.value,
          );
        },
      ),
    );
  }

  Map<DateTime, List<Transaction>> _groupTransactionsByDate(
    List<Transaction> txns,
  ) {
    final Map<DateTime, List<Transaction>> grouped = {};

    for (final transaction in txns) {
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

  Widget _dailyTransactionGroup({
    required BuildContext context,
    required DateTime date,
    required List<Transaction> transactions,
  }) {
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
        _dateHeader(
          context: context,
          date: date,
          totalIncome: totalIncome,
          totalExpense: totalExpense,
        ),
        // * Transaction items
        ...transactions.map(
          (transaction) => TransactionTile(transaction: transaction),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // * Date Header with totals

  Widget _dateHeader({
    required BuildContext context,
    required DateTime date,
    required double totalIncome,
    required double totalExpense,
  }) {
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
