// Regression: A05, AUTO-1, AUTO-2, AUTO-3, AUTO-5, AUTO-6, AUTO-7, AUTO-9,
// CORE-3, R02 (auto transaction scheduler). Real ObjectBox + real repositories;
// only the notification plugin (OS boundary) is faked.
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_schedule_calculator.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_schedule_frequency.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_group.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_item.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_log.dart';
import 'package:ikuyo_finance/features/auto_transaction/repositories/auto_transaction_repository_impl.dart';
import 'package:ikuyo_finance/features/auto_transaction/services/auto_transaction_notification_service.dart';
import 'package:ikuyo_finance/features/auto_transaction/services/auto_transaction_scheduler.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/transaction/models/create_transaction_params.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/features/transaction/repositories/transaction_repository.dart';
import 'package:ikuyo_finance/features/transaction/repositories/transaction_repository_impl.dart';

import '../support/objectbox_test_store.dart';
import '../support/test_logger.dart';

class _FakeNotif extends Fake implements AutoTransactionNotificationService {
  @override
  Future<void> showExecutionResult(
    AutoTransactionGroup g,
    int s,
    int f,
    int k,
  ) async {}
}

/// Real repository; runs [onCreate] at the moment the scheduler books
/// transactions (both the async and the in-transaction entry points funnel
/// through [createManyTransactionsSync]).
class _SpyTxRepo extends TransactionRepositoryImpl {
  _SpyTxRepo(super.storage, this.onCreate);
  final void Function() onCreate;

  @override
  BulkCreateResult createManyTransactionsSync(
    List<CreateTransactionParams> params,
  ) {
    onCreate();
    return super.createManyTransactionsSync(params);
  }
}

