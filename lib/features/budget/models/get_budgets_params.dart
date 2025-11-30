import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import 'package:ikuyo_finance/features/budget/models/budget.dart';

// * Enum untuk sorting field
enum BudgetSortBy { createdAt, amountLimit, startDate, endDate }

// * Enum untuk sort order
enum BudgetSortOrder { ascending, descending }

class GetBudgetsParams extends Equatable {
  final String? cursor;
  final int limit;
  final BudgetPeriod? period;
  final String? categoryUlid;

  // * Search & advanced filtering
  final String? searchQuery; // Case-insensitive search by category name
  final BudgetSortBy sortBy;
  final BudgetSortOrder sortOrder;
  final double? minAmountLimit;
  final double? maxAmountLimit;
  final DateTime? startDateFrom;
  final DateTime? startDateTo;
  final DateTime? endDateFrom;
  final DateTime? endDateTo;

  const GetBudgetsParams({
    this.cursor,
    this.limit = 20,
    this.period,
    this.categoryUlid,
    this.searchQuery,
    this.sortBy = BudgetSortBy.createdAt,
    this.sortOrder = BudgetSortOrder.descending,
    this.minAmountLimit,
    this.maxAmountLimit,
    this.startDateFrom,
    this.startDateTo,
    this.endDateFrom,
    this.endDateTo,
  });

  // * Helper to check if has any active filter
  bool get hasActiveFilters =>
      period != null ||
      categoryUlid != null ||
      searchQuery != null ||
      minAmountLimit != null ||
      maxAmountLimit != null ||
      startDateFrom != null ||
      startDateTo != null ||
      endDateFrom != null ||
      endDateTo != null;

  GetBudgetsParams copyWith({
    ValueGetter<String?>? cursor,
    int? limit,
    ValueGetter<BudgetPeriod?>? period,
    ValueGetter<String?>? categoryUlid,
    ValueGetter<String?>? searchQuery,
    BudgetSortBy? sortBy,
    BudgetSortOrder? sortOrder,
    ValueGetter<double?>? minAmountLimit,
    ValueGetter<double?>? maxAmountLimit,
    ValueGetter<DateTime?>? startDateFrom,
    ValueGetter<DateTime?>? startDateTo,
    ValueGetter<DateTime?>? endDateFrom,
    ValueGetter<DateTime?>? endDateTo,
  }) {
    return GetBudgetsParams(
      cursor: cursor != null ? cursor() : this.cursor,
      limit: limit ?? this.limit,
      period: period != null ? period() : this.period,
      categoryUlid: categoryUlid != null ? categoryUlid() : this.categoryUlid,
      searchQuery: searchQuery != null ? searchQuery() : this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      minAmountLimit: minAmountLimit != null
          ? minAmountLimit()
          : this.minAmountLimit,
      maxAmountLimit: maxAmountLimit != null
          ? maxAmountLimit()
          : this.maxAmountLimit,
      startDateFrom: startDateFrom != null
          ? startDateFrom()
          : this.startDateFrom,
      startDateTo: startDateTo != null ? startDateTo() : this.startDateTo,
      endDateFrom: endDateFrom != null ? endDateFrom() : this.endDateFrom,
      endDateTo: endDateTo != null ? endDateTo() : this.endDateTo,
    );
  }

  // * Reset all filters but keep sorting preference
  GetBudgetsParams clearFilters() {
    return GetBudgetsParams(sortBy: sortBy, sortOrder: sortOrder, limit: limit);
  }

  Map<String, dynamic> toMap() {
    return {
      'cursor': cursor,
      'limit': limit,
      'period': period?.name,
      'categoryUlid': categoryUlid,
      'searchQuery': searchQuery,
      'sortBy': sortBy.name,
      'sortOrder': sortOrder.name,
      'minAmountLimit': minAmountLimit,
      'maxAmountLimit': maxAmountLimit,
      'startDateFrom': startDateFrom?.toIso8601String(),
      'startDateTo': startDateTo?.toIso8601String(),
      'endDateFrom': endDateFrom?.toIso8601String(),
      'endDateTo': endDateTo?.toIso8601String(),
    };
  }

  factory GetBudgetsParams.fromMap(Map<String, dynamic> map) {
    return GetBudgetsParams(
      cursor: map['cursor'],
      limit: map['limit'] ?? 20,
      period: map['period'] != null
          ? BudgetPeriod.values.byName(map['period'])
          : null,
      categoryUlid: map['categoryUlid'],
      searchQuery: map['searchQuery'],
      sortBy: BudgetSortBy.values.firstWhere(
        (e) => e.name == map['sortBy'],
        orElse: () => BudgetSortBy.createdAt,
      ),
      sortOrder: BudgetSortOrder.values.firstWhere(
        (e) => e.name == map['sortOrder'],
        orElse: () => BudgetSortOrder.descending,
      ),
      minAmountLimit: map['minAmountLimit']?.toDouble(),
      maxAmountLimit: map['maxAmountLimit']?.toDouble(),
      startDateFrom: map['startDateFrom'] != null
          ? DateTime.parse(map['startDateFrom'])
          : null,
      startDateTo: map['startDateTo'] != null
          ? DateTime.parse(map['startDateTo'])
          : null,
      endDateFrom: map['endDateFrom'] != null
          ? DateTime.parse(map['endDateFrom'])
          : null,
      endDateTo: map['endDateTo'] != null
          ? DateTime.parse(map['endDateTo'])
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory GetBudgetsParams.fromJson(String source) =>
      GetBudgetsParams.fromMap(json.decode(source));

  @override
  String toString() =>
      'GetBudgetsParams(cursor: $cursor, limit: $limit, period: $period, categoryUlid: $categoryUlid, searchQuery: $searchQuery, sortBy: $sortBy, sortOrder: $sortOrder, minAmountLimit: $minAmountLimit, maxAmountLimit: $maxAmountLimit, startDateFrom: $startDateFrom, startDateTo: $startDateTo, endDateFrom: $endDateFrom, endDateTo: $endDateTo)';

  @override
  List<Object?> get props => [
    cursor,
    limit,
    period,
    categoryUlid,
    searchQuery,
    sortBy,
    sortOrder,
    minAmountLimit,
    maxAmountLimit,
    startDateFrom,
    startDateTo,
    endDateFrom,
    endDateTo,
  ];
}
