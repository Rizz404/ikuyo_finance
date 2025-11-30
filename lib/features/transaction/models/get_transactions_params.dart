import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

// * Enum untuk sorting field
enum TransactionSortBy { createdAt, transactionDate, amount }

// * Enum untuk sort order
enum SortOrder { ascending, descending }

class GetTransactionsParams extends Equatable {
  final String? cursor;
  final int limit;
  final String? assetUlid;
  final String? categoryUlid;
  final DateTime? startDate;
  final DateTime? endDate;

  // * Search & advanced filtering
  final String? searchQuery; // Case-insensitive search by description
  final TransactionSortBy sortBy;
  final SortOrder sortOrder;
  final double? minAmount;
  final double? maxAmount;

  const GetTransactionsParams({
    this.cursor,
    this.limit = 20,
    this.assetUlid,
    this.categoryUlid,
    this.startDate,
    this.endDate,
    this.searchQuery,
    this.sortBy = TransactionSortBy.transactionDate,
    this.sortOrder = SortOrder.descending,
    this.minAmount,
    this.maxAmount,
  });

  // * Helper to check if has any active filter
  bool get hasActiveFilters =>
      assetUlid != null ||
      categoryUlid != null ||
      startDate != null ||
      endDate != null ||
      searchQuery != null ||
      minAmount != null ||
      maxAmount != null;

  GetTransactionsParams copyWith({
    ValueGetter<String?>? cursor,
    int? limit,
    ValueGetter<String?>? assetUlid,
    ValueGetter<String?>? categoryUlid,
    ValueGetter<DateTime?>? startDate,
    ValueGetter<DateTime?>? endDate,
    ValueGetter<String?>? searchQuery,
    TransactionSortBy? sortBy,
    SortOrder? sortOrder,
    ValueGetter<double?>? minAmount,
    ValueGetter<double?>? maxAmount,
  }) {
    return GetTransactionsParams(
      cursor: cursor != null ? cursor() : this.cursor,
      limit: limit ?? this.limit,
      assetUlid: assetUlid != null ? assetUlid() : this.assetUlid,
      categoryUlid: categoryUlid != null ? categoryUlid() : this.categoryUlid,
      startDate: startDate != null ? startDate() : this.startDate,
      endDate: endDate != null ? endDate() : this.endDate,
      searchQuery: searchQuery != null ? searchQuery() : this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      minAmount: minAmount != null ? minAmount() : this.minAmount,
      maxAmount: maxAmount != null ? maxAmount() : this.maxAmount,
    );
  }

  // * Reset all filters but keep sorting preference
  GetTransactionsParams clearFilters() {
    return GetTransactionsParams(
      sortBy: sortBy,
      sortOrder: sortOrder,
      limit: limit,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cursor': cursor,
      'limit': limit,
      'assetUlid': assetUlid,
      'categoryUlid': categoryUlid,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'searchQuery': searchQuery,
      'sortBy': sortBy.name,
      'sortOrder': sortOrder.name,
      'minAmount': minAmount,
      'maxAmount': maxAmount,
    };
  }

  factory GetTransactionsParams.fromMap(Map<String, dynamic> map) {
    return GetTransactionsParams(
      cursor: map['cursor'],
      limit: map['limit'] ?? 20,
      assetUlid: map['assetUlid'],
      categoryUlid: map['categoryUlid'],
      startDate: map['startDate'] != null
          ? DateTime.parse(map['startDate'])
          : null,
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
      searchQuery: map['searchQuery'],
      sortBy: TransactionSortBy.values.firstWhere(
        (e) => e.name == map['sortBy'],
        orElse: () => TransactionSortBy.transactionDate,
      ),
      sortOrder: SortOrder.values.firstWhere(
        (e) => e.name == map['sortOrder'],
        orElse: () => SortOrder.descending,
      ),
      minAmount: map['minAmount']?.toDouble(),
      maxAmount: map['maxAmount']?.toDouble(),
    );
  }

  String toJson() => json.encode(toMap());

  factory GetTransactionsParams.fromJson(String source) =>
      GetTransactionsParams.fromMap(json.decode(source));

  @override
  String toString() =>
      'GetTransactionsParams(cursor: $cursor, limit: $limit, assetUlid: $assetUlid, categoryUlid: $categoryUlid, startDate: $startDate, endDate: $endDate, searchQuery: $searchQuery, sortBy: $sortBy, sortOrder: $sortOrder, minAmount: $minAmount, maxAmount: $maxAmount)';

  @override
  List<Object?> get props => [
    cursor,
    limit,
    assetUlid,
    categoryUlid,
    startDate,
    endDate,
    searchQuery,
    sortBy,
    sortOrder,
    minAmount,
    maxAmount,
  ];
}
