import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/asset/models/create_asset_params.dart';
import 'package:ikuyo_finance/features/asset/repositories/asset_repository_impl.dart';
import 'package:ikuyo_finance/features/backup/models/backup_data.dart';
import 'package:ikuyo_finance/features/backup/repositories/backup_repository_impl.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/category/models/create_category_params.dart';
import 'package:ikuyo_finance/features/category/repositories/category_repository_impl.dart';
import 'package:ikuyo_finance/features/transaction/models/create_transaction_params.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/features/transaction/repositories/transaction_repository_impl.dart';

import '../support/fake_app_file_storage.dart';
import '../support/objectbox_test_store.dart';
import '../support/test_logger.dart';

/// List that throws on its second iteration, used to inject a fault in the
/// middle of an import after any up-front validation has already read it.
class _FailOnSecondIteration<E> extends ListBase<E> {
  final List<E> _inner;
  int _iterations = 0;
  _FailOnSecondIteration(this._inner);

  @override
  int get length => _inner.length;
  @override
  set length(int v) => _inner.length = v;
  @override
  E operator [](int i) => _inner[i];
  @override
  void operator []=(int i, E v) => _inner[i] = v;
  @override
  Iterator<E> get iterator {
    _iterations++;
    if (_iterations >= 2) throw StateError('injected fault during import');
    return _inner.iterator;
  }
}

void main() {
  setUpAll(bootstrapTestLogger);

  late ObjectBoxTestStore store;
  late BackupRepositoryImpl backupRepo;
  late String assetUlid;

  setUp(() async {
    store = await ObjectBoxTestStore.open();
    final fs = FakeAppFileStorage();
    backupRepo = BackupRepositoryImpl(store.storage);
    final asset = (await AssetRepositoryImpl(store.storage, fs)
            .createAsset(const CreateAssetParams(
                name: 'Cash', type: AssetType.cash, balance: 500))
            .run())
        .getOrElse((f) => throw Exception(f.message))
        .data!;
    assetUlid = asset.ulid;
    final category = (await CategoryRepositoryImpl(store.storage, fs)
            .createCategory(const CreateCategoryParams(
                name: 'Food', type: CategoryType.expense))
            .run())
        .getOrElse((f) => throw Exception(f.message))
        .data!;
    await TransactionRepositoryImpl(store.storage)
        .createTransaction(CreateTransactionParams(
            assetUlid: asset.ulid,
            categoryUlid: category.ulid,
            amount: 20,
            transactionDate: DateTime(2026, 1, 1)))
        .run();
  });
  tearDown(() => store.close());

  void expectOriginalDataIntact() {
    final assets = store.storage.box<Asset>().getAll();
    expect(assets.map((a) => a.ulid), [assetUlid]);
    expect(assets.single.balance, 480);
    expect(store.storage.box<Transaction>().count(), 1);
    expect(store.storage.box<Category>().getAll().map((c) => c.name), ['Food']);
  }

  BackupData snapshot({
    List<CategoryBackup>? categories,
    List<AssetBackup>? assets,
    List<AutoLogBackup>? autoLogs,
  }) {
    final now = DateTime(2026, 2, 1);
    return BackupData(
      version: '1.0.0',
      createdAt: now,
      appName: 'Ikuyo Finance',
      categories: categories ??
          [CategoryBackup(ulid: 'c1', name: 'New', type: 1, createdAt: now, updatedAt: now)],
      assets: assets ??
          [AssetBackup(ulid: 'a1', name: 'A', type: 0, balance: 1, createdAt: now, updatedAt: now)],
      transactions: const [],
      budgets: const [],
      autoLogs: autoLogs ?? const [],
    );
  }

  test('A01 duplicate ulid in snapshot fails and keeps existing data', () async {
    final now = DateTime(2026, 2, 1);
    final result = await backupRepo
        .importData(snapshot(assets: [
          AssetBackup(ulid: 'x', name: 'A', type: 0, balance: 1, createdAt: now, updatedAt: now),
          AssetBackup(ulid: 'x', name: 'B', type: 0, balance: 2, createdAt: now, updatedAt: now),
        ]))
        .run();
    expect(result.isLeft(), isTrue);
    expectOriginalDataIntact();
  });

  test('A01/BKSEC-6 out-of-range enum value is rejected before any write', () async {
    final now = DateTime(2026, 2, 1);
    final result = await backupRepo
        .importData(snapshot(assets: [
          AssetBackup(ulid: 'a1', name: 'A', type: 99, balance: 1, createdAt: now, updatedAt: now),
        ]))
        .run();
    expect(result.isLeft(), isTrue);
    expectOriginalDataIntact();
  });

  test('A01 fault in the middle of import rolls back every write', () async {
    final result = await backupRepo
        .importData(snapshot(autoLogs: _FailOnSecondIteration(<AutoLogBackup>[])))
        .run();
    expect(result.isLeft(), isTrue);
    expectOriginalDataIntact();
  });

  test('A01 valid snapshot still replaces data', () async {
    final result = await backupRepo.importData(snapshot()).run();
    expect(result.isRight(), isTrue);
    expect(store.storage.box<Asset>().getAll().map((a) => a.ulid), ['a1']);
    expect(store.storage.box<Transaction>().count(), 0);
    expect(store.storage.box<Category>().getAll().map((c) => c.ulid), ['c1']);
  });
}
