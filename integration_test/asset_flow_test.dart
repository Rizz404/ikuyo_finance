import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/asset/models/get_assets_params.dart';
import 'package:ikuyo_finance/shared/widgets/app_button.dart';
import 'package:ikuyo_finance/shared/widgets/app_text_field.dart';

import '../test/support/test_app.dart';

/// End-to-end test driving the REAL app widget tree against an ephemeral
/// ObjectBox store. The Assets tab is a direct bottom-nav branch, so no
/// extra navigation is needed to reach it. See [TestApp] for what's real
/// vs. mocked.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;

  setUp(() async {
    app = await TestApp.boot();
  });

  tearDown(() => app.close());

  Future<void> goToAssetScreen(WidgetTester tester) async {
    await tester.tap(find.text(LocaleKeys.sharedWidgetsUserShellAssets.tr()));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the empty state when there is no data', (tester) async {
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();

    await goToAssetScreen(tester);

    expect(find.text(LocaleKeys.assetScreenEmptyTitle.tr()), findsOneWidget);
  });

  testWidgets(
    'create -> list -> delete: an asset through the real UI, persisted to real ObjectBox',
    (tester) async {
      await tester.pumpWidget(app.build());
      await tester.pumpAndSettle();
      await goToAssetScreen(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text(LocaleKeys.assetUpsertAddTitle.tr()), findsWidgets);

      // * Name field (type defaults to Cash, balance defaults to 0). The
      // * first AppTextField on this screen is 'name', the second 'balance'.
      await tester.enterText(
        find.descendant(
          of: find.byType(AppTextField).first,
          matching: find.byType(TextField),
        ),
        'BCA Savings',
      );
      await tester.pumpAndSettle();
      // * Close the on-screen keyboard first — its own native show/hide
      // * animation isn't tracked by pumpAndSettle() and can otherwise
      // * leave the submit button off-screen.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(AppButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      expect(find.text('BCA Savings'), findsOneWidget);
      final created = (await app.assetRepository
              .getAssets(const GetAssetsParams())
              .run())
          .fold((_) => <Asset>[], (s) => s.data ?? []);
      expect(created.any((a) => a.name == 'BCA Savings'), isTrue);

      await tester.longPress(find.text('BCA Savings'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(AppButton).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AppButton).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('batch-delete-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('BCA Savings'), findsNothing);
      final remaining = (await app.assetRepository
              .getAssets(const GetAssetsParams())
              .run())
          .fold((_) => <Asset>[], (s) => s.data ?? []);
      expect(remaining.any((a) => a.name == 'BCA Savings'), isFalse);
    },
  );
}
