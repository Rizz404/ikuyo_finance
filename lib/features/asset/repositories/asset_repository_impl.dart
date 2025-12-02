import 'package:fpdart/fpdart.dart' hide Order;
import 'package:ikuyo_finance/core/service/app_file_storage.dart';
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

// * Subfolder for asset icons in app storage
const _kAssetIconsFolder = 'asset_icons';

class AssetRepositoryImpl implements AssetRepository {
  final ObjectBoxStorage _storage;
  final AppFileStorage _fileStorage;

  const AssetRepositoryImpl(this._storage, this._fileStorage);

  Box<Asset> get _box => _storage.box<Asset>();

  @override
  TaskEither<Failure, Success<Asset>> createAsset(CreateAssetParams params) {
    return TaskEither.tryCatch(
      () async {
        logService('Buat aset', params.name);

        // * Save icon to app storage
        final savedIconPath = await _fileStorage.saveFile(
          params.icon,
          subFolder: _kAssetIconsFolder,
        );

        final asset = Asset(
          name: params.name,
          type: params.type.index,
          balance: params.balance,
          icon: savedIconPath,
        );

        _box.put(asset);
        logInfo('Aset berhasil dibuat');

        return Success(message: 'Aset berhasil dibuat', data: asset);
      },
      (error, stackTrace) {
        logError('Gagal membuat aset', error, stackTrace);
        return Failure(message: 'Gagal membuat aset. Silakan coba lagi.');
      },
    );
  }

  @override
  TaskEither<Failure, SuccessCursor<Asset>> getAssets(GetAssetsParams params) {
    return TaskEither.tryCatch(
      () async {
        logService(
          'Ambil aset',
          'cursor: ${params.cursor}, limit: ${params.limit}, cari: ${params.searchQuery}, urutkan: ${params.sortBy}',
        );

        // * Build conditions list
        final List<Condition<Asset>> conditions = [];

        // * Filter by type
        if (params.type != null) {
          conditions.add(Asset_.type.equals(params.type!.index));
        }

        // * Balance range filter
        if (params.minBalance != null && params.maxBalance != null) {
          conditions.add(
            Asset_.balance.between(params.minBalance!, params.maxBalance!),
          );
        } else if (params.minBalance != null) {
          conditions.add(Asset_.balance.greaterOrEqual(params.minBalance!));
        } else if (params.maxBalance != null) {
          conditions.add(Asset_.balance.lessOrEqual(params.maxBalance!));
        }

        // * Case-insensitive search by name
        if (params.searchQuery != null && params.searchQuery!.isNotEmpty) {
          conditions.add(
            Asset_.name.contains(params.searchQuery!, caseSensitive: false),
          );
        }

        // * Build query with conditions
        QueryBuilder<Asset> queryBuilder;
        if (conditions.isNotEmpty) {
          Condition<Asset> combinedCondition = conditions.first;
          for (int i = 1; i < conditions.length; i++) {
            combinedCondition = combinedCondition.and(conditions[i]);
          }
          queryBuilder = _box.query(combinedCondition);
        } else {
          queryBuilder = _box.query();
        }

        // * Apply sorting based on sortBy parameter
        final orderFlags = params.sortOrder == AssetSortOrder.descending
            ? Order.descending
            : 0;

        switch (params.sortBy) {
          case AssetSortBy.name:
            queryBuilder.order(Asset_.name, flags: orderFlags);
            break;
          case AssetSortBy.balance:
            queryBuilder.order(Asset_.balance, flags: orderFlags);
            break;
          case AssetSortBy.createdAt:
            queryBuilder.order(Asset_.createdAt, flags: orderFlags);
            break;
        }

        final builtQuery = queryBuilder.build();
        final allResults = builtQuery.find();
        builtQuery.close();

        // * Cursor-based pagination (offset-based internally)
        final offset = params.cursor != null
            ? int.tryParse(params.cursor!) ?? 0
            : 0;

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

        logInfo('Aset diambil: ${assets.length}, adaLagi: $hasMore');

        return SuccessCursor(
          message: 'Aset berhasil diambil',
          data: assets,
          cursor: cursorInfo,
        );
      },
      (error, stackTrace) {
        logError('Gagal mengambil aset', error, stackTrace);
        return Failure(message: 'Gagal mengambil aset. Silakan coba lagi.');
      },
    );
  }

  @override
  TaskEither<Failure, Success<Asset>> getAssetById({required String ulid}) {
    return TaskEither.tryCatch(
      () async {
        logService('Ambil aset berdasarkan id', ulid);

        final asset = _box.query(Asset_.ulid.equals(ulid)).build().findFirst();

        if (asset == null) {
          throw Exception('Aset tidak ditemukan');
        }

        logInfo('Aset berhasil diambil');
        return Success(message: 'Aset berhasil diambil', data: asset);
      },
      (error, stackTrace) {
        logError('Gagal mengambil aset berdasarkan id', error, stackTrace);
        return Failure(
          message: error.toString().contains('tidak ditemukan')
              ? 'Aset tidak ditemukan'
              : 'Gagal mengambil aset. Silakan coba lagi.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, Success<Asset>> updateAsset(UpdateAssetParams params) {
    return TaskEither.tryCatch(
      () async {
        logService('Perbarui aset', params.ulid);

        final asset = _box
            .query(Asset_.ulid.equals(params.ulid))
            .build()
            .findFirst();

        if (asset == null) {
          throw Exception('Aset tidak ditemukan');
        }

        // * Update fields jika ada
        if (params.name != null) asset.name = params.name!;
        if (params.type != null) asset.type = params.type!.index;
        if (params.balance != null) asset.balance = params.balance!;

        // * Handle icon update - save new and delete old
        if (params.icon != null && params.icon != asset.icon) {
          final savedIconPath = await _fileStorage.updateFile(
            newPath: params.icon,
            oldPath: asset.icon,
            subFolder: _kAssetIconsFolder,
          );
          asset.icon = savedIconPath;
        }

        asset.updatedAt = DateTime.now();
        _box.put(asset);

        logInfo('Aset berhasil diperbarui');
        return Success(message: 'Aset berhasil diperbarui', data: asset);
      },
      (error, stackTrace) {
        logError('Gagal memperbarui aset', error, stackTrace);
        return Failure(
          message: error.toString().contains('tidak ditemukan')
              ? 'Aset tidak ditemukan'
              : 'Gagal memperbarui aset. Silakan coba lagi.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, ActionSuccess> deleteAsset({required String ulid}) {
    return TaskEither.tryCatch(
      () async {
        logService('Hapus aset', ulid);

        final asset = _box.query(Asset_.ulid.equals(ulid)).build().findFirst();

        if (asset == null) {
          throw Exception('Aset tidak ditemukan');
        }

        // * Delete icon file from app storage
        await _fileStorage.deleteFile(asset.icon);

        _box.remove(asset.id);
        logInfo('Aset berhasil dihapus');

        return const ActionSuccess(message: 'Aset berhasil dihapus');
      },
      (error, stackTrace) {
        logError('Gagal menghapus aset', error, stackTrace);
        return Failure(
          message: error.toString().contains('tidak ditemukan')
              ? 'Aset tidak ditemukan'
              : 'Gagal menghapus aset. Silakan coba lagi.',
        );
      },
    );
  }
}
