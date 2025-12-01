import 'package:ikuyo_finance/features/category/models/category.dart';

/// * Model untuk menyimpan summary transaksi per kategori
class CategorySummary {
  final Category? category;
  final double totalAmount;
  final int transactionCount;
  final double percentage;

  const CategorySummary({
    this.category,
    required this.totalAmount,
    required this.transactionCount,
    this.percentage = 0,
  });

  /// * Copy with untuk update percentage
  CategorySummary copyWithPercentage(double newPercentage) {
    return CategorySummary(
      category: category,
      totalAmount: totalAmount,
      transactionCount: transactionCount,
      percentage: newPercentage,
    );
  }

  /// * Nama kategori dengan fallback
  String get categoryName => category?.name ?? 'Tanpa Kategori';

  /// * Icon kategori
  String? get categoryIcon => category?.icon;

  /// * Warna kategori
  String? get categoryColor => category?.color;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategorySummary &&
          runtimeType == other.runtimeType &&
          category?.ulid == other.category?.ulid &&
          totalAmount == other.totalAmount &&
          transactionCount == other.transactionCount;

  @override
  int get hashCode =>
      category.hashCode ^ totalAmount.hashCode ^ transactionCount.hashCode;
}

/// * Model untuk summary statistik keseluruhan
class StatisticSummary {
  final double totalIncome;
  final double totalExpense;
  final List<CategorySummary> incomeSummaries;
  final List<CategorySummary> expenseSummaries;

  const StatisticSummary({
    this.totalIncome = 0,
    this.totalExpense = 0,
    this.incomeSummaries = const [],
    this.expenseSummaries = const [],
  });

  /// * Selisih pendapatan dan pengeluaran
  double get balance => totalIncome - totalExpense;

  /// * Apakah surplus (pendapatan > pengeluaran)
  bool get isSurplus => balance > 0;

  /// * Apakah defisit (pengeluaran > pendapatan)
  bool get isDeficit => balance < 0;

  /// * Copy with
  StatisticSummary copyWith({
    double? totalIncome,
    double? totalExpense,
    List<CategorySummary>? incomeSummaries,
    List<CategorySummary>? expenseSummaries,
  }) {
    return StatisticSummary(
      totalIncome: totalIncome ?? this.totalIncome,
      totalExpense: totalExpense ?? this.totalExpense,
      incomeSummaries: incomeSummaries ?? this.incomeSummaries,
      expenseSummaries: expenseSummaries ?? this.expenseSummaries,
    );
  }
}
