import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/budget/models/get_budgets_params.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/category/models/create_category_params.dart';
import 'package:ikuyo_finance/shared/widgets/app_button.dart';
import 'package:ikuyo_finance/shared/widgets/app_text_field.dart';

import '../test/support/test_app.dart';

/// End-to-end test driving the REAL app widget tree against an ephemeral
/// ObjectBox store. Unlike category/asset, the Budget list screen has no
/// delete affordance of its own (no long-press batch-delete sheet) — budget
/// deletion lives inside the edit screen, out of scope for this flow. This
/// test instead exercises what's unique to budget: a non-searchable
/// [AppDropdown] fed by the real [CategoryBloc], and the cross-entity
/// dependency (a budget cannot exist without a category).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;

  setUp(() async {
    app = await TestApp.boot();
  });

  tearDown(() => app.close());

  Future<void> goToBudgetScreen(WidgetTester tester) async {
    app.router.go('/budget');
    await tester.pumpAndSettle();
  }

  testWidgets('shows the empty state when there is no data', (tester) async {
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();

    await goToBudgetScreen(tester);

    expect(find.text('No budgets yet'), findsOneWidget);
  });

  testWidgets(
    'create a budget through the real UI (category dropdown + amount), persisted to real ObjectBox',
    (tester) async {
      final category = (await app.categoryRepository
              .createCategory(
                const CreateCategoryParams(name: 'Groceries', type: CategoryType.expense),
              )
              .run())
          .fold((_) => throw Exception('setup failed'), (s) => s.data!);

      await tester.pumpWidget(app.build());
      await tester.pumpAndSettle();
      await goToBudgetScreen(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('Add Budget'), findsWidgets);

      // * Open the category dropdown and select the seeded category. It's a
      // * standard FormBuilderDropdown/DropdownButtonFormField, so the item
      // * text appears twice once opened (closed-field vs menu) — use .last
      // * for the menu entry.
      await tester.tap(find.text('Select category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(category.name).last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.descendant(
          of: find.byType(AppTextField),
          matching: find.byType(TextField),
        ),
        '500000',
      );
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(AppButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      // * Back on the list, the budget's category name should be visible...
      expect(find.text(category.name), findsWidgets);
      // * ...and it must actually be in the database.
      final created = (await app.budgetRepository
              .getBudgets(const GetBudgetsParams())
              .run())
          .fold((_) => <Budget>[], (s) => s.data ?? []);
      expect(created.any((b) => b.category.target?.ulid == category.ulid), isTrue);
      expect(created.first.amountLimit, 500000);
    },
  );
}
