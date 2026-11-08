import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/core/currency/currency.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/asset/models/create_asset_params.dart';
import 'package:ikuyo_finance/features/asset/repositories/asset_repository_impl.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_schedule_frequency.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_group.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_item.dart';
import 'package:ikuyo_finance/features/auto_transaction/repositories/auto_transaction_repository_impl.dart';
import 'package:ikuyo_finance/features/auto_transaction/services/auto_transaction_notification_service.dart';
import 'package:ikuyo_finance/features/auto_transaction/services/auto_transaction_scheduler.dart';
import 'package:ikuyo_finance/features/backup/repositories/backup_repository_impl.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/category/models/create_category_params.dart';
import 'package:ikuyo_finance/features/category/models/update_category_params.dart';
import 'package:ikuyo_finance/features/category/repositories/category_repository_impl.dart';
import 'package:ikuyo_finance/features/statistic/models/get_statistic_params.dart';
import 'package:ikuyo_finance/features/transaction/models/create_transaction_params.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/features/transaction/models/update_transaction_params.dart';
import 'package:ikuyo_finance/features/transaction/repositories/transaction_repository_impl.dart';
import 'package:ikuyo_finance/features/transaction/services/transaction_type_backfill.dart';

import '../support/fake_app_file_storage.dart';
import '../support/objectbox_test_store.dart';
import '../support/test_logger.dart';

class _FakeNotif extends Fake implements AutoTransactionNotificationService {
  @override
  Future<void> showExecutionResult(AutoTransactionGroup g, int s, int f, int k) async {}
}

