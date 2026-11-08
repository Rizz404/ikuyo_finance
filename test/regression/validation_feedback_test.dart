// Regression: A19. After a failed submit, a field error must clear as soon as
// the user corrects the field. It must not linger until the next submit.
// Real app (TestApp: real ObjectBox, repositories, blocs, router, screens).
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/storage/storage_keys.dart';
import 'package:ikuyo_finance/shared/widgets/app_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.currency: 'idr',
      'cached_exchange_rates': '{"usd":1.0,"idr":16800.0,"eur":0.85}',
      'exchange_rates_timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    rootBundle.clear();
    app = await TestApp.boot();
  });
  tearDown(() => app.close());

  testWidgets('A19 asset name error clears once the name is fixed',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    app.router.go('/asset');
    await tester.pumpAndSettle();
    app.router.push('/asset/add');
    await tester.pumpAndSettle();

    final submit = find.byType(AppButton).first;
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    final required = LocaleKeys.assetValidatorNameRequired.tr();
    expect(find.text(required), findsOneWidget);

    final nameField = find.byWidgetPredicate(
      (w) => w is FormBuilderTextField && w.name == 'name',
    );
    await tester.enterText(
      find.descendant(of: nameField, matching: find.byType(TextField)),
      'Wallet',
    );
    await tester.pumpAndSettle();

    expect(find.text(required), findsNothing);
  });
}
