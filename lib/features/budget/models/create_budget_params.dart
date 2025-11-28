import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import 'package:ikuyo_finance/features/budget/models/budget.dart';

class CreateBudgetParams extends Equatable {
  final String categoryUlid;
  final double amountLimit;
  final BudgetPeriod period;
  final DateTime? startDate;
  final DateTime? endDate;

  const CreateBudgetParams({
    required this.categoryUlid,
    required this.amountLimit,
    this.period = BudgetPeriod.monthly,
    this.startDate,
    this.endDate,
  });

  CreateBudgetParams copyWith({
    String? categoryUlid,
    double? amountLimit,
    BudgetPeriod? period,
    ValueGetter<DateTime?>? startDate,
    ValueGetter<DateTime?>? endDate,
  }) {
    return CreateBudgetParams(
      categoryUlid: categoryUlid ?? this.categoryUlid,
      amountLimit: amountLimit ?? this.amountLimit,
      period: period ?? this.period,
      startDate: startDate != null ? startDate() : this.startDate,
      endDate: endDate != null ? endDate() : this.endDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'categoryUlid': categoryUlid,
      'amountLimit': amountLimit,
      'period': period.name,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
    };
  }

  factory CreateBudgetParams.fromMap(Map<String, dynamic> map) {
    return CreateBudgetParams(
      categoryUlid: map['categoryUlid'] ?? '',
      amountLimit: (map['amountLimit'] ?? 0).toDouble(),
      period: map['period'] != null
          ? BudgetPeriod.values.byName(map['period'])
          : BudgetPeriod.monthly,
      startDate: map['startDate'] != null
          ? DateTime.parse(map['startDate'])
          : null,
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory CreateBudgetParams.fromJson(String source) =>
      CreateBudgetParams.fromMap(json.decode(source));

  @override
  String toString() {
    return 'CreateBudgetParams(categoryUlid: $categoryUlid, amountLimit: $amountLimit, period: $period, startDate: $startDate, endDate: $endDate)';
  }

  @override
  List<Object?> get props => [
    categoryUlid,
    amountLimit,
    period,
    startDate,
    endDate,
  ];
}
