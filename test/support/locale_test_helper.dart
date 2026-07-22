import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Boots a minimal [EasyLocalization] tree so that `LocaleKeys.xxx.tr()`
/// calls made by validators (outside of any widget context) resolve
/// against the real `assets/translations/en-US.json` bundle instead of
/// throwing/returning the raw key.
Future<void> loadTestLocale(WidgetTester tester) async {
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en', 'US'), Locale('id', 'ID')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en', 'US'),
      startLocale: const Locale('en', 'US'),
      child: const MaterialApp(home: SizedBox()),
    ),
  );
  await tester.pumpAndSettle();
}
