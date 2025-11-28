import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import 'package:ikuyo_finance/features/budget/models/budget.dart';

class GetBudgetsParams extends Equatable {
  final String? cursor;
  final int limit = 20;
  final BudgetPeriod? period;
  final String? categoryUlid;

  const GetBudgetsParams({this.cursor, this.period, this.categoryUlid});

  GetBudgetsParams copyWith({
    ValueGetter<String?>? cursor,
    ValueGetter<BudgetPeriod?>? period,
    ValueGetter<String?>? categoryUlid,
  }) {
    return GetBudgetsParams(
      cursor: cursor != null ? cursor() : this.cursor,
      period: period != null ? period() : this.period,
      categoryUlid: categoryUlid != null ? categoryUlid() : this.categoryUlid,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cursor': cursor,
      'period': period?.name,
      'categoryUlid': categoryUlid,
    };
  }

  factory GetBudgetsParams.fromMap(Map<String, dynamic> map) {
    return GetBudgetsParams(
      cursor: map['cursor'],
      period: map['period'] != null
          ? BudgetPeriod.values.byName(map['period'])
          : null,
      categoryUlid: map['categoryUlid'],
    );
  }

  String toJson() => json.encode(toMap());

  factory GetBudgetsParams.fromJson(String source) =>
      GetBudgetsParams.fromMap(json.decode(source));

  @override
  String toString() =>
      'GetBudgetsParams(cursor: $cursor, period: $period, categoryUlid: $categoryUlid)';

  @override
  List<Object?> get props => [cursor, period, categoryUlid];
}
