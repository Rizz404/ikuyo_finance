import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/asset/models/create_asset_params.dart';
import 'package:ikuyo_finance/features/asset/models/get_assets_params.dart';
import 'package:ikuyo_finance/features/asset/models/update_asset_params.dart';
import 'package:ikuyo_finance/features/asset/repositories/asset_repository_impl.dart';

import '../../../support/fake_app_file_storage.dart';
import '../../../support/objectbox_test_store.dart';
import '../../../support/test_logger.dart';

void main() {
  late ObjectBoxTestStore testStore;
  late FakeAppFileStorage fileStorage;
  late AssetRepositoryImpl repository;

  setUpAll(bootstrapTestLogger);

  setUp(() async {
    testStore = await ObjectBoxTestStore.open();
    fileStorage = FakeAppFileStorage();
    repository = AssetRepositoryImpl(testStore.storage, fileStorage);
  });

  tearDown(() => testStore.close());

  group('createAsset', () {
    test('persists an asset and assigns a ulid', () async {
      final result = await repository
          .createAsset(
            const CreateAssetParams(name: 'Cash Wallet', type: AssetType.cash),
          )
          .run();

      expect(result.isRight(), isTrue);
      final asset = result.getOrElse((_) => throw Exception()).data!;
      expect(asset.ulid, isNotEmpty);
      expect(asset.name, 'Cash Wallet');
      expect(asset.assetType, AssetType.cash);
      expect(asset.balance, 0);
    });

    test('defaults balance to 0 when not provided', () async {
      final result = await repository
          .createAsset(
            const CreateAssetParams(name: 'BCA', type: AssetType.bank),
          )
          .run();

      final asset = result.getOrElse((_) => throw Exception()).data!;
      expect(asset.balance, 0);
    });

    test('persists the given balance', () async {
      final result = await repository
          .createAsset(
            const CreateAssetParams(
              name: 'BCA',
              type: AssetType.bank,
              balance: 1500000,
            ),
          )
          .run();

      final asset = result.getOrElse((_) => throw Exception()).data!;
      expect(asset.balance, 1500000);
    });

    test('saves the icon through AppFileStorage', () async {
      await repository
          .createAsset(
            const CreateAssetParams(
              name: 'GoPay',
              type: AssetType.eWallet,
              icon: '/tmp/source_icon.png',
            ),
          )
          .run();

      expect(fileStorage.savedPaths, hasLength(1));
    });

    test('does not touch AppFileStorage when icon is null', () async {
      await repository
          .createAsset(
            const CreateAssetParams(name: 'Cash', type: AssetType.cash),
          )
          .run();

      expect(fileStorage.savedPaths, isEmpty);
    });
  });

  group('getAssets', () {
    setUp(() async {
      await repository
          .createAsset(
            const CreateAssetParams(
              name: 'Cash',
              type: AssetType.cash,
              balance: 100,
            ),
          )
          .run();
      await repository
          .createAsset(
            const CreateAssetParams(
              name: 'BCA',
              type: AssetType.bank,
              balance: 500,
            ),
          )
          .run();
      await repository
          .createAsset(
            const CreateAssetParams(
              name: 'Bitcoin',
              type: AssetType.crypto,
              balance: 1000,
            ),
          )
          .run();
    });

    test('returns all assets with no filters', () async {
      final result = await repository.getAssets(const GetAssetsParams()).run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data, hasLength(3));
    });

    test('filters by type', () async {
      final result = await repository
          .getAssets(const GetAssetsParams(type: AssetType.bank))
          .run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data, hasLength(1));
      expect(success.data!.single.name, 'BCA');
    });

    test('filters by minBalance', () async {
      final result = await repository
          .getAssets(const GetAssetsParams(minBalance: 500))
          .run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data!.map((a) => a.name), containsAll(['BCA', 'Bitcoin']));
      expect(success.data, hasLength(2));
    });

    test('filters by maxBalance', () async {
      final result = await repository
          .getAssets(const GetAssetsParams(maxBalance: 100))
          .run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data, hasLength(1));
      expect(success.data!.single.name, 'Cash');
    });

    test('filters by min and max balance range', () async {
      final result = await repository
          .getAssets(const GetAssetsParams(minBalance: 200, maxBalance: 700))
          .run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data, hasLength(1));
      expect(success.data!.single.name, 'BCA');
    });

    test('searches case-insensitively by name', () async {
      final result = await repository
          .getAssets(const GetAssetsParams(searchQuery: 'bca'))
          .run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data, hasLength(1));
      expect(success.data!.single.name, 'BCA');
    });

    test('sorts by name ascending', () async {
      final result = await repository
          .getAssets(
            const GetAssetsParams(
              sortBy: AssetSortBy.name,
              sortOrder: AssetSortOrder.ascending,
            ),
          )
          .run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data!.map((a) => a.name), ['BCA', 'Bitcoin', 'Cash']);
    });

    test('sorts by balance descending', () async {
      final result = await repository
          .getAssets(
            const GetAssetsParams(
              sortBy: AssetSortBy.balance,
              sortOrder: AssetSortOrder.descending,
            ),
          )
          .run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data!.map((a) => a.name), ['Bitcoin', 'BCA', 'Cash']);
    });

    test('paginates using cursor and reports hasNextPage', () async {
      final firstPage = (await repository
              .getAssets(const GetAssetsParams(limit: 2))
              .run())
          .getOrElse((_) => throw Exception());

      expect(firstPage.data, hasLength(2));
      expect(firstPage.cursor.hasNextPage, isTrue);

      final secondPage = (await repository
              .getAssets(GetAssetsParams(limit: 2, cursor: firstPage.cursor.nextCursor))
              .run())
          .getOrElse((_) => throw Exception());

      expect(secondPage.data, hasLength(1));
      expect(secondPage.cursor.hasNextPage, isFalse);
    });

    test('returns empty result set when no asset matches', () async {
      final result = await repository
          .getAssets(const GetAssetsParams(searchQuery: 'nonexistent'))
          .run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data, isEmpty);
      expect(success.cursor.hasNextPage, isFalse);
    });
  });

  group('getAssetById', () {
    test('returns the matching asset', () async {
      final created = (await repository
              .createAsset(
                const CreateAssetParams(name: 'Cash', type: AssetType.cash),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;

      final result = await repository.getAssetById(ulid: created.ulid).run();

      expect(result.isRight(), isTrue);
      expect(result.getOrElse((_) => throw Exception()).data!.name, 'Cash');
    });

    test('fails for an unknown ulid', () async {
      final result = await repository.getAssetById(ulid: 'unknown').run();

      expect(result.isLeft(), isTrue);
    });
  });

  group('updateAsset', () {
    test('updates name, type and balance', () async {
      final created = (await repository
              .createAsset(
                const CreateAssetParams(name: 'Cash', type: AssetType.cash),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;

      final result = await repository
          .updateAsset(
            UpdateAssetParams(
              ulid: created.ulid,
              name: 'Wallet',
              type: AssetType.eWallet,
              balance: 250,
            ),
          )
          .run();

      final updated = result.getOrElse((_) => throw Exception()).data!;
      expect(updated.name, 'Wallet');
      expect(updated.assetType, AssetType.eWallet);
      expect(updated.balance, 250);
    });

    test('partially updates only the balance, leaving other fields untouched', () async {
      final created = (await repository
              .createAsset(
                const CreateAssetParams(
                  name: 'Cash',
                  type: AssetType.cash,
                  balance: 100,
                ),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;

      final result = await repository
          .updateAsset(
            UpdateAssetParams(ulid: created.ulid, balance: 900),
          )
          .run();

      final updated = result.getOrElse((_) => throw Exception()).data!;
      expect(updated.name, 'Cash');
      expect(updated.assetType, AssetType.cash);
      expect(updated.balance, 900);
    });

    test('fails for an unknown ulid', () async {
      final result = await repository
          .updateAsset(const UpdateAssetParams(ulid: 'unknown', name: 'x'))
          .run();

      expect(result.isLeft(), isTrue);
    });

    test('replaces the icon via AppFileStorage.updateFile and deletes the old one', () async {
      final created = (await repository
              .createAsset(
                const CreateAssetParams(
                  name: 'Cash',
                  type: AssetType.cash,
                  icon: '/tmp/old_icon.png',
                ),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;
      final oldIcon = created.icon!;

      await repository
          .updateAsset(
            UpdateAssetParams(ulid: created.ulid, icon: '/tmp/new_icon.png'),
          )
          .run();

      expect(fileStorage.deletedPaths, contains(oldIcon));
    });

    test('does not touch AppFileStorage when icon is unchanged', () async {
      final created = (await repository
              .createAsset(
                const CreateAssetParams(
                  name: 'Cash',
                  type: AssetType.cash,
                  icon: '/tmp/icon.png',
                ),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;
      fileStorage.savedPaths.clear();

      await repository
          .updateAsset(
            UpdateAssetParams(ulid: created.ulid, icon: created.icon),
          )
          .run();

      expect(fileStorage.savedPaths, isEmpty);
      expect(fileStorage.deletedPaths, isEmpty);
    });
  });

  group('deleteAsset', () {
    test('removes the asset', () async {
      final created = (await repository
              .createAsset(
                const CreateAssetParams(name: 'Cash', type: AssetType.cash),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;

      final result = await repository.deleteAsset(ulid: created.ulid).run();

      expect(result.isRight(), isTrue);
      final getResult = await repository.getAssetById(ulid: created.ulid).run();
      expect(getResult.isLeft(), isTrue);
    });

    test('fails for an unknown ulid', () async {
      final result = await repository.deleteAsset(ulid: 'unknown').run();

      expect(result.isLeft(), isTrue);
    });

    test('deletes the icon file through AppFileStorage', () async {
      final created = (await repository
              .createAsset(
                const CreateAssetParams(
                  name: 'Cash',
                  type: AssetType.cash,
                  icon: '/tmp/icon.png',
                ),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;

      await repository.deleteAsset(ulid: created.ulid).run();

      expect(fileStorage.deletedPaths, contains(created.icon));
    });
  });
}
