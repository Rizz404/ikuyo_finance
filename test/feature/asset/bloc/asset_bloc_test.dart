import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/asset/bloc/asset_bloc.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/asset/models/create_asset_params.dart';
import 'package:ikuyo_finance/features/asset/models/get_assets_params.dart';
import 'package:ikuyo_finance/features/asset/models/update_asset_params.dart';
import 'package:ikuyo_finance/features/asset/repositories/asset_repository_impl.dart';

import '../../../support/fake_app_file_storage.dart';
import '../../../support/objectbox_test_store.dart';
import '../../../support/test_logger.dart';

void main() {
  setUpAll(bootstrapTestLogger);

  late ObjectBoxTestStore testStore;
  late AssetRepositoryImpl repository;

  setUp(() async {
    testStore = await ObjectBoxTestStore.open();
    repository = AssetRepositoryImpl(testStore.storage, FakeAppFileStorage());
  });

  tearDown(() => testStore.close());

  group('AssetFetched', () {
    blocTest<AssetBloc, AssetState>(
      'emits [loading, success] with the fetched assets',
      setUp: () async {
        await repository
            .createAsset(
              const CreateAssetParams(name: 'Cash', type: AssetType.cash),
            )
            .run();
      },
      build: () => AssetBloc(repository),
      act: (bloc) => bloc.add(const AssetFetched()),
      expect: () => [
        predicate<AssetState>((s) => s.status == AssetStatus.loading),
        predicate<AssetState>(
          (s) =>
              s.status == AssetStatus.success &&
              s.assets.length == 1 &&
              s.assets.first.name == 'Cash',
        ),
      ],
    );

    blocTest<AssetBloc, AssetState>(
      'emits an empty success state when there is no data',
      build: () => AssetBloc(repository),
      act: (bloc) => bloc.add(const AssetFetched()),
      expect: () => [
        predicate<AssetState>((s) => s.status == AssetStatus.loading),
        predicate<AssetState>(
          (s) => s.status == AssetStatus.success && s.assets.isEmpty,
        ),
      ],
    );

    blocTest<AssetBloc, AssetState>(
      'filters by type when fetching',
      setUp: () async {
        await repository
            .createAsset(
              const CreateAssetParams(name: 'Cash', type: AssetType.cash),
            )
            .run();
        await repository
            .createAsset(
              const CreateAssetParams(name: 'BCA', type: AssetType.bank),
            )
            .run();
      },
      build: () => AssetBloc(repository),
      act: (bloc) => bloc.add(const AssetFetched(type: AssetType.bank)),
      expect: () => [
        predicate<AssetState>((s) => s.status == AssetStatus.loading),
        predicate<AssetState>(
          (s) =>
              s.status == AssetStatus.success &&
              s.assets.length == 1 &&
              s.assets.first.name == 'BCA' &&
              s.currentTypeFilter == AssetType.bank,
        ),
      ],
    );
  });

  group('AssetFetchedMore', () {
    blocTest<AssetBloc, AssetState>(
      'loads the next page and reports hasReachedMax once exhausted',
      setUp: () async {
        for (var i = 0; i < 25; i++) {
          await repository
              .createAsset(
                CreateAssetParams(name: 'Asset $i', type: AssetType.cash),
              )
              .run();
        }
      },
      build: () => AssetBloc(repository),
      act: (bloc) async {
        bloc.add(const AssetFetched());
        await bloc.stream.firstWhere((s) => s.status == AssetStatus.success);
        bloc.add(const AssetFetchedMore());
      },
      skip: 1,
      expect: () => [
        predicate<AssetState>(
          (s) =>
              s.status == AssetStatus.success &&
              s.assets.length == 20 &&
              !s.hasReachedMax,
        ),
        predicate<AssetState>((s) => s.status == AssetStatus.loadingMore),
        predicate<AssetState>(
          (s) =>
              s.status == AssetStatus.success &&
              s.assets.length == 25 &&
              s.hasReachedMax,
        ),
      ],
    );

    blocTest<AssetBloc, AssetState>(
      'does nothing when hasReachedMax is already true',
      seed: () => const AssetState(hasReachedMax: true),
      build: () => AssetBloc(repository),
      act: (bloc) => bloc.add(const AssetFetchedMore()),
      expect: () => [],
    );
  });

  group('AssetRefreshed', () {
    blocTest<AssetBloc, AssetState>(
      'resets pagination and refetches with current filters',
      setUp: () async {
        await repository
            .createAsset(
              const CreateAssetParams(name: 'BCA', type: AssetType.bank),
            )
            .run();
      },
      build: () => AssetBloc(repository),
      seed: () => const AssetState(hasReachedMax: true, nextCursor: '20'),
      act: (bloc) => bloc.add(const AssetRefreshed()),
      expect: () => [
        predicate<AssetState>(
          (s) => s.status == AssetStatus.loading && !s.hasReachedMax,
        ),
        predicate<AssetState>(
          (s) => s.status == AssetStatus.success && s.assets.length == 1,
        ),
      ],
    );
  });

  group('AssetSearched', () {
    blocTest<AssetBloc, AssetState>(
      'debounces and filters by the search query',
      setUp: () async {
        await repository
            .createAsset(
              const CreateAssetParams(name: 'BCA', type: AssetType.bank),
            )
            .run();
        await repository
            .createAsset(
              const CreateAssetParams(name: 'Cash', type: AssetType.cash),
            )
            .run();
      },
      build: () => AssetBloc(repository),
      act: (bloc) => bloc.add(const AssetSearched(query: 'bc')),
      wait: const Duration(milliseconds: 350),
      expect: () => [
        predicate<AssetState>((s) => s.status == AssetStatus.loading),
        predicate<AssetState>(
          (s) =>
              s.status == AssetStatus.success &&
              s.assets.length == 1 &&
              s.assets.first.name == 'BCA',
        ),
      ],
    );
  });

  group('AssetFiltered', () {
    blocTest<AssetBloc, AssetState>(
      'applies balance range filters',
      setUp: () async {
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
                balance: 900,
              ),
            )
            .run();
      },
      build: () => AssetBloc(repository),
      act: (bloc) => bloc.add(const AssetFiltered(minBalance: 500)),
      expect: () => [
        predicate<AssetState>((s) => s.status == AssetStatus.loading),
        predicate<AssetState>(
          (s) =>
              s.status == AssetStatus.success &&
              s.assets.length == 1 &&
              s.assets.first.name == 'BCA' &&
              s.currentMinBalance == 500,
        ),
      ],
    );
  });

  group('AssetSorted', () {
    blocTest<AssetBloc, AssetState>(
      'sorts assets by name ascending',
      setUp: () async {
        await repository
            .createAsset(
              const CreateAssetParams(name: 'Cash', type: AssetType.cash),
            )
            .run();
        await repository
            .createAsset(
              const CreateAssetParams(name: 'BCA', type: AssetType.bank),
            )
            .run();
      },
      build: () => AssetBloc(repository),
      act: (bloc) => bloc.add(
        const AssetSorted(
          sortBy: AssetSortBy.name,
          sortOrder: AssetSortOrder.ascending,
        ),
      ),
      expect: () => [
        predicate<AssetState>((s) => s.status == AssetStatus.loading),
        predicate<AssetState>(
          (s) =>
              s.status == AssetStatus.success &&
              s.assets.map((a) => a.name).toList().first == 'BCA',
        ),
      ],
    );
  });

  group('AssetFilterCleared', () {
    blocTest<AssetBloc, AssetState>(
      'resets filters and sort back to defaults',
      build: () => AssetBloc(repository),
      seed: () => const AssetState(
        currentTypeFilter: AssetType.bank,
        currentSearchQuery: 'foo',
        currentMinBalance: 100,
      ),
      act: (bloc) => bloc.add(const AssetFilterCleared()),
      expect: () => [
        predicate<AssetState>(
          (s) => s.status == AssetStatus.loading && !s.hasActiveFilters,
        ),
        predicate<AssetState>(
          (s) => s.status == AssetStatus.success && !s.hasActiveFilters,
        ),
      ],
    );
  });

  group('AssetCreated', () {
    blocTest<AssetBloc, AssetState>(
      'emits [writeLoading, writeSuccess] and prepends the new asset',
      build: () => AssetBloc(repository),
      act: (bloc) => bloc.add(
        const AssetCreated(
          params: CreateAssetParams(name: 'Cash', type: AssetType.cash),
        ),
      ),
      expect: () => [
        predicate<AssetState>((s) => s.writeStatus == AssetWriteStatus.loading),
        predicate<AssetState>(
          (s) =>
              s.writeStatus == AssetWriteStatus.success &&
              s.assets.length == 1 &&
              s.assets.first.name == 'Cash' &&
              s.lastCreatedAsset?.name == 'Cash',
        ),
      ],
    );
  });

  group('AssetUpdated', () {
    blocTest<AssetBloc, AssetState>(
      'replaces the matching asset in the list on success',
      setUp: () async {
        await repository
            .createAsset(
              const CreateAssetParams(name: 'Cash', type: AssetType.cash),
            )
            .run();
      },
      build: () => AssetBloc(repository),
      act: (bloc) async {
        bloc.add(const AssetFetched());
        await bloc.stream.firstWhere((s) => s.status == AssetStatus.success);
        final ulid = bloc.state.assets.single.ulid;
        bloc.add(
          AssetUpdated(params: UpdateAssetParams(ulid: ulid, name: 'Wallet')),
        );
      },
      skip: 2,
      expect: () => [
        predicate<AssetState>((s) => s.writeStatus == AssetWriteStatus.loading),
        predicate<AssetState>(
          (s) =>
              s.writeStatus == AssetWriteStatus.success &&
              s.assets.single.name == 'Wallet',
        ),
      ],
    );

    blocTest<AssetBloc, AssetState>(
      'emits writeFailure for an unknown ulid',
      build: () => AssetBloc(repository),
      act: (bloc) => bloc.add(
        const AssetUpdated(
          params: UpdateAssetParams(ulid: 'unknown', name: 'x'),
        ),
      ),
      expect: () => [
        predicate<AssetState>((s) => s.writeStatus == AssetWriteStatus.loading),
        predicate<AssetState>((s) => s.writeStatus == AssetWriteStatus.failure),
      ],
    );
  });

  group('AssetDeleted', () {
    blocTest<AssetBloc, AssetState>(
      'removes the asset from the list on success',
      setUp: () async {
        await repository
            .createAsset(
              const CreateAssetParams(name: 'Cash', type: AssetType.cash),
            )
            .run();
      },
      build: () => AssetBloc(repository),
      act: (bloc) async {
        bloc.add(const AssetFetched());
        await bloc.stream.firstWhere((s) => s.status == AssetStatus.success);
        final ulid = bloc.state.assets.single.ulid;
        bloc.add(AssetDeleted(ulid: ulid));
      },
      skip: 2,
      expect: () => [
        predicate<AssetState>((s) => s.writeStatus == AssetWriteStatus.loading),
        predicate<AssetState>(
          (s) => s.writeStatus == AssetWriteStatus.success && s.assets.isEmpty,
        ),
      ],
    );

    blocTest<AssetBloc, AssetState>(
      'emits writeFailure for an unknown ulid',
      build: () => AssetBloc(repository),
      act: (bloc) => bloc.add(const AssetDeleted(ulid: 'unknown')),
      expect: () => [
        predicate<AssetState>((s) => s.writeStatus == AssetWriteStatus.loading),
        predicate<AssetState>((s) => s.writeStatus == AssetWriteStatus.failure),
      ],
    );
  });

  group('AssetBatchDeleted', () {
    blocTest<AssetBloc, AssetState>(
      'removes all matching assets when every deletion succeeds',
      setUp: () async {
        await repository
            .createAsset(
              const CreateAssetParams(name: 'Cash', type: AssetType.cash),
            )
            .run();
        await repository
            .createAsset(
              const CreateAssetParams(name: 'BCA', type: AssetType.bank),
            )
            .run();
      },
      build: () => AssetBloc(repository),
      act: (bloc) async {
        bloc.add(const AssetFetched());
        await bloc.stream.firstWhere((s) => s.status == AssetStatus.success);
        final ulids = bloc.state.assets.map((a) => a.ulid).toList();
        bloc.add(AssetBatchDeleted(ulids: ulids));
      },
      skip: 2,
      expect: () => [
        predicate<AssetState>((s) => s.writeStatus == AssetWriteStatus.loading),
        predicate<AssetState>(
          (s) => s.writeStatus == AssetWriteStatus.success && s.assets.isEmpty,
        ),
      ],
    );

    blocTest<AssetBloc, AssetState>(
      'reports failure and keeps only the assets that failed to delete',
      setUp: () async {
        await repository
            .createAsset(
              const CreateAssetParams(name: 'Cash', type: AssetType.cash),
            )
            .run();
      },
      build: () => AssetBloc(repository),
      act: (bloc) async {
        bloc.add(const AssetFetched());
        await bloc.stream.firstWhere((s) => s.status == AssetStatus.success);
        final ulid = bloc.state.assets.single.ulid;
        bloc.add(AssetBatchDeleted(ulids: [ulid, 'unknown']));
      },
      skip: 2,
      expect: () => [
        predicate<AssetState>((s) => s.writeStatus == AssetWriteStatus.loading),
        predicate<AssetState>(
          (s) => s.writeStatus == AssetWriteStatus.failure && s.assets.isEmpty,
        ),
      ],
    );
  });

  group('AssetWriteStatusReset', () {
    blocTest<AssetBloc, AssetState>(
      'clears write status and messages back to initial',
      build: () => AssetBloc(repository),
      seed: () => const AssetState(
        writeStatus: AssetWriteStatus.success,
        writeAction: AssetWriteAction.create,
        writeSuccessMessage: 'done',
      ),
      act: (bloc) => bloc.add(const AssetWriteStatusReset()),
      expect: () => [
        predicate<AssetState>(
          (s) =>
              s.writeStatus == AssetWriteStatus.initial &&
              s.writeAction == AssetWriteAction.none &&
              s.writeSuccessMessage == null,
        ),
      ],
    );
  });

  group('searchAssetsForDropdown', () {
    test('returns matching assets without mutating bloc state', () async {
      await repository
          .createAsset(
            const CreateAssetParams(name: 'BCA', type: AssetType.bank),
          )
          .run();
      await repository
          .createAsset(
            const CreateAssetParams(name: 'Cash', type: AssetType.cash),
          )
          .run();

      final bloc = AssetBloc(repository);
      final results = await bloc.searchAssetsForDropdown(query: 'bc');

      expect(results, hasLength(1));
      expect(results.single.name, 'BCA');
      expect(bloc.state, const AssetState());

      await bloc.close();
    });

    test('returns an empty list when nothing matches', () async {
      final bloc = AssetBloc(repository);

      final results = await bloc.searchAssetsForDropdown(
        type: AssetType.bank,
      );

      expect(results, isEmpty);

      await bloc.close();
    });
  });
}
