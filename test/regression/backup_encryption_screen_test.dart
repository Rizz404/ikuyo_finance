// Regression: A14 on the real BackupScreen. Export asks for a passphrase
// (min 8, confirmed, with an unrecoverable warning) and writes an encrypted
// .ikuyo file; plaintext needs an explicit opt-out after a warning. Import of
// an encrypted file asks for the passphrase; a wrong one fails closed and the
// live DB is untouched; legacy .json still imports with a warning.
// Real ObjectBox, real BackupRepositoryImpl/BackupBloc, real router/screen;
// only the OS file picker is faked.
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/currency/currency.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/storage/storage_keys.dart';
import 'package:ikuyo_finance/features/backup/models/backup_data.dart';
import 'package:ikuyo_finance/features/backup/screens/backup_screen.dart';
import 'package:ikuyo_finance/features/backup/services/backup_crypto.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

class _FakeFilePicker extends FilePicker {
  String? nextPath;
  List<String>? lastExtensions;

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
  }) async {
    lastExtensions = allowedExtensions;
    final path = nextPath!;
    final f = File(path);
    return FilePickerResult([
      PlatformFile(
        name: path.split('/').last,
        path: path,
        size: f.lengthSync(),
      ),
    ]);
  }
}

const _pass = 'correct horse battery';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;
  late Directory dir;
  late _FakeFilePicker picker;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('ikuyo_backup_enc_');
    SharedPreferences.setMockInitialValues({
      StorageKeys.currency: 'idr',
      'cached_exchange_rates': '{"usd":1.0,"idr":16800.0,"eur":0.85}',
      'exchange_rates_timestamp': DateTime.now().millisecondsSinceEpoch,
      'export_directory': dir.path,
    });
    rootBundle.clear();
    picker = _FakeFilePicker();
    FilePicker.platform = picker;
    app = await TestApp.boot();
  });
  tearDown(() {
    app.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    app.router.push('/backup');
    await tester.pumpAndSettle();
  }

  bool shown(String text) => find.text(text).evaluate().isNotEmpty;
  bool shownKey(String key) => find.byKey(Key(key)).evaluate().isNotEmpty;

  // * KDF/IO berjalan di isolate & disk nyata: beri waktu nyata
  Future<void> settleReal(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 100));
  }

  List<File> backups() =>
      dir.listSync().whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  void seedCategory(String name) => app.storage.box<Category>().put(
    Category(name: name, type: CategoryType.expense.index),
  );

  // * settle=false: aksi memicu kerja async nyata (spinner tak pernah settle)
  Future<void> tapText(
    WidgetTester tester,
    String text, {
    bool settle = true,
  }) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.tap(find.text(text).last);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pump();
  }

  testWidgets('export asks for a confirmed passphrase and writes an '
      'encrypted .ikuyo file', (tester) async {
    seedCategory('SecretFood');
    await open(tester);

    await tapText(tester, LocaleKeys.backupScreenExportButton.tr());
    expect(
      find.text(LocaleKeys.backupEncryptionUnrecoverableWarning.tr()),
      findsOneWidget,
    );

    // too short
    await tester.enterText(
      find.byKey(const Key('backup_passphrase_field')),
      '1234567',
    );
    await tester.enterText(
      find.byKey(const Key('backup_passphrase_confirm_field')),
      '1234567',
    );
    await tester.tap(find.byKey(const Key('backup_export_encrypted')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        LocaleKeys.backupEncryptionPassphraseTooShort.tr(
          namedArgs: {'min': '8'},
        ),
      ),
      findsOneWidget,
    );

    // mismatch
    await tester.enterText(
      find.byKey(const Key('backup_passphrase_field')),
      _pass,
    );
    await tester.enterText(
      find.byKey(const Key('backup_passphrase_confirm_field')),
      '$_pass x',
    );
    await tester.tap(find.byKey(const Key('backup_export_encrypted')));
    await tester.pumpAndSettle();
    expect(
      find.text(LocaleKeys.backupEncryptionPassphraseMismatch.tr()),
      findsOneWidget,
    );
    expect(backups(), isEmpty);

    await tester.enterText(
      find.byKey(const Key('backup_passphrase_confirm_field')),
      _pass,
    );
    await tapKey(tester, 'backup_export_encrypted');
    await settleReal(tester, () => shown(LocaleKeys.backupScreenSuccess.tr()));

    final files = backups();
    expect(files, hasLength(1));
    expect(files.single.path, endsWith('.${BackupCrypto.fileExtension}'));
    final bytes = files.single.readAsBytesSync();
    expect(BackupCrypto.detect(bytes), BackupFileFormat.encrypted);
    expect(String.fromCharCodes(bytes).contains('SecretFood'), isFalse);
    final decoded = await tester.runAsync(
      () => BackupCrypto.decodeBackup(bytes, passphrase: _pass),
    );
    expect(decoded!.data.categories.map((c) => c.name), ['SecretFood']);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  }, timeout: const Timeout(Duration(seconds: 60)));

  // * F3 (device QA): instalasi baru belum punya penanda sampai CurrencyCubit
  // *   dibuat (lazy); ekspor harus tetap membawa mata uang dasar
  testWidgets('export on a fresh store without a marker yet records the '
      'resolved base currency', (tester) async {
    seedCategory('FreshFood');
    expect(CurrencyMigrationService(app.storage).readMarker(), isNull);
    await open(tester);
    await tapText(tester, LocaleKeys.backupScreenExportButton.tr());
    await tester.enterText(
      find.byKey(const Key('backup_passphrase_field')),
      _pass,
    );
    await tester.enterText(
      find.byKey(const Key('backup_passphrase_confirm_field')),
      _pass,
    );
    await tapKey(tester, 'backup_export_encrypted');
    await settleReal(tester, () => shown(LocaleKeys.backupScreenSuccess.tr()));
    final bytes = backups().single.readAsBytesSync();
    final decoded = await tester.runAsync(
      () => BackupCrypto.decodeBackup(bytes, passphrase: _pass),
    );
    expect(decoded!.data.currency?.code, 'idr');
    expect(decoded.data.currency?.decimalDigits, 0);
    expect(
      CurrencyMigrationService(app.storage).readMarker(),
      CurrencyCode.idr,
    );
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('unencrypted export requires an explicit opt-out after a '
      'warning', (tester) async {
    seedCategory('PlainFood');
    await open(tester);

    await tapText(tester, LocaleKeys.backupScreenExportButton.tr());
    await tester.tap(find.byKey(const Key('backup_export_unencrypted')));
    await tester.pumpAndSettle();
    expect(
      find.text(LocaleKeys.backupEncryptionUnencryptedWarning.tr()),
      findsOneWidget,
    );
    // backing out of the warning writes nothing
    await tapText(tester, LocaleKeys.backupEncryptionCancel.tr());
    expect(find.byKey(const Key('backup_passphrase_field')), findsOneWidget);
    await tester.tap(find.byKey(const Key('backup_export_unencrypted')));
    await tester.pumpAndSettle();
    await tapKey(tester, 'backup_unencrypted_confirm');
    await settleReal(tester, () => shown(LocaleKeys.backupScreenSuccess.tr()));

    final file = backups().single;
    expect(file.path, endsWith('.json'));
    expect(
      BackupData.fromJsonString(file.readAsStringSync()).categories.single.name,
      'PlainFood',
    );
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  }, timeout: const Timeout(Duration(seconds: 60)));

  Future<void> tapImport(WidgetTester tester) async {
    await tapText(
      tester,
      LocaleKeys.backupScreenImportButton.tr(),
      settle: false,
    );
    await settleReal(
      tester,
      () =>
          shownKey('backup_import_passphrase_field') ||
          shown(LocaleKeys.backupScreenImportConfirmTitle.tr()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pickAndImport(WidgetTester tester, String path) async {
    picker.nextPath = path;
    await tapText(tester, LocaleKeys.backupEncryptionPickerHint.tr());
    await tapImport(tester);
  }

  testWidgets('import of an encrypted backup: wrong passphrase fails closed '
      'and leaves the DB untouched; the right one restores', (tester) async {
    seedCategory('Live');
    final snapshot = BackupData(
      version: BackupData.currentVersion,
      createdAt: DateTime(2026, 2, 1),
      appName: 'Ikuyo Finance',
      currency: BackupCurrency.of(CurrencyCode.idr),
      categories: [
        CategoryBackup(
          ulid: 'c-restored',
          name: 'Restored',
          type: 1,
          createdAt: DateTime(2026, 2, 1),
          updatedAt: DateTime(2026, 2, 1),
        ),
      ],
      assets: const [],
      transactions: const [],
      budgets: const [],
    );
    // * Isolate.run nyata tidak selesai di zona fake-async: pakai runAsync
    final env = await tester.runAsync(
      () => BackupCrypto.encodeBackup(snapshot, passphrase: _pass),
    );
    final path = '${dir.path}/restore.ikuyo';
    File(path).writeAsBytesSync(env!);

    await open(tester);
    await pickAndImport(tester, path);
    expect(picker.lastExtensions, containsAll(['ikuyo', 'json']));
    expect(
      find.byKey(const Key('backup_import_passphrase_field')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('backup_import_passphrase_field')),
      'not the passphrase',
    );
    await tapKey(tester, 'backup_import_decrypt');
    await settleReal(
      tester,
      () => find
          .text(LocaleKeys.backupEncryptionWrongPassphrase.tr())
          .evaluate()
          .isNotEmpty,
    );
    expect(
      find.text(LocaleKeys.backupEncryptionWrongPassphrase.tr()),
      findsOneWidget,
    );
    expect(
      find.text(LocaleKeys.backupScreenImportConfirmTitle.tr()),
      findsNothing,
    );
    expect(app.storage.box<Category>().getAll().map((c) => c.name), ['Live']);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    await tapImport(tester);
    await tester.enterText(
      find.byKey(const Key('backup_import_passphrase_field')),
      _pass,
    );
    await tapKey(tester, 'backup_import_decrypt');
    await settleReal(
      tester,
      () => find
          .text(LocaleKeys.backupScreenImportConfirmTitle.tr())
          .evaluate()
          .isNotEmpty,
    );
    expect(find.byKey(const Key('backup_legacy_warning')), findsNothing);
    // * backup format baru membawa mata uangnya; tidak ada pilihan manual
    expect(find.byKey(const Key('backup_currency_picker')), findsNothing);
    await tapText(
      tester,
      LocaleKeys.backupScreenImportConfirmButton.tr(),
      settle: false,
    );
    await settleReal(
      tester,
      () =>
          app.storage.box<Category>().getAll().any((c) => c.name == 'Restored'),
    );
    expect(app.storage.box<Category>().getAll().map((c) => c.name), [
      'Restored',
    ]);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets(
    'legacy plaintext .json still imports, with a warning',
    (tester) async {
      seedCategory('Live');
      final legacy = BackupData(
        version: '1.0.0',
        createdAt: DateTime(2026, 2, 1),
        appName: 'Ikuyo Finance',
        categories: [
          CategoryBackup(
            ulid: 'c-old',
            name: 'OldBackup',
            type: 1,
            createdAt: DateTime(2026, 2, 1),
            updatedAt: DateTime(2026, 2, 1),
          ),
        ],
        assets: const [],
        transactions: const [],
        budgets: const [],
      );
      final path = '${dir.path}/old.json';
      File(path).writeAsStringSync(legacy.toJsonString());

      await open(tester);
      await pickAndImport(tester, path);
      await settleReal(
        tester,
        () => find
            .text(LocaleKeys.backupScreenImportConfirmTitle.tr())
            .evaluate()
            .isNotEmpty,
      );
      expect(
        find.byKey(const Key('backup_import_passphrase_field')),
        findsNothing,
      );
      expect(find.byKey(const Key('backup_legacy_warning')), findsOneWidget);
      // * F3: backup lama tanpa mata uang; tidak ditebak dari DB tujuan
      expect(
        find.text(LocaleKeys.backupScreenCurrencyLegacyWarning.tr()),
        findsOneWidget,
      );
      expect(find.byKey(const Key('backup_currency_picker')), findsOneWidget);
      final confirm = find.widgetWithText(
        FilledButton,
        LocaleKeys.backupScreenImportConfirmButton.tr(),
      );
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.tap(find.byKey(const Key('backup_currency_picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('USD').last);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
      await tapText(
        tester,
        LocaleKeys.backupScreenImportConfirmButton.tr(),
        settle: false,
      );
      await settleReal(
        tester,
        () => app.storage.box<Category>().getAll().any(
          (c) => c.name == 'OldBackup',
        ),
      );
      expect(app.storage.box<Category>().getAll().map((c) => c.name), [
        'OldBackup',
      ]);
      // * Penanda ditulis bersama data; cubit diselaraskan setelah commit
      expect(
        CurrencyMigrationService(app.storage).readMarker(),
        CurrencyCode.usd,
      );
      await tester.pump();
      expect(
        tester
            .element(find.byType(MaterialApp))
            .read<CurrencyCubit>()
            .state
            .currentCurrency,
        CurrencyCode.usd,
      );
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets('a backup with unsupported currency metadata is refused '
      'before the confirm step and the DB is untouched', (tester) async {
    seedCategory('Live');
    final bad = BackupData(
      version: BackupData.currentVersion,
      createdAt: DateTime(2026, 2, 1),
      appName: 'Ikuyo Finance',
      currency: const BackupCurrency(code: 'idr', decimalDigits: 2),
      categories: const [],
      assets: const [],
      transactions: const [],
      budgets: const [],
    );
    final path = '${dir.path}/bad.json';
    File(path).writeAsStringSync(bad.toJsonString());
    await open(tester);
    picker.nextPath = path;
    await tapText(tester, LocaleKeys.backupEncryptionPickerHint.tr());
    await tapText(
      tester,
      LocaleKeys.backupScreenImportButton.tr(),
      settle: false,
    );
    final message = LocaleKeys.backupScreenCurrencyUnsupported.tr(
      namedArgs: {'code': 'idr'},
    );
    await settleReal(tester, () => shown(message));
    expect(find.text(message), findsOneWidget);
    expect(
      find.text(LocaleKeys.backupScreenImportConfirmTitle.tr()),
      findsNothing,
    );
    expect(app.storage.box<Category>().getAll().map((c) => c.name), ['Live']);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  }, timeout: const Timeout(Duration(seconds: 60)));

  // * F2: batas 32 MiB ditegakkan sebelum file dibaca
  testWidgets('an import file over 32 MiB is refused before it is read, '
      'with a localized message, and the DB is untouched', (tester) async {
    seedCategory('Live');
    final path = '${dir.path}/huge.ikuyo';
    // sparse file: real length check without writing 32 MiB of data
    final raf = File(path).openSync(mode: FileMode.write);
    raf.truncateSync(BackupCrypto.maxBackupBytes + 1);
    raf.closeSync();

    var lengthCalls = 0;
    var openCalls = 0;
    final original = BackupScreen.importFileReader;
    BackupScreen.importFileReader = (p) {
      final f = File(p);
      return BackupCrypto.readBounded(
        length: () {
          lengthCalls++;
          return f.length();
        },
        openRead: () {
          openCalls++;
          return f.openRead();
        },
      );
    };
    addTearDown(() => BackupScreen.importFileReader = original);

    await open(tester);
    picker.nextPath = path;
    await tapText(tester, LocaleKeys.backupEncryptionPickerHint.tr());
    await tapText(
      tester,
      LocaleKeys.backupScreenImportButton.tr(),
      settle: false,
    );
    final message = LocaleKeys.backupEncryptionTooLarge.tr(
      namedArgs: {'max': '32'},
    );
    await settleReal(tester, () => shown(message));
    expect(find.text(message), findsOneWidget);
    expect(lengthCalls, 1);
    expect(openCalls, 0, reason: 'oversized file must not be opened');
    expect(
      find.byKey(const Key('backup_import_passphrase_field')),
      findsNothing,
    );
    expect(
      find.text(LocaleKeys.backupScreenImportConfirmTitle.tr()),
      findsNothing,
    );
    expect(app.storage.box<Category>().getAll().map((c) => c.name), ['Live']);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('the default import reader uses the bounded reader on the real '
      'file', (tester) async {
    final path = '${dir.path}/huge.json';
    final raf = File(path).openSync(mode: FileMode.write);
    raf.truncateSync(BackupCrypto.maxBackupBytes + 1);
    raf.closeSync();
    Object? error;
    await tester.runAsync(() async {
      try {
        await BackupScreen.importFileReader(path);
      } catch (e) {
        error = e;
      }
    });
    expect(error, isA<BackupCryptoException>());
    expect((error! as BackupCryptoException).error, BackupCryptoError.tooLarge);
  });

  test('size-limit messages are localized in en-US and id-ID', () {
    for (final locale in ['en-US', 'id-ID']) {
      final json =
          jsonDecode(
                File('assets/translations/$locale.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final enc =
          (json['backup'] as Map<String, dynamic>)['encryption']
              as Map<String, dynamic>;
      for (final key in ['tooLarge', 'exportTooLarge']) {
        expect(enc[key], isA<String>(), reason: '$locale $key');
        expect(enc[key] as String, contains('{max}'), reason: '$locale $key');
      }
      final screen =
          (json['backup'] as Map<String, dynamic>)['screen']
              as Map<String, dynamic>;
      for (final key in [
        'currencyMissing',
        'currencyUnsupported',
        'currencyLegacyWarning',
        'currencyPickLabel',
      ]) {
        expect(screen[key], isA<String>(), reason: '$locale $key');
      }
      expect(screen['currencyUnsupported'] as String, contains('{code}'));
    }
    expect(
      LocaleKeys.backupEncryptionExportTooLarge,
      'backup.encryption.exportTooLarge',
    );
  });
}
