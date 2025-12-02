import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/asset/models/create_asset_params.dart';
import 'package:ikuyo_finance/features/asset/models/get_assets_params.dart';
import 'package:ikuyo_finance/features/asset/models/update_asset_params.dart';
import 'package:ikuyo_finance/features/asset/repositories/asset_repository.dart';
import 'package:stream_transform/stream_transform.dart';

part 'asset_event.dart';
part 'asset_state.dart';

// * Debounce transformer for search
EventTransformer<E> debounce<E>(Duration duration) {
  return (events, mapper) => events.debounce(duration).switchMap(mapper);
}

class AssetBloc extends Bloc<AssetEvent, AssetState> {
  AssetBloc(this._assetRepository) : super(const AssetState()) {
    // * Read events
    on<AssetFetched>(_onAssetFetched);
    on<AssetFetchedMore>(_onAssetFetchedMore);
    on<AssetRefreshed>(_onAssetRefreshed);

    // * Search & filter events
    on<AssetSearched>(
      _onAssetSearched,
      transformer: debounce(const Duration(milliseconds: 300)),
    );
    on<AssetFiltered>(_onAssetFiltered);
    on<AssetSorted>(_onAssetSorted);
    on<AssetFilterCleared>(_onAssetFilterCleared);

    // * Write events
    on<AssetCreated>(_onAssetCreated);
    on<AssetUpdated>(_onAssetUpdated);
    on<AssetDeleted>(_onAssetDeleted);
    on<AssetWriteStatusReset>(_onWriteStatusReset);
  }

  final AssetRepository _assetRepository;

