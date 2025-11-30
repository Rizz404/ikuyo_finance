part of 'asset_bloc.dart';

sealed class AssetEvent {
  const AssetEvent();
}

// * Read Events
final class AssetFetched extends AssetEvent {
  const AssetFetched({
    this.type,
    this.searchQuery,
    this.sortBy,
    this.sortOrder,
    this.minBalance,
    this.maxBalance,
  });

  final AssetType? type;
  final String? searchQuery;
  final AssetSortBy? sortBy;
  final AssetSortOrder? sortOrder;
  final double? minBalance;
  final double? maxBalance;
}

final class AssetFetchedMore extends AssetEvent {
  const AssetFetchedMore();
}

final class AssetRefreshed extends AssetEvent {
  const AssetRefreshed();
}

// * Search event - dedicated for search functionality
final class AssetSearched extends AssetEvent {
  const AssetSearched({required this.query});

  final String query;
}

// * Filter event - apply multiple filters at once
final class AssetFiltered extends AssetEvent {
  const AssetFiltered({this.type, this.minBalance, this.maxBalance});

  final AssetType? type;
  final double? minBalance;
  final double? maxBalance;
}

// * Sort event - change sorting options
final class AssetSorted extends AssetEvent {
  const AssetSorted({
    required this.sortBy,
    this.sortOrder = AssetSortOrder.descending,
  });

  final AssetSortBy sortBy;
  final AssetSortOrder sortOrder;
}

// * Clear all filters
final class AssetFilterCleared extends AssetEvent {
  const AssetFilterCleared();
}

// * Write Events
final class AssetCreated extends AssetEvent {
  const AssetCreated({required this.params});

  final CreateAssetParams params;
}

final class AssetUpdated extends AssetEvent {
  const AssetUpdated({required this.params});

  final UpdateAssetParams params;
}

final class AssetDeleted extends AssetEvent {
  const AssetDeleted({required this.ulid});

  final String ulid;
}

// * Reset write status setelah UI handle
final class AssetWriteStatusReset extends AssetEvent {
  const AssetWriteStatusReset();
}
