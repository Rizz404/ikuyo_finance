import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
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

/// Loads a real `assets/translations/<tag>.json` bundle into the global
/// localization instance for plain (non-widget) tests, so `.tr()` calls in
/// models resolve to the shipped strings instead of echoing the raw key.
void loadAssetTranslations(String tag) {
  final json = File('assets/translations/$tag.json').readAsStringSync();
  final parts = tag.split('-');
  Localization.load(
    Locale(parts[0], parts.length > 1 ? parts[1] : null),
    translations: Translations(jsonDecode(json) as Map<String, dynamic>),
  );
}
