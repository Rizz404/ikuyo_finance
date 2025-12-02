part of 'category_bloc.dart';

sealed class CategoryEvent {
  const CategoryEvent();
}

// * Read Events
final class CategoryFetched extends CategoryEvent {
  const CategoryFetched({
    this.type,
    this.searchQuery,
    this.sortBy,
    this.sortOrder,
    this.parentUlid,
    this.isRootOnly,
  });

  final CategoryType? type;
  final String? searchQuery;
  final CategorySortBy? sortBy;
  final CategorySortOrder? sortOrder;
  final String? parentUlid;
  final bool? isRootOnly;
}

final class CategoryFetchedMore extends CategoryEvent {
  const CategoryFetchedMore();
}

final class CategoryRefreshed extends CategoryEvent {
  const CategoryRefreshed();
}

// * Search event - dedicated for search functionality
final class CategorySearched extends CategoryEvent {
  const CategorySearched({required this.query});

  final String query;
}

// * Filter event - apply multiple filters at once
final class CategoryFiltered extends CategoryEvent {
  const CategoryFiltered({this.type, this.parentUlid, this.isRootOnly});

  final CategoryType? type;
  final String? parentUlid;
  final bool? isRootOnly;
}

// * Sort event - change sorting options
final class CategorySorted extends CategoryEvent {
  const CategorySorted({
    required this.sortBy,
    this.sortOrder = CategorySortOrder.descending,
  });

  final CategorySortBy sortBy;
  final CategorySortOrder sortOrder;
}

// * Clear all filters
final class CategoryFilterCleared extends CategoryEvent {
  const CategoryFilterCleared();
}

// * Write Events
final class CategoryCreated extends CategoryEvent {
  const CategoryCreated({required this.params});

  final CreateCategoryParams params;
}

final class CategoryUpdated extends CategoryEvent {
  const CategoryUpdated({required this.params});

  final UpdateCategoryParams params;
}

final class CategoryDeleted extends CategoryEvent {
  const CategoryDeleted({required this.ulid});

  final String ulid;
}

// * Reset write status setelah UI handle
final class CategoryWriteStatusReset extends CategoryEvent {
  const CategoryWriteStatusReset();
}

// * Fetch valid parent categories for nesting
final class ValidParentCategoriesFetched extends CategoryEvent {
  const ValidParentCategoriesFetched({required this.type, this.excludeUlid});

  final CategoryType type;
  final String? excludeUlid;
}

// * Check if category has children
final class CategoryHasChildrenChecked extends CategoryEvent {
  const CategoryHasChildrenChecked({required this.ulid});

  final String ulid;
}