void main() {
  setUpAll(bootstrapTestLogger);

  late ObjectBoxTestStore store;
  late Asset asset;
  late Transaction template;

  setUp(() async {
    store = await ObjectBoxTestStore.open();
    asset = Asset(name: 'Cash', type: 0, balance: 1000);
    store.storage.box<Asset>().put(asset);
    final cat = Category(name: 'Food', type: CategoryType.expense.index);
    store.storage.box<Category>().put(cat);
    template = Transaction(amount: 10, transactionDate: DateTime(2026, 1, 1))
      ..asset.target = asset
      ..category.target = cat;
    store.storage.box<Transaction>().put(template);
  });
  tearDown(() => store.close());

  AutoTransactionScheduler scheduler({TransactionRepository? txRepo}) =>
      AutoTransactionScheduler(
        repo: AutoTransactionRepositoryImpl(store.storage),
        transactionRepo: txRepo ?? TransactionRepositoryImpl(store.storage),
        notifService: _FakeNotif(),
      );

  AutoTransactionGroup seedGroup({
    required DateTime next,
    int hour = 0,
    int minute = 0,
    DateTime? endDate,
    bool isActive = true,
    bool isPaused = false,
    DateTime? pauseEndAt,
  }) {
    final g = AutoTransactionGroup(
      name: 'G',
      frequency: AutoScheduleFrequency.daily.index,
      scheduleHour: hour,
      scheduleMinute: minute,
      startDate: DateTime(2020),
      endDate: endDate,
      nextExecutedAt: next,
      isActive: isActive,
      isPaused: isPaused,
      pauseStartAt: isPaused ? DateTime(2020) : null,
      pauseEndAt: pauseEndAt,
    );
    store.storage.box<AutoTransactionGroup>().put(g);
    store.storage.box<AutoTransactionItem>().put(
      AutoTransactionItem()
        ..group.target = g
        ..transaction.target = template,
    );
    return g;
  }

  int generated() => store.storage.box<Transaction>().count() - 1;
  AutoTransactionGroup reload(AutoTransactionGroup g) =>
      store.storage.box<AutoTransactionGroup>().get(g.id)!;
  DateTime today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  test('AUTO-2 runPendingExecutions completes only after processing', () async {
    seedGroup(next: today());
    await scheduler().runPendingExecutions();
    expect(generated(), 1);
  });

  test('A05/AUTO-1/CORE-3 overlapping runs on one scheduler book a tick once',
      () async {
    seedGroup(next: today());
    final s = scheduler();
    await Future.wait([
      s.runPendingExecutions(),
      s.runPendingExecutions(),
      s.runPendingExecutions(),
    ]);
    await pumpEventQueue(times: 200);
    expect(generated(), 1);
  });

  test('two scheduler instances (e.g. UI + background isolate) book once',
      () async {
    seedGroup(next: today());
    await Future.wait([
      scheduler().runPendingExecutions(),
      scheduler().runPendingExecutions(),
    ]);
    await pumpEventQueue(times: 200);
    expect(generated(), 1);
    expect(store.storage.box<Asset>().get(asset.id)!.balance, 990);
  });

  test('AUTO-3 the tick is claimed (nextExecutedAt advanced) before booking',
      () async {
    final g = seedGroup(next: today());
    DateTime? persistedAtCreate;
    final spy = _SpyTxRepo(store.storage, () {
      persistedAtCreate = reload(g).nextExecutedAt;
    });
    await scheduler(txRepo: spy).runPendingExecutions();
    expect(persistedAtCreate, isNotNull);
    expect(persistedAtCreate!.isAfter(DateTime.now()), isTrue);
  });

  test('R02 a booking crash after the claim rolls the claim back; the retry '
      'books the tick exactly once with one log', () async {
    final g = seedGroup(next: today());
    final before = reload(g).nextExecutedAt;
    var crash = true;
    final flaky = _SpyTxRepo(store.storage, () {
      if (crash) {
        crash = false;
        throw StateError('simulated crash while booking');
      }
    });
    await scheduler(txRepo: flaky).runPendingExecutions();
    expect(generated(), 0);
    expect(
      reload(g).nextExecutedAt!.millisecondsSinceEpoch,
      before!.millisecondsSinceEpoch,
    );
    expect(store.storage.box<AutoTransactionLog>().count(), 0);

    await scheduler(txRepo: flaky).runPendingExecutions();
    expect(generated(), 1);
    expect(store.storage.box<Asset>().get(asset.id)!.balance, 990);
    expect(store.storage.box<AutoTransactionLog>().count(), 1);
    expect(reload(g).nextExecutedAt!.isAfter(DateTime.now()), isTrue);
  });

  test('R02 a user disable during a run is not overwritten by the '
      'post-execution update', () async {
    final g = seedGroup(next: today());
    final spy = _SpyTxRepo(store.storage, () {
      final box = store.storage.box<AutoTransactionGroup>();
      box.put(box.get(g.id)!..isActive = false);
    });
    await scheduler(txRepo: spy).runPendingExecutions();
    expect(reload(g).isActive, isFalse);
  });

  test('R02 a user pause during a run is preserved', () async {
    final g = seedGroup(next: today());
    final spy = _SpyTxRepo(store.storage, () {
      final box = store.storage.box<AutoTransactionGroup>();
      box.put(
        box.get(g.id)!
          ..isPaused = true
          ..pauseStartAt = DateTime.now(),
      );
    });
    await scheduler(txRepo: spy).runPendingExecutions();
    final stored = reload(g);
    expect(stored.isPaused, isTrue);
    expect(stored.isActive, isTrue);
  });

  test('R02 a post-execution update loses the CAS when the schedule moved',
      () async {
    final repo = AutoTransactionRepositoryImpl(store.storage);
    final g = seedGroup(next: today());
    final moved = today().add(const Duration(days: 9));
    store.storage.box<AutoTransactionGroup>().put(
      reload(g)..nextExecutedAt = moved,
    );
    await repo
        .updateGroupAfterExecution(
          ulid: g.ulid,
          expectedNext: today().add(const Duration(days: 1)),
          nextExecutedAt: today().add(const Duration(days: 1)),
          lastExecutedAt: DateTime.now(),
          isActive: true,
        )
        .run();
    expect(
      reload(g).nextExecutedAt!.millisecondsSinceEpoch,
      moved.millisecondsSinceEpoch,
    );
  });

  test('AUTO-6 endDate is enforced per tick and its day is inclusive', () async {
    final d = today();
    final g = seedGroup(
      next: d.subtract(const Duration(days: 3)),
      endDate: d.subtract(const Duration(days: 2)),
    );
    await scheduler().runPendingExecutions();
    // * Tick d-3 dan d-2 (hari endDate) dieksekusi; d-1 dan d tidak
    expect(generated(), 2);
    expect(reload(g).isActive, isFalse);
  });

  test('AUTO-6 a paused group past its endDate is deactivated', () async {
    final d = today();
    final g = seedGroup(
      next: d.subtract(const Duration(days: 3)),
      endDate: d.subtract(const Duration(days: 2)),
      isPaused: true,
    );
    await scheduler().runPendingExecutions();
    expect(generated(), 0);
    expect(reload(g).isActive, isFalse);
  });

  test('AUTO-9 an expired timed pause is resumed and persisted', () async {
    final g = seedGroup(
      next: today(),
      isPaused: true,
      pauseEndAt: DateTime.now().subtract(const Duration(hours: 1)),
    );
    await scheduler().runPendingExecutions();
    final stored = reload(g);
    expect(stored.isPaused, isFalse);
    expect(stored.pauseEndAt, isNull);
  });

  test('AUTO-5 re-enabling a disabled group does not backfill the off period',
      () async {
    final repo = AutoTransactionRepositoryImpl(store.storage);
    final g = seedGroup(
      next: today().subtract(const Duration(days: 3)),
      isActive: false,
    );
    final r = await repo.toggleGroup(ulid: g.ulid, isActive: true).run();
    expect(r.isRight(), isTrue);
    expect(reload(g).nextExecutedAt!.isAfter(DateTime.now()), isTrue);
    await scheduler().runPendingExecutions();
    expect(generated(), 0);
  });

  group('AUTO-7 calculateFirst respects startDate', () {
    test('monthly', () {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month + 2, 20);
      final g = AutoTransactionGroup(
        name: 'M',
        frequency: AutoScheduleFrequency.monthly.index,
        dayOfMonth: 5,
        startDate: start,
      );
      final first = AutoScheduleCalculator.calculateFirst(g);
      expect(first.isBefore(start), isFalse);
      expect(first, DateTime(start.year, start.month + 1, 5, 8));
    });

    test('yearly', () {
      final now = DateTime.now();
      final start = DateTime(now.year + 1, 6, 1);
      final g = AutoTransactionGroup(
        name: 'Y',
        frequency: AutoScheduleFrequency.yearly.index,
        monthOfYear: 3,
        dayOfMonth: 1,
        startDate: start,
      );
      final first = AutoScheduleCalculator.calculateFirst(g);
      expect(first, DateTime(now.year + 2, 3, 1, 8));
    });
  });
}
