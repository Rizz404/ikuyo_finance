import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import 'package:ikuyo_finance/features/category/models/category.dart';

// * Enum untuk sorting field
enum CategorySortBy { createdAt, name }

// * Enum untuk sort order
enum CategorySortOrder { ascending, descending }

class GetCategoriesParams extends Equatable {
  final String? cursor;
  final int limit;
  final CategoryType? type;

  // * Search & advanced filtering
  final String? searchQuery; // Case-insensitive search by name
  final CategorySortBy sortBy;
  final CategorySortOrder sortOrder;
  final String? parentUlid; // Filter by parent category
  final bool? isRootOnly; // Only get root categories (no parent)

  const GetCategoriesParams({
    this.cursor,
    this.limit = 20,
    this.type,
    this.searchQuery,
    this.sortBy = CategorySortBy.createdAt,
    this.sortOrder = CategorySortOrder.descending,
    this.parentUlid,
    this.isRootOnly,
  });

  // * Helper to check if has any active filter
  bool get hasActiveFilters =>
      type != null ||
      searchQuery != null ||
      parentUlid != null ||
      isRootOnly != null;

  GetCategoriesParams copyWith({
    ValueGetter<String?>? cursor,
    int? limit,
    ValueGetter<CategoryType?>? type,
    ValueGetter<String?>? searchQuery,
    CategorySortBy? sortBy,
    CategorySortOrder? sortOrder,
    ValueGetter<String?>? parentUlid,
    ValueGetter<bool?>? isRootOnly,
  }) {
    return GetCategoriesParams(
      cursor: cursor != null ? cursor() : this.cursor,
      limit: limit ?? this.limit,
      type: type != null ? type() : this.type,
      searchQuery: searchQuery != null ? searchQuery() : this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      parentUlid: parentUlid != null ? parentUlid() : this.parentUlid,
      isRootOnly: isRootOnly != null ? isRootOnly() : this.isRootOnly,
    );
  }

  // * Reset all filters but keep sorting preference
  GetCategoriesParams clearFilters() {
    return GetCategoriesParams(
      sortBy: sortBy,
      sortOrder: sortOrder,
      limit: limit,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cursor': cursor,
      'limit': limit,
      'type': type?.name,
      'searchQuery': searchQuery,
      'sortBy': sortBy.name,
      'sortOrder': sortOrder.name,
      'parentUlid': parentUlid,
      'isRootOnly': isRootOnly,
    };
  }

  factory GetCategoriesParams.fromMap(Map<String, dynamic> map) {
    return GetCategoriesParams(
      cursor: map['cursor'],
      limit: map['limit'] ?? 20,
      type: map['type'] != null
          ? CategoryType.values.byName(map['type'])
          : null,
      searchQuery: map['searchQuery'],
      sortBy: CategorySortBy.values.firstWhere(
        (e) => e.name == map['sortBy'],
        orElse: () => CategorySortBy.createdAt,
      ),
      sortOrder: CategorySortOrder.values.firstWhere(
        (e) => e.name == map['sortOrder'],
        orElse: () => CategorySortOrder.descending,
      ),
      parentUlid: map['parentUlid'],
      isRootOnly: map['isRootOnly'],
    );
  }

  String toJson() => json.encode(toMap());

  factory GetCategoriesParams.fromJson(String source) =>
      GetCategoriesParams.fromMap(json.decode(source));

  @override
  String toString() =>
      'GetCategoriesParams(cursor: $cursor, limit: $limit, type: $type, searchQuery: $searchQuery, sortBy: $sortBy, sortOrder: $sortOrder, parentUlid: $parentUlid, isRootOnly: $isRootOnly)';

  @override
  List<Object?> get props => [
    cursor,
    limit,
    type,
    searchQuery,
    sortBy,
    sortOrder,
    parentUlid,
    isRootOnly,
  ];
}
