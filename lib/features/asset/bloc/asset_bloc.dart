import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/asset/models/create_asset_params.dart';
import 'package:ikuyo_finance/features/asset/models/get_assets_params.dart';
import 'package:ikuyo_finance/features/asset/models/update_asset_params.dart';
import 'package:ikuyo_finance/features/asset/repositories/asset_repository.dart';

part 'asset_event.dart';
part 'asset_state.dart';

class AssetBloc extends Bloc<AssetEvent, AssetState> {
  AssetBloc(this._assetRepository) : super(const AssetState()) {
    // * Read events
    on<AssetFetched>(_onAssetFetched);
    on<AssetFetchedMore>(_onAssetFetchedMore);
    on<AssetRefreshed>(_onAssetRefreshed);

    // * Write events
    on<AssetCreated>(_onAssetCreated);
    on<AssetUpdated>(_onAssetUpdated);
    on<AssetDeleted>(_onAssetDeleted);
    on<AssetWriteStatusReset>(_onWriteStatusReset);
  }

  final AssetRepository _assetRepository;

  // * Fetch initial assets
  Future<void> _onAssetFetched(
    AssetFetched event,
    Emitter<AssetState> emit,
  ) async {
    emit(
      state.copyWith(
        status: AssetStatus.loading,
        currentFilter: () => event.type,
      ),
    );

    final result = await _assetRepository
        .getAssets(GetAssetsParams(type: event.type))
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

  // * Load more assets (pagination)
  Future<void> _onAssetFetchedMore(
    AssetFetchedMore event,
    Emitter<AssetState> emit,
  ) async {
    if (state.hasReachedMax || state.isLoadingMore) return;

    emit(state.copyWith(status: AssetStatus.loadingMore));

    final result = await _assetRepository
        .getAssets(
          GetAssetsParams(cursor: state.nextCursor, type: state.currentFilter),
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

  // * Refresh assets (reset & fetch)
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
        .getAssets(GetAssetsParams(type: state.currentFilter))
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
}
