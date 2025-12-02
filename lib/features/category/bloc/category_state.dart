part of 'category_bloc.dart';

// * Status untuk read operations (fetch, load more)
enum CategoryStatus { initial, loading, loadingMore, success, failure }

// * Status untuk write operations (create, update, delete)
enum CategoryWriteStatus { initial, loading, success, failure }

final class CategoryState extends Equatable {
  // * Read state
  final CategoryStatus status;
  final List<Category> categories;
  final String? errorMessage;
  final bool hasReachedMax;
  final String? nextCursor;

  // * Filter state
  final CategoryType? currentTypeFilter;
  final String? currentSearchQuery;
  final CategorySortBy currentSortBy;
  final CategorySortOrder currentSortOrder;
  final String? currentParentUlidFilter;
  final bool? currentIsRootOnlyFilter;

  // * Write state (terpisah dari read)
  final CategoryWriteStatus writeStatus;
  final String? writeSuccessMessage;
  final String? writeErrorMessage;
  final Category? lastCreatedCategory;

  // * Valid parent categories for nesting
  final List<Category> validParentCategories;
  final bool isLoadingParentCategories;

  // * Check if editing category has children
  final bool? editingCategoryHasChildren;

  const CategoryState({
    this.status = CategoryStatus.initial,
    this.categories = const [],
    this.errorMessage,
    this.hasReachedMax = false,
    this.nextCursor,
    this.currentTypeFilter,
    this.currentSearchQuery,
    this.currentSortBy = CategorySortBy.createdAt,
    this.currentSortOrder = CategorySortOrder.descending,
    this.currentParentUlidFilter,
    this.currentIsRootOnlyFilter,
    this.writeStatus = CategoryWriteStatus.initial,
    this.writeSuccessMessage,
    this.writeErrorMessage,
    this.lastCreatedCategory,
    this.validParentCategories = const [],
    this.isLoadingParentCategories = false,
    this.editingCategoryHasChildren,
  });

  // * Factory constructors for cleaner state creation
  const CategoryState.initial() : this();

  // * Computed properties
  bool get isLoading => status == CategoryStatus.loading;
  bool get isLoadingMore => status == CategoryStatus.loadingMore;
  bool get isWriting => writeStatus == CategoryWriteStatus.loading;

  // * Check if any filter is active
  bool get hasActiveFilters =>
      currentTypeFilter != null ||
      currentSearchQuery != null ||
      currentParentUlidFilter != null ||
      currentIsRootOnlyFilter != null;

  // * Get current params for refetching (useful for pagination)
  GetCategoriesParams get currentParams => GetCategoriesParams(
    cursor: nextCursor,
    type: currentTypeFilter,
    searchQuery: currentSearchQuery,
    sortBy: currentSortBy,
    sortOrder: currentSortOrder,
    parentUlid: currentParentUlidFilter,
    isRootOnly: currentIsRootOnlyFilter,
  );

  CategoryState copyWith({
    CategoryStatus? status,
    List<Category>? categories,
    String? Function()? errorMessage,
    bool? hasReachedMax,
    String? Function()? nextCursor,
    CategoryType? Function()? currentTypeFilter,
    String? Function()? currentSearchQuery,
    CategorySortBy? currentSortBy,
    CategorySortOrder? currentSortOrder,
    String? Function()? currentParentUlidFilter,
    bool? Function()? currentIsRootOnlyFilter,
    CategoryWriteStatus? writeStatus,
    String? Function()? writeSuccessMessage,
    String? Function()? writeErrorMessage,
    Category? Function()? lastCreatedCategory,
    List<Category>? validParentCategories,
    bool? isLoadingParentCategories,
    bool? Function()? editingCategoryHasChildren,
  }) {
    return CategoryState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      nextCursor: nextCursor != null ? nextCursor() : this.nextCursor,
      currentTypeFilter: currentTypeFilter != null
          ? currentTypeFilter()
          : this.currentTypeFilter,
      currentSearchQuery: currentSearchQuery != null
          ? currentSearchQuery()
          : this.currentSearchQuery,
      currentSortBy: currentSortBy ?? this.currentSortBy,
      currentSortOrder: currentSortOrder ?? this.currentSortOrder,
      currentParentUlidFilter: currentParentUlidFilter != null
          ? currentParentUlidFilter()
          : this.currentParentUlidFilter,
      currentIsRootOnlyFilter: currentIsRootOnlyFilter != null
          ? currentIsRootOnlyFilter()
          : this.currentIsRootOnlyFilter,
      writeStatus: writeStatus ?? this.writeStatus,
      writeSuccessMessage: writeSuccessMessage != null
          ? writeSuccessMessage()
          : this.writeSuccessMessage,
      writeErrorMessage: writeErrorMessage != null
          ? writeErrorMessage()
          : this.writeErrorMessage,
      lastCreatedCategory: lastCreatedCategory != null
          ? lastCreatedCategory()
          : this.lastCreatedCategory,
      validParentCategories:
          validParentCategories ?? this.validParentCategories,
      isLoadingParentCategories:
          isLoadingParentCategories ?? this.isLoadingParentCategories,
      editingCategoryHasChildren: editingCategoryHasChildren != null
          ? editingCategoryHasChildren()
          : this.editingCategoryHasChildren,
    );
  }

  @override
  List<Object?> get props => [
    status,
    categories,
    errorMessage,
    hasReachedMax,
    nextCursor,
    currentTypeFilter,
    currentSearchQuery,
    currentSortBy,
    currentSortOrder,
    currentParentUlidFilter,
    currentIsRootOnlyFilter,
    writeStatus,
    writeSuccessMessage,
    writeErrorMessage,
    lastCreatedCategory,
    validParentCategories,
    isLoadingParentCategories,
    editingCategoryHasChildren,
  ];
}
