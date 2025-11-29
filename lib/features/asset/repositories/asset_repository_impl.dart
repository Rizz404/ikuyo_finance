import 'package:fpdart/fpdart.dart' hide Order;
import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';
import 'package:ikuyo_finance/core/wrapper/failure.dart';
import 'package:ikuyo_finance/core/wrapper/success.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/asset/models/create_asset_params.dart';
import 'package:ikuyo_finance/features/asset/models/get_assets_params.dart';
import 'package:ikuyo_finance/features/asset/models/update_asset_params.dart';
import 'package:ikuyo_finance/features/asset/repositories/asset_repository.dart';
import 'package:ikuyo_finance/objectbox.g.dart';

class AssetRepositoryImpl implements AssetRepository {
  final ObjectBoxStorage _storage;

  const AssetRepositoryImpl(this._storage);

  Box<Asset> get _box => _storage.box<Asset>();

  @override
  TaskEither<Failure, Success<Asset>> createAsset(CreateAssetParams params) {
    return TaskEither.tryCatch(
      () async {
        logService('Create asset', params.name);

        final asset = Asset(
          name: params.name,
          type: params.type.index,
          balance: params.balance,
          icon: params.icon,
        );

        _box.put(asset);
        logInfo('Asset created successfully');

        return Success(message: 'Asset created', data: asset);
      },
      (error, stackTrace) {
        logError('Create asset failed', error, stackTrace);
        return Failure(message: 'Failed to create asset. Please try again.');
      },
    );
  }

  @override
  TaskEither<Failure, SuccessCursor<Asset>> getAssets(GetAssetsParams params) {
    return TaskEither.tryCatch(
      () async {
        logService(
          'Get assets',
          'cursor: ${params.cursor}, limit: ${params.limit}',
        );

        var query = _box.query();

        // * Filter by type jika ada
        if (params.type != null) {
          query = _box.query(Asset_.type.equals(params.type!.index));
        }

        // * Pagination dengan cursor (offset-based)
        final offset = params.cursor != null
            ? int.tryParse(params.cursor!) ?? 0
            : 0;
        query = query..order(Asset_.createdAt, flags: Order.descending);

        final builtQuery = query.build();
        final allResults = builtQuery.find();
        builtQuery.close();

        // * Manual offset & limit
        final startIndex = offset < allResults.length
            ? offset
            : allResults.length;
        final endIndex = (startIndex + params.limit + 1) < allResults.length
            ? startIndex + params.limit + 1
            : allResults.length;
        final results = allResults.sublist(startIndex, endIndex);

        final hasMore = results.length > params.limit;
        final assets = hasMore ? results.sublist(0, params.limit) : results;

        final cursorInfo = CursorInfo(
          nextCursor: hasMore ? (offset + params.limit).toString() : '',
          hasNextPage: hasMore,
          perPage: params.limit,
        );

        logInfo('Assets retrieved: ${assets.length}');

        return SuccessCursor(
          message: 'Assets retrieved',
          data: assets,
          cursor: cursorInfo,
        );
      },
      (error, stackTrace) {
        logError('Get assets failed', error, stackTrace);
        return Failure(message: 'Failed to retrieve assets. Please try again.');
      },
    );
  }

  @override
  TaskEither<Failure, Success<Asset>> getAssetById({required String ulid}) {
    return TaskEither.tryCatch(
      () async {
        logService('Get asset by id', ulid);

        final asset = _box.query(Asset_.ulid.equals(ulid)).build().findFirst();

        if (asset == null) {
          throw Exception('Asset not found');
        }

        logInfo('Asset retrieved');
        return Success(message: 'Asset retrieved', data: asset);
      },
      (error, stackTrace) {
        logError('Get asset by id failed', error, stackTrace);
        return Failure(
          message: error.toString().contains('not found')
              ? 'Asset not found'
              : 'Failed to retrieve asset. Please try again.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, Success<Asset>> updateAsset(UpdateAssetParams params) {
    return TaskEither.tryCatch(
      () async {
        logService('Update asset', params.ulid);

        final asset = _box
            .query(Asset_.ulid.equals(params.ulid))
            .build()
            .findFirst();

        if (asset == null) {
          throw Exception('Asset not found');
        }

        // * Update fields jika ada
        if (params.name != null) asset.name = params.name!;
        if (params.type != null) asset.type = params.type!.index;
        if (params.balance != null) asset.balance = params.balance!;
        if (params.icon != null) asset.icon = params.icon;

        asset.updatedAt = DateTime.now();
        _box.put(asset);

        logInfo('Asset updated successfully');
        return Success(message: 'Asset updated', data: asset);
      },
      (error, stackTrace) {
        logError('Update asset failed', error, stackTrace);
        return Failure(
          message: error.toString().contains('not found')
              ? 'Asset not found'
              : 'Failed to update asset. Please try again.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, ActionSuccess> deleteAsset({required String ulid}) {
    return TaskEither.tryCatch(
      () async {
        logService('Delete asset', ulid);

        final asset = _box.query(Asset_.ulid.equals(ulid)).build().findFirst();

        if (asset == null) {
          throw Exception('Asset not found');
        }

        _box.remove(asset.id);
        logInfo('Asset deleted successfully');

        return const ActionSuccess(message: 'Asset deleted');
      },
      (error, stackTrace) {
        logError('Delete asset failed', error, stackTrace);
        return Failure(
          message: error.toString().contains('not found')
              ? 'Asset not found'
              : 'Failed to delete asset. Please try again.',
        );
      },
    );
  }
}
