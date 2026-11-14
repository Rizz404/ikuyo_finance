// Regression: A06, A07, BKSEC-2, BKSEC-3, BKSEC-5, CORE-1, CORE-4 (auto backup
// scheduling). Platform channels (notifications, WorkManager) are mocked at
// the method-channel boundary; the service and bloc are real.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ikuyo_finance/core/wrapper/failure.dart';
import 'package:ikuyo_finance/core/wrapper/success.dart';
import 'package:ikuyo_finance/features/backup/bloc/backup_bloc.dart';
import 'package:ikuyo_finance/features/backup/models/backup_data.dart';
import 'package:ikuyo_finance/features/backup/models/backup_schedule_settings.dart';
import 'package:ikuyo_finance/features/backup/repositories/backup_repository.dart';
import 'package:ikuyo_finance/features/backup/services/auto_backup_key_store.dart';
import 'package:ikuyo_finance/features/backup/services/auto_backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:workmanager_android/workmanager_android.dart';

import '../support/test_logger.dart';

class _FakeBackupRepo implements BackupRepository {
  @override
  TaskEither<Failure, Success<BackupData>> exportData() => TaskEither.right(
    Success(
      message: 'ok',
      data: BackupData(
        version: '1',
        createdAt: DateTime(2026),
        appName: 'Ikuyo Finance',
        categories: const [],
        assets: const [],
        transactions: const [],
        budgets: const [],
      ),
    ),
  );

  @override
  TaskEither<Failure, Success<Map<String, int>>> getDataSummary() =>
      TaskEither.right(const Success(message: 'ok', data: {'categories': 1}));

  @override
  TaskEither<Failure, Success<void>> importData(BackupData backupData) =>
      TaskEither.right(const Success(message: 'imported'));
}

// * Argon2id berjalan di isolate nyata: tunggu dengan waktu nyata
Future<void> _waitFor(bool Function() done) async {
  for (var i = 0; i < 600 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  await pumpEventQueue();
}

const _notifChannel = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);
const _wmPrefix =
    'dev.flutter.pigeon.workmanager_platform_interface.WorkmanagerHostApi.';
