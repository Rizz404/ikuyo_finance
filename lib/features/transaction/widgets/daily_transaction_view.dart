import 'package:flutter/material.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/features/transaction/widgets/transaction_tile.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:intl/intl.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';

/// * Widget untuk menampilkan transaksi yang dikelompokkan berdasarkan hari
/// * Pure UI widget, no bloc logic - all callbacks handled by parent
/// * Supports infinite scroll with cursor-based pagination
class DailyTransactionView extends StatefulWidget {
  final List<Transaction> transactions;
  final VoidCallback onRefresh;
  final VoidCallback onLoadMore;
  final bool hasReachedMax;
  final bool isLoadingMore;

  const DailyTransactionView({
    super.key,
    required this.transactions,
    required this.onRefresh,
    required this.onLoadMore,
    this.hasReachedMax = false,
    this.isLoadingMore = false,
  });

  @override
  State<DailyTransactionView> createState() => _DailyTransactionViewState();
}

class _DailyTransactionViewState extends State<DailyTransactionView> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isBottom && !widget.hasReachedMax && !widget.isLoadingMore) {
      widget.onLoadMore();
    }
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    // * Trigger load more when 200px from bottom
    return currentScroll >= (maxScroll - 200);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.transactions.isEmpty) {
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
    final groupedTransactions = _groupTransactionsByDate(widget.transactions);

    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: groupedTransactions.length + (widget.hasReachedMax ? 0 : 1),
        itemBuilder: (context, index) {
          // * Show loading indicator at the bottom
          if (index >= groupedTransactions.length) {
            return _buildLoadingIndicator();
          }

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

  Widget _buildLoadingIndicator() {
    return Center(
      child: widget.isLoadingMore
          ? SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.colorScheme.primary,
              ),
            )
          : const SizedBox.shrink(),
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
