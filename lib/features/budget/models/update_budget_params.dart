import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import 'package:ikuyo_finance/features/budget/models/budget.dart';

class UpdateBudgetParams extends Equatable {
  final String ulid;
  final String? categoryUlid;
  final double? amountLimit;
  final BudgetPeriod? period;
  final DateTime? startDate;
  final DateTime? endDate;

  const UpdateBudgetParams({
    required this.ulid,
    this.categoryUlid,
    this.amountLimit,
    this.period,
    this.startDate,
    this.endDate,
  });

  UpdateBudgetParams copyWith({
    String? ulid,
    ValueGetter<String?>? categoryUlid,
    ValueGetter<double?>? amountLimit,
    ValueGetter<BudgetPeriod?>? period,
    ValueGetter<DateTime?>? startDate,
    ValueGetter<DateTime?>? endDate,
  }) {
    return UpdateBudgetParams(
      ulid: ulid ?? this.ulid,
      categoryUlid: categoryUlid != null ? categoryUlid() : this.categoryUlid,
      amountLimit: amountLimit != null ? amountLimit() : this.amountLimit,
      period: period != null ? period() : this.period,
      startDate: startDate != null ? startDate() : this.startDate,
      endDate: endDate != null ? endDate() : this.endDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ulid': ulid,
      'categoryUlid': categoryUlid,
      'amountLimit': amountLimit,
      'period': period?.name,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
    };
  }

  factory UpdateBudgetParams.fromMap(Map<String, dynamic> map) {
    return UpdateBudgetParams(
      ulid: map['ulid'] ?? '',
      categoryUlid: map['categoryUlid'],
      amountLimit: map['amountLimit']?.toDouble(),
      period: map['period'] != null
          ? BudgetPeriod.values.byName(map['period'])
          : null,
      startDate: map['startDate'] != null
          ? DateTime.parse(map['startDate'])
          : null,
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory UpdateBudgetParams.fromJson(String source) =>
      UpdateBudgetParams.fromMap(json.decode(source));

  @override
  String toString() {
    return 'UpdateBudgetParams(ulid: $ulid, categoryUlid: $categoryUlid, amountLimit: $amountLimit, period: $period, startDate: $startDate, endDate: $endDate)';
  }

  @override
  List<Object?> get props => [
    ulid,
    categoryUlid,
    amountLimit,
    period,
    startDate,
    endDate,
  ];
}
