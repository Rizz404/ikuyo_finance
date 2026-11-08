// Regression: SHARED-7 / SHARED-8. AppFilePicker must enforce maxFiles across
// repeated picks, must not setState after it is disposed mid-pick and must
// not mutate the caller's initialFiles list. AppSearchField must not setState
// after dispose while a debounce or search is pending.
// The real widgets are used; only the OS file-picker plugin is faked.
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/core/theme/app_theme.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';
import 'package:ikuyo_finance/shared/widgets/app_file_picker.dart';
import 'package:ikuyo_finance/shared/widgets/app_search_field.dart';

import '../support/test_logger.dart';

class _FakeFilePicker extends FilePicker {
  final List<Completer<FilePickerResult?>> calls = [];

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) {
    final c = Completer<FilePickerResult?>();
    calls.add(c);
    return c.future;
  }
}

PlatformFile _file(String name) =>
    PlatformFile(name: name, size: 10, path: '/tmp/$name');

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: FormBuilder(child: child)),
    );

void main() {
  setUpAll(bootstrapTestLogger);

  late _FakeFilePicker picker;
  setUp(() {
    picker = _FakeFilePicker();
    FilePicker.platform = picker;
    talker.cleanHistory();
  });

  bool loggedPickError() => talker.history
      .any((e) => (e.message ?? '').contains('Error picking files'));

  testWidgets('SHARED-7 maxFiles is enforced across repeated picks',
      (tester) async {
    final picked = <List<PlatformFile>?>[];
    await tester.pumpWidget(_host(AppFilePicker(
      name: 'files',
      allowMultiple: true,
      maxFiles: 2,
      onChanged: picked.add,
    )));

    await tester.tap(find.byIcon(Icons.upload_file_outlined));
    picker.calls.last.complete(FilePickerResult([_file('a.pdf'), _file('b.pdf')]));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.upload_file_outlined));
    picker.calls.last.complete(FilePickerResult([_file('c.pdf')]));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.text('a.pdf'), findsOneWidget);
    expect(find.text('b.pdf'), findsOneWidget);
    expect(find.text('c.pdf'), findsNothing);
    expect(picked.last, hasLength(2));
  });

  testWidgets('SHARED-7 a pick completing after dispose does not setState',
      (tester) async {
    await tester.pumpWidget(_host(const AppFilePicker(name: 'files')));
    await tester.tap(find.byIcon(Icons.upload_file_outlined));
    await tester.pumpWidget(_host(const SizedBox()));

    picker.calls.last.complete(FilePickerResult([_file('a.pdf')]));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(loggedPickError(), isFalse);
  });

  testWidgets('SHARED-7 removing a file does not mutate initialFiles',
      (tester) async {
    final initial = List<PlatformFile>.unmodifiable([_file('a.pdf')]);
    await tester.pumpWidget(_host(AppFilePicker(
      name: 'files',
      initialFiles: initial,
    )));

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('a.pdf'), findsNothing);
    expect(initial, hasLength(1));
  });

  testWidgets('SHARED-8 search completing after dispose does not setState',
      (tester) async {
    final pending = Completer<List<String>>();
    var searchStarted = false;
    await tester.pumpWidget(_host(AppSearchField<String>(
      name: 'q',
      enableAutocomplete: true,
      onSearch: (_) {
        searchStarted = true;
        return pending.future;
      },
      itemDisplayMapper: (s) => s,
      itemValueMapper: (s) => s,
    )));

    await tester.enterText(find.byType(TextField), 'abc');
    // * Debounce membandingkan jam dinding: tunggu waktu nyata
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 350)),
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(searchStarted, isTrue);
    await tester.pumpWidget(_host(const SizedBox()));
    pending.complete(['abc']);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('SHARED-8 a debounce pending at dispose does not search',
      (tester) async {
    var searches = 0;
    await tester.pumpWidget(_host(AppSearchField<String>(
      name: 'q',
      enableAutocomplete: true,
      onSearch: (_) async {
        searches++;
        return const [];
      },
      itemDisplayMapper: (s) => s,
      itemValueMapper: (s) => s,
    )));

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pumpWidget(_host(const SizedBox()));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 350)),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(searches, 0);
  });
}
