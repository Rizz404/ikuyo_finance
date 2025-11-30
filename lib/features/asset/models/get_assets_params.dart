import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import 'package:ikuyo_finance/features/asset/models/asset.dart';

// * Enum untuk sorting field
enum AssetSortBy { createdAt, name, balance }

// * Enum untuk sort order
enum AssetSortOrder { ascending, descending }

class GetAssetsParams extends Equatable {
  final String? cursor;
  final int limit;
  final AssetType? type;

  // * Search & advanced filtering
  final String? searchQuery; // Case-insensitive search by name
  final AssetSortBy sortBy;
  final AssetSortOrder sortOrder;
  final double? minBalance;
  final double? maxBalance;

  const GetAssetsParams({
    this.cursor,
    this.limit = 20,
    this.type,
    this.searchQuery,
    this.sortBy = AssetSortBy.createdAt,
    this.sortOrder = AssetSortOrder.descending,
    this.minBalance,
    this.maxBalance,
  });

  // * Helper to check if has any active filter
  bool get hasActiveFilters =>
      type != null ||
      searchQuery != null ||
      minBalance != null ||
      maxBalance != null;

  GetAssetsParams copyWith({
    ValueGetter<String?>? cursor,
    int? limit,
    ValueGetter<AssetType?>? type,
    ValueGetter<String?>? searchQuery,
    AssetSortBy? sortBy,
    AssetSortOrder? sortOrder,
    ValueGetter<double?>? minBalance,
    ValueGetter<double?>? maxBalance,
  }) {
    return GetAssetsParams(
      cursor: cursor != null ? cursor() : this.cursor,
      limit: limit ?? this.limit,
      type: type != null ? type() : this.type,
      searchQuery: searchQuery != null ? searchQuery() : this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      minBalance: minBalance != null ? minBalance() : this.minBalance,
      maxBalance: maxBalance != null ? maxBalance() : this.maxBalance,
    );
  }

  // * Reset all filters but keep sorting preference
  GetAssetsParams clearFilters() {
    return GetAssetsParams(sortBy: sortBy, sortOrder: sortOrder, limit: limit);
  }

  Map<String, dynamic> toMap() {
    return {
      'cursor': cursor,
      'limit': limit,
      'type': type?.name,
      'searchQuery': searchQuery,
      'sortBy': sortBy.name,
      'sortOrder': sortOrder.name,
      'minBalance': minBalance,
      'maxBalance': maxBalance,
    };
  }

  factory GetAssetsParams.fromMap(Map<String, dynamic> map) {
    return GetAssetsParams(
      cursor: map['cursor'],
      limit: map['limit'] ?? 20,
      type: map['type'] != null ? AssetType.values.byName(map['type']) : null,
      searchQuery: map['searchQuery'],
      sortBy: AssetSortBy.values.firstWhere(
        (e) => e.name == map['sortBy'],
        orElse: () => AssetSortBy.createdAt,
      ),
      sortOrder: AssetSortOrder.values.firstWhere(
        (e) => e.name == map['sortOrder'],
        orElse: () => AssetSortOrder.descending,
      ),
      minBalance: map['minBalance']?.toDouble(),
      maxBalance: map['maxBalance']?.toDouble(),
    );
  }

  String toJson() => json.encode(toMap());

  factory GetAssetsParams.fromJson(String source) =>
      GetAssetsParams.fromMap(json.decode(source));

  @override
  String toString() =>
      'GetAssetsParams(cursor: $cursor, limit: $limit, type: $type, searchQuery: $searchQuery, sortBy: $sortBy, sortOrder: $sortOrder, minBalance: $minBalance, maxBalance: $maxBalance)';

  @override
  List<Object?> get props => [
    cursor,
    limit,
    type,
    searchQuery,
    sortBy,
    sortOrder,
    minBalance,
    maxBalance,
  ];
}
