// Regression: R01 (P05/A11 follow-up) — recoverable, fail-closed security
// settings read errors. A missing lock hint is never treated as "no lock".
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/security/cubit/security_cubit.dart';
import 'package:ikuyo_finance/features/security/models/security_settings.dart';
import 'package:ikuyo_finance/features/security/services/biometric_service.dart';
import 'package:ikuyo_finance/features/security/services/security_storage_service.dart';
import 'package:ikuyo_finance/features/security/utils/security_hasher.dart';
import 'package:ikuyo_finance/features/security/widgets/security_overlay.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/objectbox_test_store.dart';
import '../support/test_logger.dart';

/// OS boundary: device screen-lock availability + prompt result.
class _DeviceAuth extends Fake implements LocalAuthentication {
  _DeviceAuth({required this.deviceSecure, this.grant = true});
  bool deviceSecure;
  bool grant;
  int prompts = 0;

  @override
  Future<bool> get canCheckBiometrics async => false;
  @override
  Future<bool> isDeviceSupported() async => deviceSecure;
  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<Object?> authMessages = const <Object?>[],
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    prompts++;
    return deviceSecure && grant;
  }
}

/// OS boundary: keystore whose reads fail while [broken] is true.
class _BrokenReadStorage extends Fake implements FlutterSecureStorage {
  bool broken = true;
  static const _real = FlutterSecureStorage();

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (broken) {
      throw PlatformException(code: 'keystore', message: 'simulated');
    }
    return _real.read(key: key);
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) => _real.write(key: key, value: value);

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) => _real.delete(key: key);
}

const _key = 'app_security_settings';
const _otherSecret = 'auth_token';
const _hintKey = SecurityStorageService.lockEnabledHintKey;

String _pinLock() => SecuritySettings(
  isEnabled: true,
  pinEnabled: true,
  pinHash: SecurityHasher.hash('123456'),
).encode();

