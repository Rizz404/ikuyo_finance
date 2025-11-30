part of 'asset_bloc.dart';

// * Status untuk read operations (fetch, load more)
enum AssetStatus { initial, loading, loadingMore, success, failure }

// * Status untuk write operations (create, update, delete)
enum AssetWriteStatus { initial, loading, success, failure }

final class AssetState extends Equatable {
  // * Read state
  final AssetStatus status;
  final List<Asset> assets;
  final String? errorMessage;
  final bool hasReachedMax;
  final String? nextCursor;

  // * Filter state
  final AssetType? currentTypeFilter;
  final String? currentSearchQuery;
  final AssetSortBy currentSortBy;
  final AssetSortOrder currentSortOrder;
  final double? currentMinBalance;
  final double? currentMaxBalance;

  // * Write state (terpisah dari read)
  final AssetWriteStatus writeStatus;
  final String? writeSuccessMessage;
  final String? writeErrorMessage;
  final Asset? lastCreatedAsset;

  const AssetState({
    this.status = AssetStatus.initial,
    this.assets = const [],
    this.errorMessage,
    this.hasReachedMax = false,
    this.nextCursor,
    this.currentTypeFilter,
    this.currentSearchQuery,
    this.currentSortBy = AssetSortBy.createdAt,
    this.currentSortOrder = AssetSortOrder.descending,
    this.currentMinBalance,
    this.currentMaxBalance,
    this.writeStatus = AssetWriteStatus.initial,
    this.writeSuccessMessage,
    this.writeErrorMessage,
    this.lastCreatedAsset,
  });

  // * Factory constructors for cleaner state creation
  const AssetState.initial() : this();

  // * Computed properties
  bool get isLoading => status == AssetStatus.loading;
  bool get isLoadingMore => status == AssetStatus.loadingMore;
  bool get isWriting => writeStatus == AssetWriteStatus.loading;

  // * Check if any filter is active
  bool get hasActiveFilters =>
      currentTypeFilter != null ||
      currentSearchQuery != null ||
      currentMinBalance != null ||
      currentMaxBalance != null;

  // * Get current params for refetching (useful for pagination)
  GetAssetsParams get currentParams => GetAssetsParams(
    cursor: nextCursor,
    type: currentTypeFilter,
    searchQuery: currentSearchQuery,
    sortBy: currentSortBy,
    sortOrder: currentSortOrder,
    minBalance: currentMinBalance,
    maxBalance: currentMaxBalance,
  );

  AssetState copyWith({
    AssetStatus? status,
    List<Asset>? assets,
    String? Function()? errorMessage,
    bool? hasReachedMax,
    String? Function()? nextCursor,
    AssetType? Function()? currentTypeFilter,
    String? Function()? currentSearchQuery,
    AssetSortBy? currentSortBy,
    AssetSortOrder? currentSortOrder,
    double? Function()? currentMinBalance,
    double? Function()? currentMaxBalance,
    AssetWriteStatus? writeStatus,
    String? Function()? writeSuccessMessage,
    String? Function()? writeErrorMessage,
    Asset? Function()? lastCreatedAsset,
  }) {
    return AssetState(
      status: status ?? this.status,
      assets: assets ?? this.assets,
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
      currentMinBalance: currentMinBalance != null
          ? currentMinBalance()
          : this.currentMinBalance,
      currentMaxBalance: currentMaxBalance != null
          ? currentMaxBalance()
          : this.currentMaxBalance,
      writeStatus: writeStatus ?? this.writeStatus,
      writeSuccessMessage: writeSuccessMessage != null
          ? writeSuccessMessage()
          : this.writeSuccessMessage,
      writeErrorMessage: writeErrorMessage != null
          ? writeErrorMessage()
          : this.writeErrorMessage,
      lastCreatedAsset: lastCreatedAsset != null
          ? lastCreatedAsset()
          : this.lastCreatedAsset,
    );
  }

  @override
  List<Object?> get props => [
    status,
    assets,
    errorMessage,
    hasReachedMax,
    nextCursor,
    currentTypeFilter,
    currentSearchQuery,
    currentSortBy,
    currentSortOrder,
    currentMinBalance,
    currentMaxBalance,
    writeStatus,
    writeSuccessMessage,
    writeErrorMessage,
    lastCreatedAsset,
  ];
}
