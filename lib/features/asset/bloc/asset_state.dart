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
  final AssetType? currentFilter;

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
    this.currentFilter,
    this.writeStatus = AssetWriteStatus.initial,
    this.writeSuccessMessage,
    this.writeErrorMessage,
    this.lastCreatedAsset,
  });

  // * Factory constructors for cleaner state creation
  const AssetState.initial() : this();

  bool get isLoading => status == AssetStatus.loading;
  bool get isLoadingMore => status == AssetStatus.loadingMore;
  bool get isWriting => writeStatus == AssetWriteStatus.loading;

  AssetState copyWith({
    AssetStatus? status,
    List<Asset>? assets,
    String? Function()? errorMessage,
    bool? hasReachedMax,
    String? Function()? nextCursor,
    AssetType? Function()? currentFilter,
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
    currentFilter,
    writeStatus,
    writeSuccessMessage,
    writeErrorMessage,
    lastCreatedAsset,
  ];
}
