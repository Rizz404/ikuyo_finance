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
  final CategoryType? currentFilter;

  // * Write state (terpisah dari read)
  final CategoryWriteStatus writeStatus;
  final String? writeSuccessMessage;
  final String? writeErrorMessage;
  final Category? lastCreatedCategory;

  const CategoryState({
    this.status = CategoryStatus.initial,
    this.categories = const [],
    this.errorMessage,
    this.hasReachedMax = false,
    this.nextCursor,
    this.currentFilter,
    this.writeStatus = CategoryWriteStatus.initial,
    this.writeSuccessMessage,
    this.writeErrorMessage,
    this.lastCreatedCategory,
  });

  // * Factory constructors for cleaner state creation
  const CategoryState.initial() : this();

  bool get isLoading => status == CategoryStatus.loading;
  bool get isLoadingMore => status == CategoryStatus.loadingMore;
  bool get isWriting => writeStatus == CategoryWriteStatus.loading;

  CategoryState copyWith({
    CategoryStatus? status,
    List<Category>? categories,
    String? Function()? errorMessage,
    bool? hasReachedMax,
    String? Function()? nextCursor,
    CategoryType? Function()? currentFilter,
    CategoryWriteStatus? writeStatus,
    String? Function()? writeSuccessMessage,
    String? Function()? writeErrorMessage,
    Category? Function()? lastCreatedCategory,
  }) {
    return CategoryState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      nextCursor: nextCursor != null ? nextCursor() : this.nextCursor,
      currentFilter: currentFilter != null
          ? currentFilter()
          : this.currentFilter,
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
    );
  }

  @override
  List<Object?> get props => [
    status,
    categories,
    errorMessage,
    hasReachedMax,
    nextCursor,
    currentFilter,
    writeStatus,
    writeSuccessMessage,
    writeErrorMessage,
    lastCreatedCategory,
  ];
}
