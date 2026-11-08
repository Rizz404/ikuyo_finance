// Regression: BKSEC-1, P01, A11, CORE-2, P05 (security settings).
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/security/cubit/security_cubit.dart';
import 'package:ikuyo_finance/features/security/models/security_settings.dart';
import 'package:ikuyo_finance/features/security/screens/lock_screen.dart';
import 'package:ikuyo_finance/features/security/screens/security_settings_screen.dart';
import 'package:ikuyo_finance/features/security/services/biometric_service.dart';
import 'package:ikuyo_finance/features/security/services/security_storage_service.dart';
import 'package:ikuyo_finance/features/security/utils/security_hasher.dart';
import 'package:ikuyo_finance/features/security/widgets/security_overlay.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_logger.dart';

class _NoBiometrics extends Fake implements LocalAuthentication {
  @override
  Future<bool> get canCheckBiometrics async => false;
  @override
  Future<bool> isDeviceSupported() async => false;
}

/// Secure storage yang gagal dibaca [failures] kali, lalu normal.
class _FlakySecureStorage extends Fake implements FlutterSecureStorage {
  _FlakySecureStorage(this.failures);
  int failures;
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
    if (failures > 0) {
      failures--;
      throw PlatformException(
        code: 'keystore',
        message: 'simulated read failure',
      );
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
}

const _key = 'app_security_settings';

SecuritySettings _pinLock() => SecuritySettings(
  isEnabled: true,
  pinEnabled: true,
  pinHash: SecurityHasher.hash('123456'),
);

Future<SecuritySettings?> _stored() async {
  final raw = await const FlutterSecureStorage().read(key: _key);
  return raw == null ? null : SecuritySettings.decode(raw);
}

/// Pump host lalu biarkan asset easy_localization selesai dimuat (I/O nyata).
Future<void> _pumpHost(
  WidgetTester tester,
  SecurityCubit cubit,
  Widget home,
) async {
  await tester.pumpWidget(_host(cubit, home));
  for (var i = 0; i < 20 && find.byType(Scaffold).evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

/// ? Host tanpa EasyLocalization: asset bundle easy_localization hanya
/// ? termuat di testWidgets pertama per file, sedangkan cek CORE-2 tidak
/// ? bergantung pada teks terjemahan (`.tr()` jatuh ke key mentah).
Widget _plainHost(SecurityCubit cubit, Widget home) => BlocProvider.value(
  value: cubit,
  child: MaterialApp(home: home),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pumpAndSettle();
}

Widget _host(SecurityCubit cubit, Widget home) => EasyLocalization(
  supportedLocales: const [Locale('en', 'US'), Locale('id', 'ID')],
  path: 'assets/translations',
  fallbackLocale: const Locale('en', 'US'),
  startLocale: const Locale('en', 'US'),
  child: Builder(
    builder: (context) => BlocProvider.value(
      value: cubit,
      child: MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        home: home,
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(bootstrapTestLogger);

  late SharedPreferences prefs;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  SecurityCubit newCubit([FlutterSecureStorage? storage]) => SecurityCubit(
    SecurityStorageService(storage ?? const FlutterSecureStorage(), prefs),
    BiometricService(_NoBiometrics()),
  );

  group('BKSEC-1 first-time enable', () {
    testWidgets(
      'real SecuritySettingsScreen: enable + PIN setup persists PIN and lock together',
      (tester) async {
        final cubit = newCubit();
        await _pumpHost(tester, cubit, const SecuritySettingsScreen());
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Switch).first);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.enterText(find.byType(TextField).last, '123456');
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, '123456');
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();

        final stored = (await _stored())!;
        expect(stored.isEnabled, isTrue);
        expect(stored.pinEnabled, isTrue);
        expect(stored.pinHash, isNotNull);

        // * Simulasi relaunch: cubit baru dari storage yang sama
        final relaunched = newCubit();
        await tester.pump();
        await tester.pump();
        expect(relaunched.state.shouldLock, isTrue);
        expect(relaunched.state.canUsePin, isTrue);
        await relaunched.close();
        await cubit.close();
      },
    );

    test(
      'concurrent setPin + toggleSecurity never persists an enabled lock without PIN',
      () async {
        final cubit = newCubit();
        await pumpEventQueue();
        final a = cubit.setPin('123456');
        final b = cubit.toggleSecurity(true);
        await Future.wait([a, b]);
        final stored = (await _stored())!;
        expect(stored.isEnabled, isTrue);
        expect(
          stored.pinHash,
          isNotNull,
          reason: 'second write must not drop the PIN',
        );
        expect(cubit.state.canUsePin, isTrue);
        await cubit.close();
      },
    );
  });

  group('P01 last unlock method', () {
    test(
      'removePin is rejected when it is the only knowledge factor of an enabled lock',
      () async {
        FlutterSecureStorage.setMockInitialValues({_key: _pinLock().encode()});
        final cubit = newCubit();
        await pumpEventQueue();
        await cubit.removePin();
        expect((await _stored())!.pinHash, isNotNull);
        expect(cubit.state.canUsePin, isTrue);
        await cubit.close();
      },
    );

    test(
      'removePassword is rejected when it is the only knowledge factor',
      () async {
        FlutterSecureStorage.setMockInitialValues({
          _key: SecuritySettings(
            isEnabled: true,
            passwordEnabled: true,
            passwordHash: SecurityHasher.hash('secret123'),
          ).encode(),
        });
        final cubit = newCubit();
        await pumpEventQueue();
        await cubit.removePassword();
        expect((await _stored())!.passwordHash, isNotNull);
        expect(cubit.state.canUsePassword, isTrue);
        await cubit.close();
      },
    );

    test(
      'enabling the lock with biometric only (no PIN/password) is rejected',
      () async {
        FlutterSecureStorage.setMockInitialValues({
          _key: const SecuritySettings(biometricEnabled: true).encode(),
        });
        final cubit = newCubit();
        await pumpEventQueue();
        await cubit.toggleSecurity(true);
        expect((await _stored())!.isEnabled, isFalse);
        expect(cubit.state.settings.isEnabled, isFalse);
        await cubit.close();
      },
    );

    test('removing the PIN is allowed when a password remains', () async {
      FlutterSecureStorage.setMockInitialValues({
        _key: _pinLock()
            .copyWith(
              passwordEnabled: true,
              passwordHash: SecurityHasher.hash('secret123'),
            )
            .encode(),
      });
      final cubit = newCubit();
      await pumpEventQueue();
      await cubit.removePin();
      final stored = (await _stored())!;
      expect(stored.pinHash, isNull);
      expect(stored.isEnabled, isTrue);
      expect(cubit.state.canUsePassword, isTrue);
      await cubit.close();
    });
  });

  group('A11 / P05 fail closed', () {
    test('first state of a lock-enabled app is never "unlocked"', () async {
      FlutterSecureStorage.setMockInitialValues({_key: _pinLock().encode()});
      final cubit = newCubit();
      expect(cubit.state.status, isNot(SecurityStatus.unlocked));
      await pumpEventQueue();
      expect(cubit.state.shouldLock, isTrue);
      await cubit.close();
    });

    test(
      'secure-storage read error with unknown lock state fails closed',
      () async {
        final cubit = newCubit(_FlakySecureStorage(1000));
        await pumpEventQueue();
        expect(cubit.state.shouldLock, isTrue);
        expect(cubit.state.status, isNot(SecurityStatus.unlocked));
        await cubit.close();
      },
    );

    test(
      'read error does not lock out a user whose lock is known to be disabled',
      () async {
        // * Marker non-rahasia ditulis saat settings disimpan dengan lock off
        final seed = newCubit();
        await pumpEventQueue();
        await seed.setAutoLockMinutes(5);
        await seed.close();

        final cubit = newCubit(_FlakySecureStorage(1000));
        await pumpEventQueue();
        expect(cubit.state.shouldLock, isFalse);
        expect(cubit.state.status, SecurityStatus.unlocked);
        await cubit.close();
      },
    );

    test(
      'retry after a transient read error loads the real settings (no lockout)',
      () async {
        FlutterSecureStorage.setMockInitialValues({_key: _pinLock().encode()});
        final cubit = newCubit(_FlakySecureStorage(1));
        await pumpEventQueue();
        expect(cubit.state.shouldLock, isTrue);
        await cubit.retryLoad();
        expect(cubit.state.loadFailed, isFalse);
        expect(cubit.state.shouldLock, isTrue);
        expect(cubit.state.canUsePin, isTrue);
        cubit.authenticateWithPin('123456');
        expect(cubit.state.shouldLock, isFalse);
        await cubit.close();
      },
    );

    test(
      'settings are never overwritten while the stored settings could not be read',
      () async {
        FlutterSecureStorage.setMockInitialValues({_key: _pinLock().encode()});
        final cubit = newCubit(_FlakySecureStorage(1000));
        await pumpEventQueue();
        await cubit.setAutoLockMinutes(10);
        final stored = (await _stored())!;
        expect(stored.pinHash, isNotNull);
        expect(stored.autoLockMinutes, 0);
        await cubit.close();
      },
    );
  });

  group('CORE-2 overlay', () {
    testWidgets(
      'protected content is hidden while settings are still loading',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({_key: _pinLock().encode()});
        final cubit = newCubit();
        await tester.pumpWidget(
          _plainHost(
            cubit,
            const SecurityOverlay(child: Text('BALANCE-SECRET')),
          ),
        );
        // * Frame pertama, sebelum load async selesai
        expect(find.text('BALANCE-SECRET'), findsNothing);
        await _settle(tester);
        expect(find.byType(LockScreen), findsOneWidget);
        expect(find.text('BALANCE-SECRET'), findsNothing);
        await cubit.close();
      },
    );

    testWidgets('content becomes visible once loaded with the lock disabled', (
      tester,
    ) async {
      final cubit = newCubit();
      await tester.pumpWidget(
        _plainHost(cubit, const SecurityOverlay(child: Text('BALANCE-SECRET'))),
      );
      await _settle(tester);
      expect(find.text('BALANCE-SECRET'), findsOneWidget);
      expect(find.byType(LockScreen), findsNothing);
      await cubit.close();
    });

    testWidgets('lock screen offers a retry after a read error', (
      tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({_key: _pinLock().encode()});
      final cubit = newCubit(_FlakySecureStorage(1));
      await tester.pumpWidget(
        _plainHost(cubit, const SecurityOverlay(child: Text('BALANCE-SECRET'))),
      );
      await _settle(tester);
      expect(find.text('BALANCE-SECRET'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('security-load-retry')));
      await _settle(tester);
      expect(cubit.state.canUsePin, isTrue);
      expect(find.byType(TextField), findsOneWidget);
      await cubit.close();
    });
  });
}
