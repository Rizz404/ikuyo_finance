// Regression: CSE-4 / CSE-6. Cancelling the export date picker must keep the
// chosen date, and reopening the Export screen must not replay the toast of an
// earlier export (ExportBloc is app-wide).
// Real ObjectBox, real ExportRepositoryImpl/ExportBloc, real router/screen.
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/storage/storage_keys.dart';
import 'package:ikuyo_finance/features/export/bloc/export_bloc.dart';
import 'package:ikuyo_finance/features/export/models/export_params.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;
  late Directory exportDir;

  setUp(() async {
    exportDir = Directory.systemTemp.createTempSync('ikuyo_export_screen_');
    SharedPreferences.setMockInitialValues({
      StorageKeys.currency: 'idr',
      'cached_exchange_rates': '{"usd":1.0,"idr":16800.0,"eur":0.85}',
      'exchange_rates_timestamp': DateTime.now().millisecondsSinceEpoch,
      'export_excel_directory': exportDir.path,
    });
    rootBundle.clear();
    app = await TestApp.boot();
  });
  tearDown(() async {
    app.close();
    if (exportDir.existsSync()) exportDir.deleteSync(recursive: true);
  });

  Future<void> start(WidgetTester tester) async {
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
  }

  testWidgets('CSE-4 cancelling the date picker keeps the selected date',
      (tester) async {
    await start(tester);
    app.router.push('/export');
    await tester.pumpAndSettle();

    Finder dialogButtons() => find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.byType(TextButton),
        );

    await tester.tap(find.text(LocaleKeys.exportScreenStartDate.tr()));
    await tester.pumpAndSettle();
    await tester.tap(dialogButtons().last); // OK -> today
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.clear), findsOneWidget);

    await tester.tap(find.byIcon(Icons.calendar_today_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(dialogButtons().first); // Cancel
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.clear), findsOneWidget);
    expect(find.text(LocaleKeys.exportScreenStartDate.tr()), findsNothing);
  });

  testWidgets('CSE-6 reopening Export does not replay the previous result toast',
      (tester) async {
    await start(tester);
    final bloc = tester.element(find.byType(Navigator).first).read<ExportBloc>();

    bloc.add(
      ExportExcelRequested(
        params: const ExportParams(),
        exportDirectory: exportDir.path,
        labels: const {},
        currencySymbol: 'Rp',
      ),
    );
    // * File I/O nyata: beri waktu nyata sampai export selesai
    for (var i = 0; i < 100 && bloc.state.status == ExportStatus.loading ||
        bloc.state.status == ExportStatus.initial; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(bloc.state.status, ExportStatus.success, reason: bloc.state.message);
    await tester.pumpAndSettle();

    // * Toast auto-close 4 dtk: biarkan toast export pertama hilang dulu
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text(LocaleKeys.exportScreenExportSuccess.tr()), findsNothing);

    app.router.push('/export');
    // * Jangan pumpAndSettle: toast yang salah akan auto-close dalam 4 dtk
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text(LocaleKeys.exportScreenExportSuccess.tr()), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  }, timeout: const Timeout(Duration(seconds: 60)));
}
