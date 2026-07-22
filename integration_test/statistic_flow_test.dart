import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/asset/models/create_asset_params.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/category/models/create_category_params.dart';
import 'package:ikuyo_finance/features/transaction/models/create_transaction_params.dart';

import '../test/support/test_app.dart';

/// End-to-end test driving the REAL app widget tree against an ephemeral
/// ObjectBox store. StatisticScreen has no create form of its own — it's a
/// read-only aggregation view over real transactions (self-dispatches
/// `StatisticFetched` in `initState` for the current-month period by
/// default) — so this flow seeds data directly via the real repositories
/// (exactly what a user's transaction history would already contain) and
/// verifies the real screen renders the real aggregation correctly.
///
/// The screen's body is a `CustomScrollView` with the chart section above
/// `CategorySummaryList`; the chart is tall enough that the category list's
/// `SliverToBoxAdapter` sits outside the initial viewport + cache extent,
/// so it isn't actually built until scrolled into view — confirmed by
/// direct widget-tree inspection during development. `find.text(...)` only
/// searches the built element tree, so this flow scrolls down before
/// asserting on category-list content.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;

  setUp(() async {
    app = await TestApp.boot();
  });

  tearDown(() => app.close());

  Future<void> goToStatisticScreen(WidgetTester tester) async {
    await tester.tap(find.text('Statistics'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows a zero-category summary when there is no transaction data', (tester) async {
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();

    await goToStatisticScreen(tester);

    // * CategorySummaryList itself renders nothing when empty (SizedBox.shrink) —
    // * the "0 categories • 0 transactions" count line in the summary card
    // * (above the fold, no scrolling needed) is the real observable signal.
    expect(find.textContaining('0 categories'), findsOneWidget);
  });

  testWidgets(
    'aggregates real transactions by category for the current month',
    (tester) async {
      final asset = (await app.assetRepository
              .createAsset(const CreateAssetParams(name: 'Cash', type: AssetType.cash))
              .run())
          .fold((_) => throw Exception('setup failed'), (s) => s.data!);
      final category = (await app.categoryRepository
              .createCategory(
                const CreateCategoryParams(name: 'Dining', type: CategoryType.expense),
              )
              .run())
          .fold((_) => throw Exception('setup failed'), (s) => s.data!);
      await app.transactionRepository
          .createTransaction(
            CreateTransactionParams(
              assetUlid: asset.ulid,
              categoryUlid: category.ulid,
              amount: 75000,
              transactionDate: DateTime.now(),
            ),
          )
          .run();

      await tester.pumpWidget(app.build());
      await tester.pumpAndSettle();
      await goToStatisticScreen(tester);

      // * Summary card is above the fold — visible without scrolling.
      expect(find.textContaining('1 categories'), findsOneWidget);

      // * Scroll past the chart to build+reveal CategorySummaryList's sliver.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('Dining'), findsOneWidget);
    },
  );
}
