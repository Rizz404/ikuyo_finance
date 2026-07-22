import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/category/models/create_category_params.dart';
import 'package:ikuyo_finance/features/category/models/get_categories_params.dart';
import 'package:ikuyo_finance/shared/widgets/app_button.dart';
import 'package:ikuyo_finance/shared/widgets/app_text_field.dart';

import '../test/support/test_app.dart';

/// End-to-end test driving the REAL app widget tree — real [GoRouter] with
/// every route, real blocs, real repositories — against an ephemeral
/// ObjectBox store. See [TestApp] for exactly what's real vs. mocked.
///
/// Category management lives off the "Others" bottom-nav tab, behind a
/// "Manage Categories" card (`lib/features/other/screens/other_screen.dart`).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;

  setUp(() async {
    app = await TestApp.boot();
  });

  tearDown(() => app.close());

  Future<void> goToCategoryScreen(WidgetTester tester) async {
    await tester.tap(find.text('Others'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage Categories'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the empty state when there is no data', (tester) async {
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();

    await goToCategoryScreen(tester);

    expect(find.text('No categories yet'), findsOneWidget);
  });

  testWidgets(
    'create -> list -> delete: a category through the real UI, persisted to real ObjectBox',
    (tester) async {
      await tester.pumpWidget(app.build());
      await tester.pumpAndSettle();
      await goToCategoryScreen(tester);

      // * Tap the FAB to open the add-category screen.
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('Add Category'), findsWidgets);

      // * Fill in the name (type already defaults to Expense). The parent
      // * category dropdown also contains a hidden search TextField, so
      // * scope the finder to the one AppTextField on this screen (name).
      await tester.enterText(
        find.descendant(
          of: find.byType(AppTextField),
          matching: find.byType(TextField),
        ),
        'Groceries',
      );
      await tester.pumpAndSettle();
      // * Close the on-screen keyboard before interacting with anything
      // * else — on a real device it can otherwise stay up long enough to
      // * shrink the viewport and push the submit button off-screen, even
      // * after pumpAndSettle() (the keyboard's own show/hide animation
      // * isn't tracked by Flutter's frame scheduler).
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(AppButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      // * Back on the list, the new category should be visible...
      expect(find.text('Groceries'), findsOneWidget);
      // * ...and it must actually be in the database, not just in memory.
      final created = (await app.categoryRepository
              .getCategories(const GetCategoriesParams())
              .run())
          .fold((_) => <Category>[], (s) => s.data ?? []);
      expect(created.any((c) => c.name == 'Groceries'), isTrue);

      // * Long-press to open the batch-delete sheet, then delete it.
      await tester.longPress(find.text('Groceries'));
      await tester.pumpAndSettle();
      // * The delete trigger button inside the sheet.
      await tester.ensureVisible(find.byType(AppButton).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AppButton).last);
      await tester.pumpAndSettle();
      // * Confirm the "Hapus item?" dialog.
      await tester.tap(find.text('Hapus').last);
      await tester.pumpAndSettle();

      expect(find.text('Groceries'), findsNothing);
      final remaining = (await app.categoryRepository
              .getCategories(const GetCategoriesParams())
              .run())
          .fold((_) => <Category>[], (s) => s.data ?? []);
      expect(remaining.any((c) => c.name == 'Groceries'), isFalse);
    },
  );

  testWidgets('switching to the Expense tab filters out income categories', (tester) async {
    await app.categoryRepository
        .createCategory(
          const CreateCategoryParams(name: 'Salary', type: CategoryType.income),
        )
        .run();
    await app.categoryRepository
        .createCategory(
          const CreateCategoryParams(name: 'Rent', type: CategoryType.expense),
        )
        .run();

    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await goToCategoryScreen(tester);

    // * "Expense" also appears as a per-card type label, so scope the tap
    // * to the TabBar itself.
    await tester.tap(
      find.descendant(of: find.byType(TabBar), matching: find.text('Expense')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('Salary'), findsNothing);
  });
}