  // * Fetch initial assets with all filter options
  Future<void> _onAssetFetched(
    AssetFetched event,
    Emitter<AssetState> emit,
  ) async {
    emit(
      state.copyWith(
        status: AssetStatus.loading,
        currentTypeFilter: () => event.type,
        currentSearchQuery: () => event.searchQuery,
        currentSortBy: event.sortBy ?? state.currentSortBy,
        currentSortOrder: event.sortOrder ?? state.currentSortOrder,
        currentMinBalance: () => event.minBalance,
        currentMaxBalance: () => event.maxBalance,
      ),
    );

    final result = await _assetRepository
        .getAssets(
          GetAssetsParams(
            type: event.type,
            searchQuery: event.searchQuery,
            sortBy: event.sortBy ?? state.currentSortBy,
            sortOrder: event.sortOrder ?? state.currentSortOrder,
            minBalance: event.minBalance,
            maxBalance: event.maxBalance,
          ),
        )
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: AssetStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: AssetStatus.success,
          assets: success.data,
          hasReachedMax: !success.cursor.hasNextPage,
          nextCursor: () => success.cursor.nextCursor,
          errorMessage: () => null,
        ),
      ),
    );
  }

  // * Load more assets (cursor-based pagination)
  Future<void> _onAssetFetchedMore(
    AssetFetchedMore event,
    Emitter<AssetState> emit,
  ) async {
    if (state.hasReachedMax || state.isLoadingMore) return;

    emit(state.copyWith(status: AssetStatus.loadingMore));

    final result = await _assetRepository
        .getAssets(
          GetAssetsParams(
            cursor: state.nextCursor,
            type: state.currentTypeFilter,
            searchQuery: state.currentSearchQuery,
            sortBy: state.currentSortBy,
            sortOrder: state.currentSortOrder,
            minBalance: state.currentMinBalance,
            maxBalance: state.currentMaxBalance,
          ),
        )
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: AssetStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: AssetStatus.success,
          assets: [...state.assets, ...?success.data],
          hasReachedMax: !success.cursor.hasNextPage,
          nextCursor: () => success.cursor.nextCursor,
          errorMessage: () => null,
        ),
      ),
    );
  }

  // * Refresh assets (reset & fetch with current filters)
  Future<void> _onAssetRefreshed(
    AssetRefreshed event,
    Emitter<AssetState> emit,
  ) async {
    emit(
      state.copyWith(
        status: AssetStatus.loading,
        hasReachedMax: false,
        nextCursor: () => null,
      ),
    );

    final result = await _assetRepository
        .getAssets(
          GetAssetsParams(
            type: state.currentTypeFilter,
            searchQuery: state.currentSearchQuery,
            sortBy: state.currentSortBy,
            sortOrder: state.currentSortOrder,
            minBalance: state.currentMinBalance,
            maxBalance: state.currentMaxBalance,
          ),
        )
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: AssetStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: AssetStatus.success,
          assets: success.data,
          hasReachedMax: !success.cursor.hasNextPage,
          nextCursor: () => success.cursor.nextCursor,
          errorMessage: () => null,
        ),
      ),
    );
  }

  // * Search assets by name (debounced)
  Future<void> _onAssetSearched(
    AssetSearched event,
    Emitter<AssetState> emit,
  ) async {
    final query = event.query.trim();

    emit(
      state.copyWith(
        status: AssetStatus.loading,
        currentSearchQuery: () => query.isEmpty ? null : query,
        hasReachedMax: false,
        nextCursor: () => null,
      ),
    );

    final result = await _assetRepository
        .getAssets(
          GetAssetsParams(
            type: state.currentTypeFilter,
            searchQuery: query.isEmpty ? null : query,
            sortBy: state.currentSortBy,
            sortOrder: state.currentSortOrder,
            minBalance: state.currentMinBalance,
            maxBalance: state.currentMaxBalance,
          ),
        )
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: AssetStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: AssetStatus.success,
          assets: success.data,
          hasReachedMax: !success.cursor.hasNextPage,
          nextCursor: () => success.cursor.nextCursor,
          errorMessage: () => null,
        ),
      ),
    );
  }

  // * Apply multiple filters at once
  Future<void> _onAssetFiltered(
    AssetFiltered event,
    Emitter<AssetState> emit,
  ) async {
    emit(
      state.copyWith(
        status: AssetStatus.loading,
        currentTypeFilter: () => event.type,
        currentMinBalance: () => event.minBalance,
        currentMaxBalance: () => event.maxBalance,
        hasReachedMax: false,
        nextCursor: () => null,
      ),
    );

    final result = await _assetRepository
        .getAssets(
          GetAssetsParams(
            type: event.type,
            searchQuery: state.currentSearchQuery,
            sortBy: state.currentSortBy,
            sortOrder: state.currentSortOrder,
            minBalance: event.minBalance,
            maxBalance: event.maxBalance,
          ),
        )
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: AssetStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: AssetStatus.success,
          assets: success.data,
          hasReachedMax: !success.cursor.hasNextPage,
          nextCursor: () => success.cursor.nextCursor,
          errorMessage: () => null,
        ),
      ),
    );
  }

  // * Change sorting options
  Future<void> _onAssetSorted(
    AssetSorted event,
    Emitter<AssetState> emit,
  ) async {
    emit(
      state.copyWith(
        status: AssetStatus.loading,
        currentSortBy: event.sortBy,
        currentSortOrder: event.sortOrder,
        hasReachedMax: false,
        nextCursor: () => null,
      ),
    );

    final result = await _assetRepository
        .getAssets(
          GetAssetsParams(
            type: state.currentTypeFilter,
            searchQuery: state.currentSearchQuery,
            sortBy: event.sortBy,
            sortOrder: event.sortOrder,
            minBalance: state.currentMinBalance,
            maxBalance: state.currentMaxBalance,
          ),
        )
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: AssetStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: AssetStatus.success,
          assets: success.data,
          hasReachedMax: !success.cursor.hasNextPage,
          nextCursor: () => success.cursor.nextCursor,
          errorMessage: () => null,
        ),
      ),
    );
  }

  // * Clear all filters and reset to default
  Future<void> _onAssetFilterCleared(
    AssetFilterCleared event,
    Emitter<AssetState> emit,
  ) async {
    emit(
      state.copyWith(
        status: AssetStatus.loading,
        currentTypeFilter: () => null,
        currentSearchQuery: () => null,
        currentSortBy: AssetSortBy.createdAt,
        currentSortOrder: AssetSortOrder.descending,
        currentMinBalance: () => null,
        currentMaxBalance: () => null,
        hasReachedMax: false,
        nextCursor: () => null,
      ),
    );

    final result = await _assetRepository
        .getAssets(const GetAssetsParams())
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: AssetStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: AssetStatus.success,
          assets: success.data,
          hasReachedMax: !success.cursor.hasNextPage,
          nextCursor: () => success.cursor.nextCursor,
          errorMessage: () => null,
        ),
      ),
    );
  }

  // * Create asset
  Future<void> _onAssetCreated(
    AssetCreated event,
    Emitter<AssetState> emit,
  ) async {
    emit(state.copyWith(writeStatus: AssetWriteStatus.loading));

    final result = await _assetRepository.createAsset(event.params).run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          writeStatus: AssetWriteStatus.failure,
          writeErrorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          writeStatus: AssetWriteStatus.success,
          writeSuccessMessage: () => success.message,
          lastCreatedAsset: () => success.data,
          // * Tambah ke list langsung untuk UX responsif
          assets: [success.data!, ...state.assets],
        ),
      ),
    );
  }

  // * Update asset
  Future<void> _onAssetUpdated(
    AssetUpdated event,
    Emitter<AssetState> emit,
  ) async {
    emit(state.copyWith(writeStatus: AssetWriteStatus.loading));

    final result = await _assetRepository.updateAsset(event.params).run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          writeStatus: AssetWriteStatus.failure,
          writeErrorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          writeStatus: AssetWriteStatus.success,
          writeSuccessMessage: () => success.message,
          // * Update item di list
          assets: state.assets.map((asset) {
            return asset.ulid == event.params.ulid ? success.data! : asset;
          }).toList(),
        ),
      ),
    );
  }

  // * Delete asset
  Future<void> _onAssetDeleted(
    AssetDeleted event,
    Emitter<AssetState> emit,
  ) async {
    emit(state.copyWith(writeStatus: AssetWriteStatus.loading));

    final result = await _assetRepository.deleteAsset(ulid: event.ulid).run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          writeStatus: AssetWriteStatus.failure,
          writeErrorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          writeStatus: AssetWriteStatus.success,
          writeSuccessMessage: () => success.message,
          // * Hapus dari list
          assets: state.assets
              .where((asset) => asset.ulid != event.ulid)
              .toList(),
        ),
      ),
    );
  }

  // * Reset write status (panggil dari UI setelah handle success/error)
  void _onWriteStatusReset(
    AssetWriteStatusReset event,
    Emitter<AssetState> emit,
  ) {
    emit(
      state.copyWith(
        writeStatus: AssetWriteStatus.initial,
        writeSuccessMessage: () => null,
        writeErrorMessage: () => null,
        lastCreatedAsset: () => null,
      ),
    );
  }

  // * Public method for searchable dropdown - returns Future directly
  // * Does NOT affect bloc state, purely for dropdown search
  Future<List<Asset>> searchAssetsForDropdown({
    String? query,
    AssetType? type,
  }) async {
    final result = await _assetRepository
        .getAssets(
          GetAssetsParams(
            searchQuery: query?.isEmpty == true ? null : query,
            type: type,
          ),
        )
        .run();

    return result.fold((failure) => [], (success) => success.data ?? []);
  }
}
