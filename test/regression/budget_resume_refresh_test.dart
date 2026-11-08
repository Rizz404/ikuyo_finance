// Regression: F9 (foreground resume ran the pending auto-transaction
// scheduler and refreshed Transaction/Asset/Statistic, but never Budget, so
// the visible budget progress stayed stale until a manual refresh).
// Real app widget tree (TestApp) with the real AppSecurityWrapper from
// main.dart, a real AutoTransactionScheduler on the same ObjectBox store,
// and a synthetic auto expense due today. Only the OS notification plugin
// is faked.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/core/storage/storage_keys.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_schedule_frequency.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_group.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_item.dart';
import 'package:ikuyo_finance/features/auto_transaction/repositories/auto_transaction_repository_impl.dart';
import 'package:ikuyo_finance/features/auto_transaction/services/auto_transaction_notification_service.dart';
import 'package:ikuyo_finance/features/auto_transaction/services/auto_transaction_scheduler.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/other/screens/other_screen.dart';
import 'package:ikuyo_finance/features/category/bloc/category_bloc.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/category/models/update_category_params.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/features/transaction/repositories/transaction_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

class _FakeNotif extends Fake implements AutoTransactionNotificationService {
  @override
  Future<void> showExecutionResult(
    AutoTransactionGroup g,
    int s,
    int f,
    int k,
  ) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('F9 resume books a due auto expense and the budget card '
      'progress updates without a manual refresh', (tester) async {
    final app = await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.currency: 'idr',
        'cached_exchange_rates': '{"usd":1.0,"idr":16800.0,"eur":0.85}',
        'exchange_rates_timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      rootBundle.clear();
      return TestApp.boot();
    });
    addTearDown(app!.close);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cash = Asset(name: 'Cash', type: 0, balance: 1000);
    app.storage.box<Asset>().put(cash);
    final food = Category(name: 'Food', type: CategoryType.expense.index);
    app.storage.box<Category>().put(food);
    app.storage.box<Budget>().put(
      Budget(amountLimit: 100)..category.target = food,
    );
    // * template dated outside the current month (counts nothing itself)
    final template =
        Transaction(
            amount: 40,
            type: CategoryType.expense.index,
            transactionDate: DateTime(2000, 1, 1),
            createdAt: DateTime(2000, 1, 1),
          )
          ..asset.target = cash
          ..category.target = food;
    app.storage.box<Transaction>().put(template);
    final group = AutoTransactionGroup(
      name: 'Daily lunch',
      frequency: AutoScheduleFrequency.daily.index,
      startDate: DateTime(2020),
      nextExecutedAt: today,
    );
    app.storage.box<AutoTransactionGroup>().put(group);
    app.storage.box<AutoTransactionItem>().put(
      AutoTransactionItem()
        ..group.target = group
        ..transaction.target = template,
    );

    final scheduler = AutoTransactionScheduler(
      repo: AutoTransactionRepositoryImpl(app.storage),
      transactionRepo: TransactionRepositoryImpl(app.storage),
      notifService: _FakeNotif(),
    );
    var runs = 0;
    Future<void> resumeRun() {
      runs++;
      return scheduler.runPendingExecutions();
    }

    await tester.pumpWidget(app.build(resumeRun: resumeRun));
    await tester.pumpAndSettle();
    app.router.go('/budget');
    await tester.pumpAndSettle();
    expect(find.textContaining('0%'), findsOneWidget);
    expect(runs, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.runAsync(() async {
      for (var i = 0; i < 50 && runs == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await scheduler.runPendingExecutions();
    });
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(runs, 1, reason: 'one resume triggers exactly one scheduler run');
    final booked = app.storage
        .box<Transaction>()
        .getAll()
        .where((t) => t.id != template.id)
        .toList();
    expect(booked, hasLength(1), reason: 'the due tick is booked once');
    expect(
      find.textContaining('40%'),
      findsOneWidget,
      reason: 'budget progress must refresh after the resume scheduler run',
    );
  });

  testWidgets('F9 a category move made elsewhere refreshes visible budget '
      'progress', (tester) async {
    final app = await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.currency: 'idr',
        'cached_exchange_rates': '{"usd":1.0,"idr":16800.0,"eur":0.85}',
        'exchange_rates_timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      rootBundle.clear();
      return TestApp.boot();
    });
    addTearDown(app!.close);
    final cash = Asset(name: 'Cash', type: 0, balance: 0);
    app.storage.box<Asset>().put(cash);
    final food = Category(name: 'Food', type: CategoryType.expense.index);
    final snacks = Category(name: 'Snacks', type: CategoryType.expense.index);
    app.storage.box<Category>().putMany([food, snacks]);
    app.storage.box<Transaction>().put(
      Transaction(
          amount: 25,
          type: CategoryType.expense.index,
          transactionDate: DateTime.now(),
        )
        ..asset.target = cash
        ..category.target = snacks,
    );
    app.storage.box<Budget>().put(
      Budget(amountLimit: 100)..category.target = food,
    );

    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    app.router.go('/budget');
    await tester.pumpAndSettle();
    expect(find.textContaining('0%'), findsOneWidget);
    app.router.go('/other');
    await tester.pumpAndSettle();

    // * Snacks becomes a sub-category of Food through the real CategoryBloc
    final ctx = tester.element(find.byType(OtherScreen));
    ctx.read<CategoryBloc>().add(
      CategoryUpdated(
        params: UpdateCategoryParams(
          ulid: snacks.ulid,
          name: snacks.name,
          type: CategoryType.expense,
          parentUlid: food.ulid,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      app.storage.box<Category>().get(snacks.id)!.parent.targetId,
      food.id,
    );

    app.router.go('/budget');
    await tester.pumpAndSettle();
    expect(find.textContaining('25%'), findsOneWidget);
  });

  testWidgets('F9 a resume after the wrapper is unmounted never touches '
      'closed blocs', (tester) async {
    final app = await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({StorageKeys.currency: 'idr'});
      rootBundle.clear();
      return TestApp.boot();
    });
    addTearDown(app!.close);
    var runs = 0;
    await tester.pumpWidget(app.build(resumeRun: () async => runs++));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(runs, 0, reason: 'observer is removed on dispose');
    expect(tester.takeException(), isNull);
  });
}