void main() {
  setUpAll(bootstrapTestLogger);

  late ObjectBoxTestStore store;
  late AssetRepositoryImpl assetRepo;
  late CategoryRepositoryImpl categoryRepo;
  late TransactionRepositoryImpl txRepo;

  setUp(() async {
    store = await ObjectBoxTestStore.open();
    final fs = FakeAppFileStorage();
    assetRepo = AssetRepositoryImpl(store.storage, fs);
    categoryRepo = CategoryRepositoryImpl(store.storage, fs);
    txRepo = TransactionRepositoryImpl(store.storage);
  });
  tearDown(() => store.close());

  Future<Asset> asset(double balance) async => (await assetRepo
          .createAsset(CreateAssetParams(name: 'Cash', type: AssetType.cash, balance: balance))
          .run())
      .getOrElse((f) => throw Exception(f.message))
      .data!;
  Future<Category> category(CategoryType t) async => (await categoryRepo
          .createCategory(CreateCategoryParams(name: 'Food', type: t))
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

  group('A03/CSE-1/CSE-3 referenced categories are protected', () {
    test('deleting a category used by a transaction is blocked', () async {
      final a = await asset(1000);
      final c = await category(CategoryType.expense);
      final t = await tx(a.ulid, 100, categoryUlid: c.ulid);
      final r = await categoryRepo.deleteCategory(ulid: c.ulid).run();
      expect(r.isLeft(), isTrue);
      expect(store.storage.box<Category>().count(), 1);
      // * Ledger stays consistent on later edit/delete
      await txRepo.updateTransaction(UpdateTransactionParams(ulid: t.ulid, amount: 120)).run();
      expect(bal(a.ulid), 880);
    });

    test('deleting a category used by a budget is blocked', () async {
      final c = await category(CategoryType.expense);
      store.storage.box<Budget>().put(Budget(amountLimit: 10)..category.target = c);
      final r = await categoryRepo.deleteCategory(ulid: c.ulid).run();
      expect(r.isLeft(), isTrue);
      expect(store.storage.box<Category>().count(), 1);
    });

    test('changing the type of a referenced category is blocked', () async {
      final a = await asset(1000);
      final c = await category(CategoryType.expense);
      final t = await tx(a.ulid, 100, categoryUlid: c.ulid);
      final r = await categoryRepo
          .updateCategory(UpdateCategoryParams(ulid: c.ulid, name: c.name, type: CategoryType.income))
          .run();
      expect(r.isLeft(), isTrue);
      expect(store.storage.box<Category>().get(c.id)!.type, CategoryType.expense.index);
      await txRepo.deleteTransaction(ulid: t.ulid).run();
      expect(bal(a.ulid), 1000);
    });

    test('renaming a referenced category (same type) is still allowed', () async {
      final a = await asset(1000);
      final c = await category(CategoryType.expense);
      await tx(a.ulid, 100, categoryUlid: c.ulid);
      final r = await categoryRepo
          .updateCategory(UpdateCategoryParams(ulid: c.ulid, name: 'Meals', type: CategoryType.expense))
          .run();
      expect(r.isRight(), isTrue);
    });

    test('unreferenced category can still be deleted', () async {
      final c = await category(CategoryType.expense);
      final r = await categoryRepo.deleteCategory(ulid: c.ulid).run();
      expect(r.isRight(), isTrue);
    });
  });

  group('A02 referenced assets are protected', () {
    test('deleting an asset with transactions is blocked and nothing is orphaned', () async {
      final a = await asset(1000);
      await tx(a.ulid, 10, type: CategoryType.expense);
      final r = await assetRepo.deleteAsset(ulid: a.ulid).run();
      expect(r.isLeft(), isTrue);
      expect(store.storage.box<Asset>().count(), 1);
      final exp = (await BackupRepositoryImpl(store.storage).exportData().run())
          .getOrElse((_) => throw Exception())
          .data!;
      expect(exp.transactions, hasLength(1));
    });

    test('asset without transactions can still be deleted', () async {
      final a = await asset(1000);
      final r = await assetRepo.deleteAsset(ulid: a.ulid).run();
      expect(r.isRight(), isTrue);
    });
  });

  test('AUTO-10 scheduler copies the template direction', () async {
    final a = await asset(1000);
    final template = await tx(a.ulid, 10, type: CategoryType.expense);
    expect(bal(a.ulid), 990);
    final now = DateTime.now();
    final g = AutoTransactionGroup(
      name: 'G',
      frequency: AutoScheduleFrequency.daily.index,
      scheduleHour: now.hour,
      scheduleMinute: now.minute,
      startDate: now.subtract(const Duration(days: 1)),
      nextExecutedAt: now.subtract(const Duration(hours: 1)),
    );
    store.storage.box<AutoTransactionGroup>().put(g);
    store.storage.box<AutoTransactionItem>().put(AutoTransactionItem()
      ..group.target = g
      ..transaction.target = template);
    final scheduler = AutoTransactionScheduler(
        repo: AutoTransactionRepositoryImpl(store.storage),
        transactionRepo: txRepo,
        notifService: _FakeNotif());
    await scheduler.runPendingExecutions();
    await pumpEventQueue(times: 50);
    expect(store.storage.box<Transaction>().count(), 2);
    expect(bal(a.ulid), 980);
  });

  test('backup round-trip preserves direction of uncategorized transactions', () async {
    final a = await asset(1000);
    await tx(a.ulid, 100, type: CategoryType.expense);
    final backup = BackupRepositoryImpl(store.storage);
    // * F3: export membawa penanda mata uang DB; tanpa penanda impor ditolak
    CurrencyMigrationService(store.storage).markStoredCurrency(CurrencyCode.idr);
    final data = (await backup.exportData().run()).getOrElse((_) => throw Exception()).data!;
    final restored = await backup.importData(data).run();
    expect(restored.isRight(), isTrue);
    final t = store.storage.box<Transaction>().getAll().single;
    expect(t.type, CategoryType.expense.index);
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

  group('R07 one direction rule: the stored/explicit type wins, category is '
      'only a fallback, legacy uncategorized = income', () {
    test('a template whose stored type disagrees with its category books '
        'the stored direction (scheduler, balance, statistics agree)',
        () async {
      final a = await asset(1000);
      final inc = await category(CategoryType.income);
      final template = Transaction(
        amount: 10,
        type: CategoryType.expense.index,
        transactionDate: DateTime(2026, 1, 1),
      )
        ..asset.target = store.storage.box<Asset>().getAll().single
        ..category.target = inc;
      store.storage.box<Transaction>().put(template);
      expect(template.direction, CategoryType.expense);

      final now = DateTime.now();
      final g = AutoTransactionGroup(
        name: 'G',
        frequency: AutoScheduleFrequency.daily.index,
        scheduleHour: now.hour,
        scheduleMinute: now.minute,
        startDate: now.subtract(const Duration(days: 1)),
        nextExecutedAt: now.subtract(const Duration(hours: 1)),
      );
      store.storage.box<AutoTransactionGroup>().put(g);
      store.storage.box<AutoTransactionItem>().put(AutoTransactionItem()
        ..group.target = g
        ..transaction.target = template);
      await AutoTransactionScheduler(
        repo: AutoTransactionRepositoryImpl(store.storage),
        transactionRepo: txRepo,
        notifService: _FakeNotif(),
      ).runPendingExecutions();

      final booked = store.storage
          .box<Transaction>()
          .getAll()
          .firstWhere((t) => t.id != template.id);
      expect(booked.direction, CategoryType.expense);
      expect(bal(a.ulid), 990);
    });

    test('an explicit type passed with a conflicting category is what is '
        'stored, balanced and reported', () async {
      final a = await asset(1000);
      final inc = await category(CategoryType.income);
      final t = await tx(
        a.ulid,
        100,
        categoryUlid: inc.ulid,
        type: CategoryType.expense,
      );
      final stored = store.storage.box<Transaction>().get(t.id)!;
      expect(stored.direction, CategoryType.expense);
      expect(bal(a.ulid), 900);
      final summary = (await txRepo
              .getStatisticSummary(GetStatisticParams(
                startDate: DateTime.now().subtract(const Duration(days: 1)),
                endDate: DateTime.now().add(const Duration(days: 1)),
              ))
              .run())
          .getOrElse((_) => throw Exception())
          .data!;
      expect(summary.totalExpense, 100);
      expect(summary.totalIncome, 0);
    });

    test('an edit with an explicit type and a conflicting category follows '
        'the type', () async {
      final a = await asset(1000);
      final exp = await category(CategoryType.expense);
      final inc = (await categoryRepo
              .createCategory(
                CreateCategoryParams(name: 'Salary', type: CategoryType.income),
              )
              .run())
          .getOrElse((f) => throw Exception(f.message))
          .data!;
      final t = await tx(a.ulid, 100, categoryUlid: exp.ulid);
      expect(bal(a.ulid), 900);
      await txRepo
          .updateTransaction(UpdateTransactionParams(
            ulid: t.ulid,
            categoryUlid: inc.ulid,
            type: CategoryType.expense,
          ))
          .run();
      final stored = store.storage.box<Transaction>().get(t.id)!;
      expect(stored.direction, CategoryType.expense);
      expect(bal(a.ulid), 900);
    });

    test('a legacy uncategorized row is income after the backfill in '
        'balance, statistics and the model getter', () async {
      final a = Asset(name: 'A', type: 0, balance: 500);
      store.storage.box<Asset>().put(a);
      final legacy = Transaction(amount: 50, transactionDate: DateTime.now())
        ..asset.target = a;
      store.storage.box<Transaction>().put(legacy);
      TransactionTypeBackfill(store.storage).run();
      final stored = store.storage.box<Transaction>().get(legacy.id)!;
      expect(stored.direction, CategoryType.income);
      final summary = (await txRepo
              .getStatisticSummary(GetStatisticParams(
                startDate: DateTime.now().subtract(const Duration(days: 1)),
                endDate: DateTime.now().add(const Duration(days: 1)),
              ))
              .run())
          .getOrElse((_) => throw Exception())
          .data!;
      expect(summary.totalIncome, 50);
      expect(store.storage.box<Asset>().get(a.id)!.balance, 500);
      // * Menghapus baris lama mengembalikan saldo dengan arah yang sama
      await txRepo.deleteTransaction(ulid: stored.ulid).run();
      expect(store.storage.box<Asset>().get(a.id)!.balance, 450);
    });
  });
}
