import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';

/// Rentang periode anggaran dalam waktu lokal perangkat: [start, end).
/// * Batas dihitung dengan aritmetika hari kalender agar aman DST
class BudgetPeriodRange extends Equatable {
  final DateTime start;
  final DateTime end;

  const BudgetPeriodRange(this.start, this.end);

  factory BudgetPeriodRange.of(Budget budget, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    switch (budget.budgetPeriod) {
      case BudgetPeriod.weekly:
        final start = DateTime(
          ref.year,
          ref.month,
          ref.day - (ref.weekday - 1),
        );
        return BudgetPeriodRange(
          start,
          DateTime(start.year, start.month, start.day + 7),
        );
      case BudgetPeriod.yearly:
        return BudgetPeriodRange(
          DateTime(ref.year, 1, 1),
          DateTime(ref.year + 1, 1, 1),
        );
      case BudgetPeriod.custom:
        final s = budget.startDate;
        final e = budget.endDate;
        if (s != null && e != null) {
          return BudgetPeriodRange(
            DateTime(s.year, s.month, s.day),
            DateTime(e.year, e.month, e.day + 1),
          );
        }
        // * Kustom tanpa tanggal: jatuh ke bulan kalender berjalan
        return BudgetPeriodRange._month(ref);
      case BudgetPeriod.monthly:
        return BudgetPeriodRange._month(ref);
    }
  }

  factory BudgetPeriodRange._month(DateTime ref) => BudgetPeriodRange(
    DateTime(ref.year, ref.month, 1),
    DateTime(ref.year, ref.month + 1, 1),
  );

  bool contains(DateTime value) =>
      !value.isBefore(start) && value.isBefore(end);

  @override
  List<Object?> get props => [start, end];
}

/// Realisasi anggaran pada satu periode, dihitung dalam satuan minor
/// mata uang tersimpan agar penjumlahan tidak terkena drift double.
class BudgetProgress extends Equatable {
  final int spentMinor;
  final int limitMinor;
  final int decimalDigits;
  final BudgetPeriodRange period;

  const BudgetProgress({
    required this.spentMinor,
    required this.limitMinor,
    required this.decimalDigits,
    required this.period,
  });

  static int toMinor(double amount, int decimalDigits) =>
      (amount * math.pow(10, decimalDigits)).round();

  double _major(int minor) => minor / math.pow(10, decimalDigits);

  double get spent => _major(spentMinor);
  double get limit => _major(limitMinor);
  double get remaining => _major(limitMinor - spentMinor);

  /// Rasio tidak di-clamp; null bila limit tidak positif (tanpa bagi nol)
  double? get ratio => limitMinor > 0 ? spentMinor / limitMinor : null;

  /// Limit tersimpan yang tidak positif (data lama) selalu dianggap terlampaui
  bool get isOverspent => limitMinor <= 0 || spentMinor > limitMinor;

  /// Nilai bar visual saja yang di-clamp ke 0..1
  double get barValue {
    final r = ratio;
    if (r == null) return 1.0;
    return r.clamp(0.0, 1.0);
  }

  @override
  List<Object?> get props => [spentMinor, limitMinor, decimalDigits, period];
}
