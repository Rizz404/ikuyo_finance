// Regression: F8 (BudgetScreen was routable but unreachable: pushToBudget had
// no caller and no screen offered an entry). The Others grid must expose a
// localized Budget entry (reusing the existing budget.screen.title label)
// that opens the real BudgetScreen, where create / edit / progress work.
// Real app widget tree (TestApp: real router, blocs, repositories, ObjectBox).
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/storage/storage_keys.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/budget/screens/budget_screen.dart';
import 'package:ikuyo_finance/features/budget/screens/budget_upsert_screen.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/other/screens/other_screen.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/shared/widgets/app_button.dart';
import 'package:ikuyo_finance/shared/widgets/app_text_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // * Taps must land on a hit-testable widget (no silent off-target taps)
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  Future<TestApp> boot(WidgetTester tester) async {
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
    return app;
  }

  Future<void> openOthers(WidgetTester tester, TestApp app) async {
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    app.router.go('/other');
    await tester.pumpAndSettle();
    expect(find.byType(OtherScreen), findsOneWidget);
  }

  Finder budgetEntry() => find.descendant(
    of: find.byType(OtherScreen),
    matching: find.text(LocaleKeys.budgetScreenTitle.tr()),
  );

  // * The Others page scrolls; reach the card like a user would
  Future<void> tapBudgetEntry(WidgetTester tester) async {
    await tester.ensureVisible(budgetEntry());
    await tester.pumpAndSettle();
    await tester.tap(budgetEntry());
    await tester.pumpAndSettle();
  }

  testWidgets('F8 the Others grid has a localized Budget entry that opens '
      'BudgetScreen', (tester) async {
    final app = await boot(tester);
    await openOthers(tester, app);

    expect(budgetEntry(), findsOneWidget);
    await tapBudgetEntry(tester);

    expect(find.byType(BudgetScreen), findsOneWidget);
    expect(app.router.state.uri.path, '/budget');
    // * back returns to Others (pushed, not replaced)
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(OtherScreen), findsOneWidget);
  });

  testWidgets('F8 the entry label follows the Indonesian locale', (
    tester,
  ) async {
    final app = await boot(tester);
    await openOthers(tester, app);
    final ctx = tester.element(find.byType(OtherScreen));
    await ctx.setLocale(const Locale('id', 'ID'));
    await tester.pumpAndSettle();

    expect(LocaleKeys.budgetScreenTitle.tr(), 'Anggaran');
    expect(budgetEntry(), findsOneWidget);
  });

  testWidgets('F8 create, progress and edit through the reachable screen', (
    tester,
  ) async {
    final app = await boot(tester);
    final cash = Asset(name: 'Cash', type: 0, balance: 0);
    app.storage.box<Asset>().put(cash);
    final food = Category(name: 'Groceries', type: CategoryType.expense.index);
    app.storage.box<Category>().put(food);
    app.storage.box<Transaction>().put(
      Transaction(
          amount: 50000,
          type: CategoryType.expense.index,
          transactionDate: DateTime.now(),
        )
        ..asset.target = cash
        ..category.target = food,
    );
    await openOthers(tester, app);
    await tapBudgetEntry(tester);

    // * create
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(BudgetUpsertScreen), findsOneWidget);
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(food.name).last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AppTextField),
        matching: find.byType(TextField),
      ),
      '200000',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(AppButton).first);
    await tester.tap(find.byType(AppButton).first);
    await tester.pumpAndSettle();

    // * progress: 50 000 of 200 000
    expect(find.byType(BudgetScreen), findsOneWidget);
    expect(app.storage.box<Budget>().count(), 1);
    expect(find.textContaining('25%'), findsOneWidget);

    // * edit the limit to 100 000 -> 50%
    await tester.tap(find.text(food.name).first);
    await tester.pumpAndSettle();
    expect(find.byType(BudgetUpsertScreen), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(AppTextField),
        matching: find.byType(TextField),
      ),
      '100000',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(AppButton).first);
    await tester.tap(find.byType(AppButton).first);
    await tester.pumpAndSettle();

    expect(app.storage.box<Budget>().getAll().single.amountLimit, 100000);
    expect(find.textContaining('50%'), findsOneWidget);
  });
}
