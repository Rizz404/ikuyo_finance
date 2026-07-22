import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/export/bloc/export_bloc.dart';
import 'package:ikuyo_finance/features/export/models/export_params.dart';
import 'package:ikuyo_finance/features/export/repositories/export_repository_impl.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';

import '../../../support/objectbox_test_store.dart';
import '../../../support/test_logger.dart';

void main() {
  setUpAll(bootstrapTestLogger);

  late ObjectBoxTestStore testStore;
  late ExportRepositoryImpl repository;
  late Directory tempExportDir;

  setUp(() async {
    testStore = await ObjectBoxTestStore.open();
    repository = ExportRepositoryImpl(testStore.storage);
    tempExportDir = Directory.systemTemp.createTempSync('ikuyo_export_bloc_test_');
  });

  tearDown(() {
    testStore.close();
    if (tempExportDir.existsSync()) {
      tempExportDir.deleteSync(recursive: true);
    }
  });

  group('ExportAssetsLoaded', () {
    blocTest<ExportBloc, ExportState>(
      'loads assets into state',
      setUp: () async {
        testStore.storage.box<Asset>().put(Asset(name: 'Cash', type: AssetType.cash.index));
      },
      build: () => ExportBloc(repository),
      act: (bloc) => bloc.add(ExportAssetsLoaded()),
      expect: () => [
        predicate<ExportState>((s) => s.assets.length == 1 && s.assets.first.name == 'Cash'),
      ],
    );

    blocTest<ExportBloc, ExportState>(
      'emits nothing new when there are no assets',
      build: () => ExportBloc(repository),
      act: (bloc) => bloc.add(ExportAssetsLoaded()),
      expect: () => [predicate<ExportState>((s) => s.assets.isEmpty)],
    );
  });

  group('ExportCategoriesLoaded', () {
    blocTest<ExportBloc, ExportState>(
      'loads categories into state',
      setUp: () async {
        testStore.storage.box<Category>().put(
          Category(name: 'Food', type: CategoryType.expense.index),
        );
      },
      build: () => ExportBloc(repository),
      act: (bloc) => bloc.add(ExportCategoriesLoaded()),
      expect: () => [
        predicate<ExportState>(
          (s) => s.categories.length == 1 && s.categories.first.name == 'Food',
        ),
      ],
    );
  });

  group('ExportExcelRequested', () {
    blocTest<ExportBloc, ExportState>(
      'emits [loading, success] and reports the saved path',
      setUp: () async {
        testStore.storage.box<Asset>().put(Asset(name: 'Cash', type: AssetType.cash.index));
      },
      build: () => ExportBloc(repository),
      act: (bloc) => bloc.add(
        ExportExcelRequested(
          params: const ExportParams(),
          exportDirectory: tempExportDir.path,
          labels: const {},
          currencySymbol: 'Rp',
        ),
      ),
      wait: const Duration(milliseconds: 200),
      expect: () => [
        predicate<ExportState>((s) => s.status == ExportStatus.loading),
        predicate<ExportState>(
          (s) => s.status == ExportStatus.success && s.savedPath != null,
        ),
      ],
      verify: (bloc) {
        expect(File(bloc.state.savedPath!).existsSync(), isTrue);
      },
    );

    blocTest<ExportBloc, ExportState>(
      'emits [loading, failure] when the export directory cannot be created',
      setUp: () async {
        // * Create a plain FILE at the path the bloc will try to use as a
        // * directory, so Directory(...).create() throws.
        File('${tempExportDir.path}/blocked').writeAsStringSync('not a directory');
      },
      build: () => ExportBloc(repository),
      act: (bloc) => bloc.add(
        ExportExcelRequested(
          params: const ExportParams(),
          exportDirectory: '${tempExportDir.path}/blocked',
          labels: const {},
          currencySymbol: 'Rp',
        ),
      ),
      wait: const Duration(milliseconds: 200),
      expect: () => [
        predicate<ExportState>((s) => s.status == ExportStatus.loading),
        predicate<ExportState>((s) => s.status == ExportStatus.failure),
      ],
    );
  });
}
