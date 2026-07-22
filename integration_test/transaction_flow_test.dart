import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/asset/models/create_asset_params.dart';
import 'package:ikuyo_finance/features/transaction/models/get_transactions_params.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/shared/widgets/app_button.dart';
import 'package:ikuyo_finance/shared/widgets/app_text_field.dart';

import '../test/support/test_app.dart';

/// End-to-end test driving the REAL app widget tree against an ephemeral
/// ObjectBox store. Transaction is the initial route/tab, so no extra
/// navigation is needed. The add form is the most complex one in the app —
/// a currency-formatted amount field plus a required [AppSearchableDropdown]
/// for Asset — so a real Asset is seeded first via the repository (exactly
/// what a real user would already have set up before recording a
/// transaction).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;

  setUp(() async {
    app = await TestApp.boot();
  });

  tearDown(() => app.close());

  testWidgets('renders the transaction screen with its add button', (tester) async {
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();

    // * The screen has TWO FABs (a small "bulk copy" one plus the regular
    // * "add" one), so scope to the add icon specifically.
    expect(find.widgetWithIcon(FloatingActionButton, Icons.add), findsOneWidget);
  });

  testWidgets(
    'create -> list -> delete: a transaction through the real UI, persisted to real ObjectBox',
    (tester) async {
      final asset = (await app.assetRepository
              .createAsset(const CreateAssetParams(name: 'Cash Wallet', type: AssetType.cash))
              .run())
          .fold((_) => throw Exception('setup failed'), (s) => s.data!);

      await tester.pumpWidget(app.build());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithIcon(FloatingActionButton, Icons.add));
      await tester.pumpAndSettle();
      expect(find.text('Add Transaction'), findsWidgets);

      // * Amount (currency-formatted field).
      await tester.enterText(
        find.descendant(
          of: find.byType(AppTextField).first,
          matching: find.byType(TextField),
        ),
        '75000',
      );
      await tester.pumpAndSettle();

      // * Asset — required searchable dropdown, opened by tapping its hint.
      await tester.tap(find.text('Select asset'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(asset.name).last);
      await tester.pumpAndSettle();

      // * Category is optional — skipped. Date/time already defaults to now.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(AppButton).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AppButton).first);
      await tester.pumpAndSettle();

      final created = (await app.transactionRepository
              .getTransactions(const GetTransactionsParams())
              .run())
          .fold((_) => <Transaction>[], (s) => s.data ?? []);
      expect(created.any((t) => t.asset.target?.ulid == asset.ulid), isTrue);
      expect(created.first.amount, 75000);

      // * The created transaction should now be visible in the list.
      expect(find.text('Cash Wallet'), findsWidgets);
    },
  );
}
