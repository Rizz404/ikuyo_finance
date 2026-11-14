// Regression: F10 on the real BackupScreen. Turning auto backup on opens
// the backup passphrase setup dialog (min 8, confirmed, unrecoverable /
// change warning); cancelling leaves it off and nothing is scheduled. A
// schedule already enabled without a usable key (upgrade, reinstall, key
// unreadable) shows a persistent paused banner with a setup action.
// Real router/screen/bloc; only the AutoBackupService platform boundary is
// mocked so no Argon2/WorkManager/keystore runs here.
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/backup/bloc/backup_bloc.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/storage/storage_keys.dart';
import 'package:ikuyo_finance/features/backup/models/backup_schedule_settings.dart';
import 'package:ikuyo_finance/features/backup/services/auto_backup_key_store.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

const _pass = 'synthetic setup phrase';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;
  late Directory dir;

  setUpAll(() {
    registerFallbackValue(const BackupScheduleSettings());
  });

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('ikuyo_f10_ui_');
    SharedPreferences.setMockInitialValues({
      StorageKeys.currency: 'idr',
      'cached_exchange_rates': '{"usd":1.0,"idr":16800.0,"eur":0.85}',
      'exchange_rates_timestamp': DateTime.now().millisecondsSinceEpoch,
      'export_directory': dir.path,
    });
    rootBundle.clear();
    app = await TestApp.boot();
  });
  tearDown(() {
    app.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  MockAutoBackupService serviceWith({
    required BackupScheduleSettings settings,
    required AutoBackupKeyState keyState,
  }) {
    final s = MockAutoBackupService();
    var current = settings;
    var key = keyState;
    when(() => s.loadSettings()).thenAnswer((_) => current);
    when(() => s.keyState()).thenAnswer((_) async => key);
    when(() => s.saveSettings(any())).thenAnswer((i) async {
      current = i.positionalArguments.first as BackupScheduleSettings;
    });
    when(() => s.schedule(any(), keepExisting: any(named: 'keepExisting')))
        .thenAnswer((_) async {});
    when(() => s.schedule(any())).thenAnswer((_) async {});
    when(() => s.setupKey(any())).thenAnswer((_) async {
      key = AutoBackupKeyState.ready;
    });
    when(() => s.clearKey()).thenAnswer((_) async {
      key = AutoBackupKeyState.missing;
    });
    return s;
  }

  Future<void> open(WidgetTester tester, MockAutoBackupService service) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app.build(autoBackupServiceOverride: service));
    await tester.pumpAndSettle();
    app.router.push('/backup');
    await tester.pumpAndSettle();
  }

  Switch autoSwitch(WidgetTester tester) =>
      tester.widget<Switch>(find.byKey(const Key('auto_backup_switch')));

  testWidgets('turning auto backup on requires a confirmed passphrase; '
      'cancel leaves it off', (tester) async {
    final service = serviceWith(
      settings: const BackupScheduleSettings(),
      keyState: AutoBackupKeyState.missing,
    );
    await open(tester, service);
    expect(find.byKey(const Key('auto_backup_paused_banner')), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('auto_backup_switch')));
    await tester.tap(find.byKey(const Key('auto_backup_switch')));
    await tester.pumpAndSettle();
    expect(find.text(LocaleKeys.backupAutoSetupTitle.tr()), findsOneWidget);
    expect(find.text(LocaleKeys.backupAutoSetupWarning.tr()), findsOneWidget);
    // * tidak ada jalan pintas tanpa enkripsi di dialog auto backup
    expect(find.byKey(const Key('backup_export_unencrypted')), findsNothing);

    await tester.tap(find.byKey(const Key('auto_backup_passphrase_cancel')));
    await tester.pumpAndSettle();
    expect(autoSwitch(tester).value, isFalse);
    verifyNever(() => service.setupKey(any()));
    verifyNever(() => service.schedule(any()));

    await tester.tap(find.byKey(const Key('auto_backup_switch')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('auto_backup_passphrase_field')),
      '1234567',
    );
    await tester.enterText(
      find.byKey(const Key('auto_backup_passphrase_confirm_field')),
      '1234567',
    );
    await tester.tap(find.byKey(const Key('auto_backup_passphrase_save')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        LocaleKeys.backupEncryptionPassphraseTooShort.tr(
          namedArgs: {'min': '8'},
        ),
      ),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('auto_backup_passphrase_field')),
      _pass,
    );
    await tester.enterText(
      find.byKey(const Key('auto_backup_passphrase_confirm_field')),
      '$_pass x',
    );
    await tester.tap(find.byKey(const Key('auto_backup_passphrase_save')));
    await tester.pumpAndSettle();
    expect(
      find.text(LocaleKeys.backupEncryptionPassphraseMismatch.tr()),
      findsOneWidget,
    );
    verifyNever(() => service.setupKey(any()));

    await tester.enterText(
      find.byKey(const Key('auto_backup_passphrase_confirm_field')),
      _pass,
    );
    await tester.tap(find.byKey(const Key('auto_backup_passphrase_save')));
    await tester.pumpAndSettle();

    verify(() => service.setupKey(_pass)).called(1);
    verify(() => service.schedule(any())).called(1);
    expect(autoSwitch(tester).value, isTrue);
    expect(find.byKey(const Key('auto_backup_paused_banner')), findsNothing);
    expect(find.text(LocaleKeys.backupAutoLegacyNote.tr()), findsOneWidget);
    expect(find.text(LocaleKeys.backupAutoChangeButton.tr()), findsOneWidget);
  });

  testWidgets('upgrade with the schedule on and no key shows a persistent '
      'paused prompt; setting the passphrase resumes', (tester) async {
    final service = serviceWith(
      settings: const BackupScheduleSettings(isEnabled: true),
      keyState: AutoBackupKeyState.missing,
    );
    await open(tester, service);

    expect(find.byKey(const Key('auto_backup_paused_banner')), findsOneWidget);
    expect(find.text(LocaleKeys.backupAutoPausedMissing.tr()), findsOneWidget);
    expect(autoSwitch(tester).value, isTrue);

    await tester.ensureVisible(find.byKey(const Key('auto_backup_key_setup')));
    await tester.tap(find.byKey(const Key('auto_backup_key_setup')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('auto_backup_passphrase_field')),
      _pass,
    );
    await tester.enterText(
      find.byKey(const Key('auto_backup_passphrase_confirm_field')),
      _pass,
    );
    await tester.tap(find.byKey(const Key('auto_backup_passphrase_save')));
    await tester.pumpAndSettle();

    verify(() => service.setupKey(_pass)).called(1);
    expect(find.byKey(const Key('auto_backup_paused_banner')), findsNothing);
    expect(autoSwitch(tester).value, isTrue);
  });

  testWidgets('an unreadable key shows the reinstall/restore explanation',
      (tester) async {
    final service = serviceWith(
      settings: const BackupScheduleSettings(isEnabled: true),
      keyState: AutoBackupKeyState.unreadable,
    );
    await open(tester, service);
    expect(
      find.text(LocaleKeys.backupAutoPausedUnreadable.tr()),
      findsOneWidget,
    );
  });

  testWidgets('a key setup failure keeps auto backup off and shows a '
      'localized error', (tester) async {
    final service = serviceWith(
      settings: const BackupScheduleSettings(),
      keyState: AutoBackupKeyState.missing,
    );
    when(() => service.setupKey(any()))
        .thenThrow(const AutoBackupKeyException('write'));
    await open(tester, service);
    await tester.ensureVisible(find.byKey(const Key('auto_backup_switch')));
    await tester.tap(find.byKey(const Key('auto_backup_switch')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('auto_backup_passphrase_field')),
      _pass,
    );
    await tester.enterText(
      find.byKey(const Key('auto_backup_passphrase_confirm_field')),
      _pass,
    );
    await tester.tap(find.byKey(const Key('auto_backup_passphrase_save')));
    await tester.pumpAndSettle();
    final bloc = tester
        .element(find.byKey(const Key('auto_backup_switch')))
        .read<BackupBloc>();
    expect(bloc.state.status, BackupStatus.failure);
    expect(bloc.state.message, LocaleKeys.backupAutoKeySetupFailed.tr());
    expect(bloc.state.autoKeyBusy, isFalse);
    expect(autoSwitch(tester).value, isFalse);
    verifyNever(() => service.schedule(any()));
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('turning auto backup off cancels and clears the key',
      (tester) async {
    final service = serviceWith(
      settings: const BackupScheduleSettings(isEnabled: true),
      keyState: AutoBackupKeyState.ready,
    );
    await open(tester, service);
    await tester.ensureVisible(find.byKey(const Key('auto_backup_switch')));
    await tester.tap(find.byKey(const Key('auto_backup_switch')));
    await tester.pumpAndSettle();
    expect(find.text(LocaleKeys.backupAutoSetupTitle.tr()), findsNothing);
    verify(() => service.schedule(any())).called(1);
    verify(() => service.clearKey()).called(1);
    expect(autoSwitch(tester).value, isFalse);
  });
}