const _wmMethods = ['cancelByUniqueName', 'registerPeriodicTask'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(bootstrapTestLogger);

  final calls = <String>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var failRegister = false;

  void installMocks(TargetPlatform p) {
    calls.clear();
    failRegister = false;
    debugDefaultTargetPlatformOverride = p;
    if (p == TargetPlatform.android) {
      AndroidFlutterLocalNotificationsPlugin.registerWith();
    } else {
      IOSFlutterLocalNotificationsPlugin.registerWith();
    }
    WorkmanagerAndroid.registerWith();
    messenger.setMockMethodCallHandler(_notifChannel, (call) async {
      calls.add('notif.${call.method}');
      if (call.method == 'canScheduleExactNotifications') return true;
      return null;
    });
    for (final m in _wmMethods) {
      messenger.setMockMessageHandler('$_wmPrefix$m', (msg) async {
        calls.add('wm.$m');
        if (m == 'registerPeriodicTask' && failRegister) {
          return const StandardMessageCodec().encodeMessage(<Object?>[
            'wm_error',
            'simulated failure',
            null,
          ]);
        }
        return const StandardMessageCodec().encodeMessage(<Object?>[]);
      });
    }
  }

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(_notifChannel, null);
    for (final m in _wmMethods) {
      messenger.setMockMessageHandler('$_wmPrefix$m', null);
    }
  });

  Future<SharedPreferences> prefsWith(BackupScheduleSettings? s) async {
    SharedPreferences.setMockInitialValues({
      if (s != null) 'auto_backup_settings': s.toJsonString(),
    });
    return SharedPreferences.getInstance();
  }

  BackupScheduleSettings persisted(SharedPreferences prefs) =>
      BackupScheduleSettings.fromJsonString(
        prefs.getString('auto_backup_settings')!,
      );

  group('AutoBackupService (WorkManager-only)', () {
    test('A06a disable cancels the WorkManager task without throwing', () async {
      installMocks(TargetPlatform.android);
      final svc = AutoBackupService(await prefsWith(null));
      await svc.schedule(const BackupScheduleSettings(isEnabled: false));
      expect(calls, contains('wm.cancelByUniqueName'));
      expect(calls.where((c) => c.startsWith('notif.')), isEmpty);
    });

    test('A06d/BKSEC-2 enable (exact alarms allowed) registers WorkManager, '
        'no tz.local / exact alarm involved', () async {
      installMocks(TargetPlatform.android);
      final svc = AutoBackupService(await prefsWith(null));
      await svc.schedule(const BackupScheduleSettings(isEnabled: true));
      expect(calls, contains('wm.registerPeriodicTask'));
      expect(calls, isNot(contains('notif.zonedSchedule')));
    });

    test('BKSEC-2 iOS enable does not throw', () async {
      installMocks(TargetPlatform.iOS);
      final svc = AutoBackupService(await prefsWith(null));
      await svc.schedule(const BackupScheduleSettings(isEnabled: true));
      expect(calls, contains('wm.registerPeriodicTask'));
    });
  });

  group('BKSEC-9 auto backup rotation', () {
    // * F10: rotasi hanya untuk .ikuyo terenkripsi; .json lama tidak disentuh
    test('keeps only the newest N encrypted backup files and ignores other '
        'files', () async {
      final dir = Directory.systemTemp.createTempSync('ikuyo_rotation_');
      addTearDown(() => dir.deleteSync(recursive: true));
      for (var i = 1; i <= 13; i++) {
        final d = i.toString().padLeft(2, '0');
        File('${dir.path}/ikuyo_backup_202601${d}_020000.ikuyo')
            .writeAsStringSync('IKYB');
      }
      File('${dir.path}/notes.txt').writeAsStringSync('keep me');

      await AutoBackupService.pruneOldBackups(dir, keep: 10);

      final names = dir
          .listSync()
          .map((e) => e.uri.pathSegments.last)
          .toList()
        ..sort();
      expect(names, contains('notes.txt'));
      expect(names.where((n) => n.startsWith('ikuyo_backup_')), hasLength(10));
      expect(names, isNot(contains('ikuyo_backup_20260101_020000.ikuyo')));
      expect(names, isNot(contains('ikuyo_backup_20260103_020000.ikuyo')));
      expect(names, contains('ikuyo_backup_20260113_020000.ikuyo'));
      expect(names, contains('ikuyo_backup_20260104_020000.ikuyo'));
    });
  });

  group('BackupBloc schedule state', () {
    test('A06b disable: persisted settings and bloc state agree', () async {
      installMocks(TargetPlatform.android);
      FlutterSecureStorage.setMockInitialValues({});
      final prefs = await prefsWith(
        const BackupScheduleSettings(isEnabled: true),
      );
      final errors = <Object>[];
      late BackupBloc bloc;
      await runZonedGuarded(() async {
        bloc = BackupBloc(_FakeBackupRepo(), AutoBackupService(prefs));
        bloc.add(BackupScheduleLoaded());
        await pumpEventQueue();
        bloc.add(BackupScheduleToggled(false));
        await pumpEventQueue(times: 50);
      }, (e, s) => errors.add(e));
      expect(errors, isEmpty);
      expect(persisted(prefs).isEnabled, isFalse);
      expect(bloc.state.schedule.isEnabled, isFalse);
      expect(calls, contains('wm.cancelByUniqueName'));
      await bloc.close();
    });

    test('enable failure: settings stay disabled, a failure is emitted and '
        'the just-derived key is rolled back', () async {
      installMocks(TargetPlatform.android);
      FlutterSecureStorage.setMockInitialValues({});
      final prefs = await prefsWith(
        const BackupScheduleSettings(isEnabled: false),
      );
      failRegister = true;
      final errors = <Object>[];
      late BackupBloc bloc;
      final statuses = <BackupStatus>[];
      await runZonedGuarded(() async {
        bloc = BackupBloc(_FakeBackupRepo(), AutoBackupService(prefs));
        bloc.stream.listen((s) => statuses.add(s.status));
        bloc.add(BackupScheduleLoaded());
        await pumpEventQueue();
        bloc.add(BackupAutoEnableRequested('synthetic passphrase'));
        await _waitFor(() => !bloc.state.autoKeyBusy &&
            statuses.contains(BackupStatus.failure));
      }, (e, s) => errors.add(e));
      expect(errors, isEmpty);
      expect(persisted(prefs).isEnabled, isFalse);
      expect(bloc.state.schedule.isEnabled, isFalse);
      expect(statuses, contains(BackupStatus.failure));
      expect(
        await const FlutterSecureStorage().read(
          key: AutoBackupKeyStore.storageKey,
        ),
        isNull,
      );
      await bloc.close();
    }, timeout: const Timeout(Duration(minutes: 1)));

    test('F10 enabling without a passphrase is refused: no schedule, no '
        'settings change', () async {
      installMocks(TargetPlatform.android);
      FlutterSecureStorage.setMockInitialValues({});
      final prefs = await prefsWith(null);
      final bloc = BackupBloc(_FakeBackupRepo(), AutoBackupService(prefs));
      bloc.add(BackupScheduleLoaded());
      await _waitFor(() => bloc.state.autoKeyState != null);
      bloc.add(BackupScheduleToggled(true));
      await pumpEventQueue(times: 20);
      expect(bloc.state.schedule.isEnabled, isFalse);
      expect(prefs.getString('auto_backup_settings'), isNull);
      expect(calls, isNot(contains('wm.registerPeriodicTask')));
      await bloc.close();
    });

    test('F10 enabling with a passphrase stores the key, then schedules; '
        'disabling cancels and clears the key', () async {
      installMocks(TargetPlatform.android);
      FlutterSecureStorage.setMockInitialValues({});
      final prefs = await prefsWith(null);
      final bloc = BackupBloc(_FakeBackupRepo(), AutoBackupService(prefs));
      bloc.add(BackupScheduleLoaded());
      await _waitFor(() => bloc.state.autoKeyState != null);
      expect(bloc.state.autoKeyState, AutoBackupKeyState.missing);
      expect(bloc.state.autoBackupPaused, isFalse);

      bloc.add(BackupAutoEnableRequested('synthetic passphrase'));
      await _waitFor(
        () => bloc.state.schedule.isEnabled &&
            !bloc.state.autoKeyBusy &&
            bloc.state.autoKeyState == AutoBackupKeyState.ready,
      );
      expect(persisted(prefs).isEnabled, isTrue);
      expect(calls, contains('wm.registerPeriodicTask'));
      final raw = await const FlutterSecureStorage().read(
        key: AutoBackupKeyStore.storageKey,
      );
      expect(raw, isNotNull);
      expect(raw!.contains('synthetic passphrase'), isFalse);
      expect(bloc.state.autoBackupPaused, isFalse);

      bloc.add(BackupScheduleToggled(false));
      await _waitFor(
        () => bloc.state.autoKeyState == AutoBackupKeyState.missing,
      );
      expect(persisted(prefs).isEnabled, isFalse);
      expect(calls, contains('wm.cancelByUniqueName'));
      expect(
        await const FlutterSecureStorage().read(
          key: AutoBackupKeyStore.storageKey,
        ),
        isNull,
      );
      await bloc.close();
    }, timeout: const Timeout(Duration(minutes: 1)));

    test('F10 upgrade: schedule already enabled without a key keeps the '
        'schedule but reports paused until setup; setup resumes', () async {
      installMocks(TargetPlatform.android);
      FlutterSecureStorage.setMockInitialValues({});
      final prefs = await prefsWith(
        const BackupScheduleSettings(isEnabled: true),
      );
      final bloc = BackupBloc(_FakeBackupRepo(), AutoBackupService(prefs));
      bloc.add(BackupScheduleLoaded());
      await _waitFor(() => bloc.state.autoKeyState != null);
      expect(bloc.state.schedule.isEnabled, isTrue);
      expect(bloc.state.autoKeyState, AutoBackupKeyState.missing);
      expect(bloc.state.autoBackupPaused, isTrue);
      expect(persisted(prefs).isEnabled, isTrue);

      bloc.add(BackupAutoKeySetupRequested('synthetic passphrase'));
      await _waitFor(
        () => bloc.state.autoKeyState == AutoBackupKeyState.ready &&
            !bloc.state.autoKeyBusy,
      );
      expect(bloc.state.autoBackupPaused, isFalse);
      expect(bloc.state.schedule.isEnabled, isTrue);
      await bloc.close();
    }, timeout: const Timeout(Duration(minutes: 1)));

    test('F10 an unreadable stored key is reported as paused (unreadable)',
        () async {
      installMocks(TargetPlatform.android);
      FlutterSecureStorage.setMockInitialValues({
        AutoBackupKeyStore.storageKey: 'garbage',
      });
      final prefs = await prefsWith(
        const BackupScheduleSettings(isEnabled: true),
      );
      final bloc = BackupBloc(_FakeBackupRepo(), AutoBackupService(prefs));
      bloc.add(BackupScheduleLoaded());
      await _waitFor(() => bloc.state.autoKeyState != null);
      expect(bloc.state.autoKeyState, AutoBackupKeyState.unreadable);
      expect(bloc.state.autoBackupPaused, isTrue);
      await bloc.close();
    });

    test('F10 a passphrase too short for setup fails without touching the '
        'schedule or storing anything', () async {
      installMocks(TargetPlatform.android);
      FlutterSecureStorage.setMockInitialValues({});
      final prefs = await prefsWith(null);
      final statuses = <BackupStatus>[];
      final bloc = BackupBloc(_FakeBackupRepo(), AutoBackupService(prefs));
      bloc.stream.listen((s) => statuses.add(s.status));
      bloc.add(BackupScheduleLoaded());
      await _waitFor(() => bloc.state.autoKeyState != null);
      bloc.add(BackupAutoEnableRequested('short'));
      await _waitFor(() => statuses.contains(BackupStatus.failure));
      expect(bloc.state.schedule.isEnabled, isFalse);
      expect(bloc.state.autoKeyBusy, isFalse);
      expect(calls, isNot(contains('wm.registerPeriodicTask')));
      expect(
        await const FlutterSecureStorage().read(
          key: AutoBackupKeyStore.storageKey,
        ),
        isNull,
      );
      await bloc.close();
    });

    test('BKSEC-5 exported data is one-shot: later emits do not carry it',
        () async {
      installMocks(TargetPlatform.android);
      FlutterSecureStorage.setMockInitialValues({});
      final prefs = await prefsWith(null);
      final bloc = BackupBloc(_FakeBackupRepo(), AutoBackupService(prefs));
      bloc.add(BackupExportRequested());
      await pumpEventQueue();
      expect(bloc.state.exportedData, isNotNull);
      bloc.add(BackupSummaryRequested());
      await pumpEventQueue();
      expect(bloc.state.summary, isNotNull);
      expect(bloc.state.exportedData, isNull);
      expect(bloc.state.isImport, isFalse);

      bloc.add(BackupImportRequested(bloc.state.exportedData ??
          BackupData(
            version: '1',
            createdAt: DateTime(2026),
            appName: 'x',
            categories: const [],
            assets: const [],
            transactions: const [],
            budgets: const [],
          )));
      await pumpEventQueue();
      expect(bloc.state.isImport, isTrue);
      bloc.add(BackupSummaryRequested());
      await pumpEventQueue();
      expect(bloc.state.isImport, isFalse);
      await bloc.close();
    });
  });
}