Future<String?> _raw() => const FlutterSecureStorage().read(key: _key);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(bootstrapTestLogger);

  late SharedPreferences prefs;

  Future<void> seed({
    Map<String, String> secure = const {},
    Map<String, Object> prefsValues = const {},
  }) async {
    FlutterSecureStorage.setMockInitialValues(Map.of(secure));
    SharedPreferences.setMockInitialValues(Map.of(prefsValues));
    prefs = await SharedPreferences.getInstance();
  }

  SecurityCubit newCubit(LocalAuthentication auth, [FlutterSecureStorage? s]) =>
      SecurityCubit(
        SecurityStorageService(s ?? const FlutterSecureStorage(), prefs),
        BiometricService(auth),
      );

  group('hint policy (evidence-backed)', () {
    test('fresh install: no stored settings loads unlocked and seeds hint=false', () async {
      await seed();
      final cubit = newCubit(_DeviceAuth(deviceSecure: false));
      await pumpEventQueue();
      expect(cubit.state.status, SecurityStatus.unlocked);
      expect(cubit.state.loadFailed, isFalse);
      expect(prefs.getBool(_hintKey), isFalse);
      await cubit.close();
    });

    test('legacy lock (no hint) that reads fine locks and seeds hint=true', () async {
      await seed(secure: {_key: _pinLock()});
      final cubit = newCubit(_DeviceAuth(deviceSecure: false));
      await pumpEventQueue();
      expect(cubit.state.shouldLock, isTrue);
      expect(cubit.state.canUsePin, isTrue);
      expect(prefs.getBool(_hintKey), isTrue);
      await cubit.close();
    });

    test('legacy lock with unknown hint and a read error stays locked, data untouched', () async {
      await seed(secure: {_key: _pinLock()});
      final cubit = newCubit(_DeviceAuth(deviceSecure: true), _BrokenReadStorage());
      await pumpEventQueue();
      expect(cubit.state.shouldLock, isTrue);
      expect(cubit.state.loadFailed, isTrue);
      expect(cubit.state.lockHint, isNull);
      expect(prefs.getBool(_hintKey), isNull, reason: 'a failure never writes the hint');
      expect(await _raw(), _pinLock());
      await cubit.close();
    });
  });

  group('corrupted store', () {
    test('invalid JSON is reported as corrupt, locked, and never auto-repaired', () async {
      await seed(secure: {_key: 'not-json{'});
      final auth = _DeviceAuth(deviceSecure: true);
      final cubit = newCubit(auth);
      await pumpEventQueue();
      expect(cubit.state.shouldLock, isTrue);
      expect(cubit.state.loadFailed, isTrue);
      expect(cubit.state.loadError, 'corrupt');
      await cubit.retryLoad();
      expect(cubit.state.shouldLock, isTrue);
      expect(await _raw(), 'not-json{');
      expect(auth.prompts, 0, reason: 'no reset/unlock without an explicit user action');
      await cubit.close();
    });

    test('diagnostics expose error kind, hint and credential state but no secrets', () async {
      await seed(secure: {_key: _pinLock()}, prefsValues: {_hintKey: true});
      final cubit = newCubit(_DeviceAuth(deviceSecure: false), _BrokenReadStorage());
      await pumpEventQueue();
      final d = cubit.state.diagnostics;
      expect(d, contains('error=platform:keystore'));
      expect(d, contains('lockHint=true'));
      expect(d, contains('deviceCredential=false'));
      expect(d, isNot(contains(SecurityHasher.hash('123456').substring(0, 8))));
      await cubit.close();
    });
  });

  group('no device credential', () {
    test('unknown hint + read error never unlocks and cannot reset', () async {
      await seed(secure: {_key: _pinLock()});
      final auth = _DeviceAuth(deviceSecure: false);
      final cubit = newCubit(auth, _BrokenReadStorage());
      await pumpEventQueue();
      expect(cubit.state.status, isNot(SecurityStatus.unlocked));
      expect(await cubit.resetLockWithDeviceCredential(), isFalse);
      expect(cubit.state.shouldLock, isTrue);
      expect(await _raw(), _pinLock());
      await cubit.close();
    });

    test('setting up a device screen lock then retrying re-enables recovery', () async {
      await seed(secure: {_key: _pinLock()});
      final auth = _DeviceAuth(deviceSecure: false);
      final cubit = newCubit(auth, _BrokenReadStorage());
      await pumpEventQueue();
      expect(cubit.state.deviceCredentialAvailable, isFalse);
      auth.deviceSecure = true;
      await cubit.retryLoad();
      expect(cubit.state.shouldLock, isTrue);
      expect(cubit.state.deviceCredentialAvailable, isTrue);
      await cubit.close();
    });
  });

  group('device-credential-gated reset', () {
    test('denied device auth keeps the lock and the stored settings', () async {
      await seed(secure: {_key: _pinLock()});
      final auth = _DeviceAuth(deviceSecure: true, grant: false);
      final cubit = newCubit(auth, _BrokenReadStorage());
      await pumpEventQueue();
      expect(await cubit.resetLockWithDeviceCredential(), isFalse);
      expect(auth.prompts, 1);
      expect(cubit.state.shouldLock, isTrue);
      expect(await _raw(), _pinLock());
      await cubit.close();
    });

    test('granted reset clears only the lock; DB, other secrets and prefs survive', () async {
      final db = await ObjectBoxTestStore.open();
      addTearDown(db.close);
      db.storage.box<Category>().put(Category(name: 'Food', type: 1));

      await seed(
        secure: {_key: 'not-json{', _otherSecret: 'synthetic-token'},
        prefsValues: {'currency_code': 'IDR'},
      );
      final auth = _DeviceAuth(deviceSecure: true);
      final cubit = newCubit(auth);
      await pumpEventQueue();
      expect(cubit.state.shouldLock, isTrue);

      expect(await cubit.resetLockWithDeviceCredential(), isTrue);
      expect(auth.prompts, 1);
      expect(cubit.state.status, SecurityStatus.unlocked);
      expect(cubit.state.loadFailed, isFalse);
      expect(cubit.state.settings.isEnabled, isFalse);

      expect(await _raw(), isNull);
      expect(
        await const FlutterSecureStorage().read(key: _otherSecret),
        'synthetic-token',
      );
      expect(prefs.getString('currency_code'), 'IDR');
      expect(prefs.getBool(_hintKey), isFalse);
      expect(db.storage.box<Category>().getAll().single.name, 'Food');

      // * Restart: fresh cubit reads the reset store normally
      final relaunched = newCubit(_DeviceAuth(deviceSecure: true));
      await pumpEventQueue();
      expect(relaunched.state.status, SecurityStatus.unlocked);
      expect(relaunched.state.loadFailed, isFalse);
      await relaunched.close();
      await cubit.close();
    });

    test('reset is refused when settings loaded fine (not a bypass)', () async {
      await seed(secure: {_key: _pinLock()});
      final auth = _DeviceAuth(deviceSecure: true);
      final cubit = newCubit(auth);
      await pumpEventQueue();
      expect(await cubit.resetLockWithDeviceCredential(), isFalse);
      expect(auth.prompts, 0);
      expect(cubit.state.shouldLock, isTrue);
      expect(await _raw(), _pinLock());
      await cubit.close();
    });
  });

  group('recovery UI', () {
    Widget host(SecurityCubit cubit) => BlocProvider.value(
      value: cubit,
      child: const MaterialApp(
        home: SecurityOverlay(child: Text('BALANCE-SECRET')),
      ),
    );

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('no credential: retry + diagnostics + copy, no reset, still hidden', (
      tester,
    ) async {
      await seed(secure: {_key: _pinLock()});
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      final cubit = newCubit(_DeviceAuth(deviceSecure: false), _BrokenReadStorage());
      await tester.pumpWidget(host(cubit));
      await settle(tester);

      expect(find.text('BALANCE-SECRET'), findsNothing);
      expect(find.byKey(const ValueKey('security-load-retry')), findsOneWidget);
      expect(find.byKey(const ValueKey('security-no-device-credential')), findsOneWidget);
      expect(find.byKey(const ValueKey('security-reset-lock')), findsNothing);
      expect(find.byKey(const ValueKey('security-diagnostics')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('security-copy-diagnostics')));
      await tester.pumpAndSettle();
      expect(copied, contains('lockHint=unknown'));
      await cubit.close();
    });

    testWidgets('with credential: reset needs confirmation then device auth', (
      tester,
    ) async {
      await seed(secure: {_key: _pinLock()});
      final auth = _DeviceAuth(deviceSecure: true);
      final cubit = newCubit(auth, _BrokenReadStorage());
      await tester.pumpWidget(host(cubit));
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('security-reset-lock')));
      await tester.pumpAndSettle();
      expect(auth.prompts, 0, reason: 'confirmation first');
      await tester.tap(find.byKey(const ValueKey('security-reset-lock-cancel')));
      await tester.pumpAndSettle();
      expect(auth.prompts, 0);
      expect(find.text('BALANCE-SECRET'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('security-reset-lock')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('security-reset-lock-confirm')));
      await settle(tester);
      expect(auth.prompts, 1);
      expect(find.text('BALANCE-SECRET'), findsOneWidget);
      expect(await _raw(), isNull);
      await cubit.close();
    });
  });
}
