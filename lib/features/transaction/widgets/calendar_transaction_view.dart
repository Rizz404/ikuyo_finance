import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/transaction/bloc/transaction_bloc.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/features/transaction/widgets/transaction_tile.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:intl/intl.dart';

/// * Widget untuk menampilkan transaksi dalam format kalender bulanan
/// * Terintegrasi dengan currentMonth dari TransactionBloc
class CalendarTransactionView extends StatelessWidget {
  const CalendarTransactionView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransactionBloc, TransactionState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: () async {
            context.read<TransactionBloc>().add(const TransactionRefreshed());
          },
          child: _CalendarBody(
            currentMonth: state.currentMonth,
            transactions: state.transactions,
          ),
        );
      },
    );
  }
}

class _CalendarBody extends StatelessWidget {
  final DateTime currentMonth;
  final List<Transaction> transactions;

  const _CalendarBody({required this.currentMonth, required this.transactions});

  @override
  Widget build(BuildContext context) {
    // * Group transactions by date
    final groupedTransactions = _groupTransactionsByDate(transactions);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // * Weekday headers
          _buildWeekdayHeaders(context),
          const SizedBox(height: 8),
          // * Calendar grid
          _buildCalendarGrid(context, groupedTransactions),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeaders(BuildContext context) {
    const weekdays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    return Row(
      children: weekdays
          .map(
            (day) => Expanded(
              child: Center(
                child: AppText(
                  day,
                  style: AppTextStyle.labelMedium,
                  fontWeight: FontWeight.w600,
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildCalendarGrid(
    BuildContext context,
    Map<DateTime, List<Transaction>> groupedTransactions,
  ) {
    final firstDayOfMonth = DateTime(currentMonth.year, currentMonth.month, 1);
    final lastDayOfMonth = DateTime(
      currentMonth.year,
      currentMonth.month + 1,
      0,
    );
    final daysInMonth = lastDayOfMonth.day;

    // * Monday = 1, Sunday = 7 (adjust for Monday start)
    final firstWeekday = firstDayOfMonth.weekday;
    final leadingEmptyDays = firstWeekday - 1;

    // * Total cells needed
    final totalCells = leadingEmptyDays + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: List.generate(rows, (rowIndex) {
        return Row(
          children: List.generate(7, (colIndex) {
            final cellIndex = rowIndex * 7 + colIndex;
            final dayNumber = cellIndex - leadingEmptyDays + 1;

            // * Empty cell for days outside current month
            if (dayNumber < 1 || dayNumber > daysInMonth) {
              return const Expanded(child: SizedBox(height: 80));
            }

            final date = DateTime(
              currentMonth.year,
              currentMonth.month,
              dayNumber,
            );
            final dayTransactions = groupedTransactions[date] ?? [];

            return Expanded(
              child: _CalendarDayCell(
                date: date,
                transactions: dayTransactions,
                isToday: _isToday(date),
              ),
            );
          }),
        );
      }),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
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

    return grouped;
  }
}

/// * Single day cell in the calendar
class _CalendarDayCell extends StatelessWidget {
  final DateTime date;
  final List<Transaction> transactions;
  final bool isToday;

  const _CalendarDayCell({
    required this.date,
    required this.transactions,
    this.isToday = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasTransactions = transactions.isNotEmpty;
    final totalAmount = _calculateTotalAmount();

    return GestureDetector(
      onTap: hasTransactions ? () => _showTransactionModal(context) : null,
      child: Container(
        height: 80,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isToday
              ? context.colorScheme.primaryContainer.withValues(alpha: 0.3)
              : context.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isToday
                ? context.colorScheme.primary
                : context.colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: isToday ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // * Day number
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: AppText(
                '${date.day}',
                style: AppTextStyle.labelMedium,
                fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                color: isToday
                    ? context.colorScheme.primary
                    : context.colorScheme.onSurface,
              ),
            ),
            // * Transaction summary
            if (hasTransactions) ...[
              const Spacer(),
              _buildAmountSummary(context, totalAmount),
              const SizedBox(height: 2),
              _buildTransactionCount(context),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAmountSummary(BuildContext context, _DayTotal total) {
    // * Show net amount (income - expense)
    final netAmount = total.income - total.expense;
    final isPositive = netAmount >= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: AppText(
        _formatCompactCurrency(netAmount.abs()),
        style: AppTextStyle.labelSmall,
        fontWeight: FontWeight.w600,
        color: isPositive ? context.semantic.success : context.semantic.error,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTransactionCount(BuildContext context) {
    final count = transactions.length;

    // * Show indicator if more than 3 transactions
    if (count > 3) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: context.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(4),
        ),
        child: AppText(
          '$count+',
          style: AppTextStyle.labelSmall,
          color: context.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    // * Show dots for 1-3 transactions
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (index) => Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: context.colorScheme.primary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  _DayTotal _calculateTotalAmount() {
    double income = 0;
    double expense = 0;

    for (final transaction in transactions) {
      final isExpense =
          transaction.category.target?.categoryType == CategoryType.expense;
      if (isExpense) {
        expense += transaction.amount;
      } else {
        income += transaction.amount;
      }
    }

    return _DayTotal(income: income, expense: expense);
  }

  String _formatCompactCurrency(double amount) {
    if (amount >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}Jt';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toStringAsFixed(0);
  }

  void _showTransactionModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _TransactionDayModal(date: date, transactions: transactions),
    );
  }
}

/// * Modal showing transactions for a specific day
class _TransactionDayModal extends StatelessWidget {
  final DateTime date;
  final List<Transaction> transactions;

  const _TransactionDayModal({required this.date, required this.transactions});

  @override
  Widget build(BuildContext context) {
    final totalIncome = transactions
        .where((t) => t.category.target?.categoryType == CategoryType.income)
        .fold<double>(0, (sum, t) => sum + t.amount);

    final totalExpense = transactions
        .where((t) => t.category.target?.categoryType == CategoryType.expense)
        .fold<double>(0, (sum, t) => sum + t.amount);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // * Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: context.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // * Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    AppText(
                      DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date),
                      style: AppTextStyle.titleMedium,
                      fontWeight: FontWeight.w600,
                    ),
                    const SizedBox(height: 8),
                    // * Total summary
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (totalIncome > 0) ...[
                          AppText(
                            '+${_formatCurrency(totalIncome)}',
                            style: AppTextStyle.labelMedium,
                            color: context.semantic.success,
                            fontWeight: FontWeight.w600,
                          ),
                          const SizedBox(width: 16),
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
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: context.colorScheme.outlineVariant),
              // * Transaction list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    return TransactionTile(transaction: transactions[index]);
                  },
                ),
              ),
            ],
          ),
        );
      },
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

/// * Helper class for day totals
class _DayTotal {
  final double income;
  final double expense;

  const _DayTotal({required this.income, required this.expense});
}
