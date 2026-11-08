// Regression: A01, BKSEC-6, R06 (backup import validation + atomic replace).
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/core/currency/currency.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/asset/models/create_asset_params.dart';
import 'package:ikuyo_finance/features/asset/repositories/asset_repository_impl.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_item.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_log.dart';
import 'package:ikuyo_finance/features/backup/models/backup_data.dart';
import 'package:ikuyo_finance/features/backup/repositories/backup_repository_impl.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
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
    List<TransactionBackup>? transactions,
    List<BudgetBackup>? budgets,
    List<AutoGroupBackup>? autoGroups,
    List<AutoItemBackup>? autoItems,
    List<AutoLogBackup>? autoLogs,
  }) {
    final now = DateTime(2026, 2, 1);
    return BackupData(
      version: '1.0.0',
      createdAt: now,
      appName: 'Ikuyo Finance',
      // * F3: mata uang dinyatakan agar test menguji validasi lain
      currency: BackupCurrency.of(CurrencyCode.idr),
      categories: categories ??
          [CategoryBackup(ulid: 'c1', name: 'New', type: 1, createdAt: now, updatedAt: now)],
      assets: assets ??
          [AssetBackup(ulid: 'a1', name: 'A', type: 0, balance: 1, createdAt: now, updatedAt: now)],
      transactions: transactions ?? const [],
      budgets: budgets ?? const [],
      autoGroups: autoGroups ?? const [],
      autoItems: autoItems ?? const [],
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

  group('R06/BKSEC-6 dangling references are rejected before the '
      'destructive replace', () {
    final now = DateTime(2026, 2, 1);
    TransactionBackup tx({String asset = 'a1', String? category = 'c1'}) =>
        TransactionBackup(
          ulid: 't1',
          assetUlid: asset,
          categoryUlid: category,
          type: 1,
          amount: 5,
          transactionDate: now,
          createdAt: now,
          updatedAt: now,
        );
    AutoGroupBackup group() => AutoGroupBackup(
      ulid: 'g1',
      name: 'G',
      isActive: true,
      isPaused: false,
      frequency: 0,
      scheduleHour: 8,
      scheduleMinute: 0,
      intervalDays: 1,
      activeDaysMask: 127,
      startDate: now,
      createdAt: now,
      updatedAt: now,
    );

    final cases = <String, BackupData Function()>{
      'transaction -> missing asset': () =>
          snapshot(transactions: [tx(asset: 'missing')]),
      'transaction -> missing category': () =>
          snapshot(transactions: [tx(category: 'missing')]),
      'budget -> missing category': () => snapshot(
        budgets: [
          BudgetBackup(
            ulid: 'b1',
            categoryUlid: 'missing',
            amountLimit: 10,
            period: 0,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
      'category -> missing parent': () => snapshot(
        categories: [
          CategoryBackup(
            ulid: 'c1',
            parentUlid: 'missing',
            name: 'New',
            type: 1,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
      'auto item -> missing group': () => snapshot(
        transactions: [tx()],
        autoItems: [
          AutoItemBackup(
            ulid: 'i1',
            groupUlid: 'missing',
            transactionUlid: 't1',
            isActive: true,
            sortOrder: 0,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
      'auto item -> missing transaction': () => snapshot(
        autoGroups: [group()],
        autoItems: [
          AutoItemBackup(
            ulid: 'i1',
            groupUlid: 'g1',
            transactionUlid: 'missing',
            isActive: true,
            sortOrder: 0,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
      'auto log -> missing group': () => snapshot(
        autoLogs: [
          AutoLogBackup(
            ulid: 'l1',
            groupUlid: 'missing',
            scheduledAt: now,
            executedAt: now,
            status: 0,
            successCount: 1,
            failureCount: 0,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
    };

    for (final entry in cases.entries) {
      test(entry.key, () async {
        final result = await backupRepo.importData(entry.value()).run();
        expect(result.isLeft(), isTrue);
        expectOriginalDataIntact();
      });
    }

    test('a fully linked snapshot restores every relation', () async {
      final result = await backupRepo
          .importData(
            snapshot(
              categories: [
                CategoryBackup(
                  ulid: 'p1',
                  name: 'Parent',
                  type: 1,
                  createdAt: now,
                  updatedAt: now,
                ),
                CategoryBackup(
                  ulid: 'c1',
                  parentUlid: 'p1',
                  name: 'New',
                  type: 1,
                  createdAt: now,
                  updatedAt: now,
                ),
              ],
              transactions: [tx()],
              budgets: [
                BudgetBackup(
                  ulid: 'b1',
                  categoryUlid: 'c1',
                  amountLimit: 10,
                  period: 0,
                  createdAt: now,
                  updatedAt: now,
                ),
              ],
              autoGroups: [group()],
              autoItems: [
                AutoItemBackup(
                  ulid: 'i1',
                  groupUlid: 'g1',
                  transactionUlid: 't1',
                  isActive: true,
                  sortOrder: 0,
                  createdAt: now,
                  updatedAt: now,
                ),
              ],
              autoLogs: [
                AutoLogBackup(
                  ulid: 'l1',
                  groupUlid: 'g1',
                  scheduledAt: now,
                  executedAt: now,
                  status: 0,
                  successCount: 1,
                  failureCount: 0,
                  createdAt: now,
                  updatedAt: now,
                ),
              ],
            ),
          )
          .run();
      expect(result.isRight(), isTrue);
      final t = store.storage.box<Transaction>().getAll().single;
      expect(t.asset.target!.ulid, 'a1');
      expect(t.category.target!.ulid, 'c1');
      final c = store.storage
          .box<Category>()
          .getAll()
          .firstWhere((c) => c.ulid == 'c1');
      expect(c.parent.target!.ulid, 'p1');
      final item = store.storage.box<AutoTransactionItem>().getAll().single;
      expect(item.group.target!.ulid, 'g1');
      expect(item.transaction.target!.ulid, 't1');
      expect(
        store.storage.box<AutoTransactionLog>().getAll().single.group.target!.ulid,
        'g1',
      );
      expect(
        store.storage.box<Budget>().getAll().single.category.target!.ulid,
        'c1',
      );
    });
  });
}
