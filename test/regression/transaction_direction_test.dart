import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/asset/models/create_asset_params.dart';
import 'package:ikuyo_finance/features/asset/repositories/asset_repository_impl.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/statistic/models/get_statistic_params.dart';
import 'package:ikuyo_finance/features/transaction/models/create_transaction_params.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/features/transaction/models/update_transaction_params.dart';
import 'package:ikuyo_finance/features/transaction/repositories/transaction_repository_impl.dart';
import 'package:ikuyo_finance/features/transaction/services/transaction_type_backfill.dart';

import '../support/fake_app_file_storage.dart';
import '../support/objectbox_test_store.dart';
import '../support/test_logger.dart';

void main() {
  setUpAll(bootstrapTestLogger);

  late ObjectBoxTestStore store;
  late AssetRepositoryImpl assetRepo;
  late TransactionRepositoryImpl txRepo;

  setUp(() async {
    store = await ObjectBoxTestStore.open();
    final fs = FakeAppFileStorage();
    assetRepo = AssetRepositoryImpl(store.storage, fs);
    txRepo = TransactionRepositoryImpl(store.storage);
  });
  tearDown(() => store.close());

  Future<Asset> asset(double balance) async => (await assetRepo
          .createAsset(CreateAssetParams(name: 'Cash', type: AssetType.cash, balance: balance))
          .run())
      .getOrElse((f) => throw Exception(f.message))
      .data!;
  Future<Transaction> tx(String assetUlid, double amount,
          {String? categoryUlid, CategoryType? type}) async =>
      (await txRepo
              .createTransaction(CreateTransactionParams(
                  assetUlid: assetUlid,
                  categoryUlid: categoryUlid,
                  type: type,
                  amount: amount,
                  transactionDate: DateTime.now()))
              .run())
          .getOrElse((f) => throw Exception(f.message))
          .data!;
  double bal(String ulid) =>
      store.storage.box<Asset>().getAll().firstWhere((x) => x.ulid == ulid).balance;

  group('A04 explicit direction without category', () {
    test('expense without category debits the asset and is persisted', () async {
      final a = await asset(1000);
      final t = await tx(a.ulid, 100, type: CategoryType.expense);
      expect(bal(a.ulid), 900);
      final stored = store.storage.box<Transaction>().get(t.id)!;
      expect(stored.type, CategoryType.expense.index);

      await txRepo.deleteTransaction(ulid: t.ulid).run();
      expect(bal(a.ulid), 1000);
    });

    test('statistics agree with the balance direction', () async {
      final a = await asset(1000);
      await tx(a.ulid, 100, type: CategoryType.expense);
      await tx(a.ulid, 40, type: CategoryType.income);
      final now = DateTime.now();
      final s = (await txRepo
              .getStatisticSummary(GetStatisticParams(
                  startDate: now.subtract(const Duration(days: 1)),
                  endDate: now.add(const Duration(days: 1))))
              .run())
          .getOrElse((_) => throw Exception())
          .data!;
      expect(s.totalExpense, 100);
      expect(s.totalIncome, 40);
    });

    test('editing amount of an uncategorized expense keeps expense semantics', () async {
      final a = await asset(1000);
      final t = await tx(a.ulid, 100, type: CategoryType.expense);
      await txRepo.updateTransaction(UpdateTransactionParams(ulid: t.ulid, amount: 120)).run();
      expect(bal(a.ulid), 880);
    });
  });

  group('legacy data backfill (non-destructive migration)', () {
    test('fills type from category, or income when uncategorized, without touching balances', () {
      final a = Asset(name: 'A', type: 0, balance: 777);
      store.storage.box<Asset>().put(a);
      final exp = Category(name: 'E', type: CategoryType.expense.index);
      final inc = Category(name: 'I', type: CategoryType.income.index);
      store.storage.box<Category>().putMany([exp, inc]);
      final t1 = Transaction(amount: 1)..asset.target = a..category.target = exp;
      final t2 = Transaction(amount: 2)..asset.target = a..category.target = inc;
      final t3 = Transaction(amount: 3)..asset.target = a;
      final t4 = Transaction(amount: 4, type: CategoryType.expense.index)..asset.target = a;
      store.storage.box<Transaction>().putMany([t1, t2, t3, t4]);
      expect(store.storage.box<Transaction>().get(t1.id)!.type, isNull);

      final updated = TransactionTypeBackfill(store.storage).run();
      expect(updated, 3);
      final box = store.storage.box<Transaction>();
      expect(box.get(t1.id)!.type, CategoryType.expense.index);
      expect(box.get(t2.id)!.type, CategoryType.income.index);
      // * Legacy uncategorized rows were booked as income: keep that meaning
      expect(box.get(t3.id)!.type, CategoryType.income.index);
      expect(box.get(t4.id)!.type, CategoryType.expense.index);
      expect(store.storage.box<Asset>().get(a.id)!.balance, 777);
      expect(TransactionTypeBackfill(store.storage).run(), 0, reason: 'idempotent');
    });
  });
}
