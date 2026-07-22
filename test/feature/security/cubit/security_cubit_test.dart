import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ikuyo_finance/features/security/cubit/security_cubit.dart';
import 'package:ikuyo_finance/features/security/models/security_settings.dart';
import 'package:ikuyo_finance/features/security/services/biometric_service.dart';
import 'package:ikuyo_finance/features/security/services/security_storage_service.dart';
import 'package:ikuyo_finance/features/security/utils/security_hasher.dart';

import '../../../support/test_logger.dart';

class MockSecurityStorageService extends Mock implements SecurityStorageService {}

class MockBiometricService extends Mock implements BiometricService {}

void main() {
  setUpAll(() {
    bootstrapTestLogger();
    // * Needed by mocktail whenever `any()` is used for this argument type
    // * in when()/verify().
    registerFallbackValue(const SecuritySettings());
  });

  late MockSecurityStorageService mockStorage;
  late MockBiometricService mockBiometric;

  setUp(() {
    mockStorage = MockSecurityStorageService();
    mockBiometric = MockBiometricService();

    // * `SecurityCubit`'s constructor fires-and-forgets an internal `_init()`
    // * that awaits `_storageService.load()` then emits once it resolves.
    // * Because that emission lands asynchronously (after the blocTest
    // * stream subscription is already attached) it would otherwise show up
    // * as an unwanted extra state in every single test. We hang `load()`
    // * forever by default so `_init()` never reaches its `emit`, and set up
    // * whatever state a given test needs via `seed:` instead. The
    // * dedicated "_init" group below overrides this to test init directly.
    when(
      () => mockStorage.load(),
    ).thenAnswer((_) => Completer<SecuritySettings>().future);
    when(() => mockBiometric.isAvailable).thenAnswer((_) async => false);
    when(() => mockStorage.save(any())).thenAnswer((_) async {});
    when(() => mockStorage.clear()).thenAnswer((_) async {});
  });

  group('_init (constructor)', () {
    blocTest<SecurityCubit, SecurityState>(
      'loads settings and biometric availability, locked when security is enabled',
      build: () {
        when(() => mockStorage.load()).thenAnswer(
          (_) async => const SecuritySettings(isEnabled: true, pinEnabled: true),
        );
        when(() => mockBiometric.isAvailable).thenAnswer((_) async => true);
        return SecurityCubit(mockStorage, mockBiometric);
      },
      wait: const Duration(milliseconds: 20),
      expect: () => [
        predicate<SecurityState>(
          (s) =>
              s.status == SecurityStatus.locked &&
              s.settings.isEnabled &&
              s.settings.pinEnabled &&
              s.biometricAvailable,
        ),
      ],
    );

    blocTest<SecurityCubit, SecurityState>(
      'unlocked when security is disabled',
      build: () {
        when(() => mockStorage.load()).thenAnswer(
          (_) async => const SecuritySettings(),
        );
        return SecurityCubit(mockStorage, mockBiometric);
      },
      wait: const Duration(milliseconds: 20),
      expect: () => [
        predicate<SecurityState>(
          (s) => s.status == SecurityStatus.unlocked && !s.settings.isEnabled,
        ),
      ],
    );

    blocTest<SecurityCubit, SecurityState>(
      'does not emit when loading settings throws (error is caught and logged)',
      build: () {
        when(() => mockStorage.load()).thenThrow(Exception('disk error'));
        return SecurityCubit(mockStorage, mockBiometric);
      },
      wait: const Duration(milliseconds: 20),
      expect: () => [],
    );
  });

  group('authenticateWithBiometric', () {
    blocTest<SecurityCubit, SecurityState>(
      'does nothing when biometric cannot be used',
      build: () => SecurityCubit(mockStorage, mockBiometric),
      seed: () => const SecurityState(
        settings: SecuritySettings(isEnabled: true, biometricEnabled: false),
        biometricAvailable: true,
      ),
      act: (cubit) => cubit.authenticateWithBiometric(),
      expect: () => [],
      verify: (_) {
        verifyNever(() => mockBiometric.authenticate(reason: any(named: 'reason')));
      },
    );

    blocTest<SecurityCubit, SecurityState>(
      'emits [authenticating, unlocked] and resets failedAttempts on success',
      build: () {
        when(
          () => mockBiometric.authenticate(reason: any(named: 'reason')),
        ).thenAnswer((_) async => true);
        return SecurityCubit(mockStorage, mockBiometric);
      },
      seed: () => const SecurityState(
        settings: SecuritySettings(isEnabled: true, biometricEnabled: true),
        biometricAvailable: true,
        status: SecurityStatus.locked,
        failedAttempts: 2,
      ),
      act: (cubit) => cubit.authenticateWithBiometric(),
      expect: () => [
        predicate<SecurityState>((s) => s.status == SecurityStatus.authenticating),
        predicate<SecurityState>(
          (s) =>
              s.status == SecurityStatus.unlocked &&
              s.authResult == SecurityAuthResult.success &&
              s.failedAttempts == 0,
        ),
      ],
    );

    blocTest<SecurityCubit, SecurityState>(
      'returns to [authenticating, locked/idle] without a failure banner when canceled/failed',
      build: () {
        when(
          () => mockBiometric.authenticate(reason: any(named: 'reason')),
        ).thenAnswer((_) async => false);
        return SecurityCubit(mockStorage, mockBiometric);
      },
      seed: () => const SecurityState(
        settings: SecuritySettings(isEnabled: true, biometricEnabled: true),
        biometricAvailable: true,
        status: SecurityStatus.locked,
      ),
      act: (cubit) => cubit.authenticateWithBiometric(),
      expect: () => [
        predicate<SecurityState>((s) => s.status == SecurityStatus.authenticating),
        predicate<SecurityState>(
          (s) => s.status == SecurityStatus.locked && s.authResult == SecurityAuthResult.idle,
        ),
      ],
    );
  });

  group('authenticateWithPin', () {
    blocTest<SecurityCubit, SecurityState>(
      'does nothing when PIN cannot be used (not enabled / no hash)',
      build: () => SecurityCubit(mockStorage, mockBiometric),
      seed: () => const SecurityState(
        settings: SecuritySettings(isEnabled: true, pinEnabled: false),
      ),
      act: (cubit) => cubit.authenticateWithPin('123456'),
      expect: () => [],
    );

    blocTest<SecurityCubit, SecurityState>(
      'emits [authenticating, unlocked] and resets failedAttempts on a correct PIN',
      build: () => SecurityCubit(mockStorage, mockBiometric),
      seed: () => SecurityState(
        settings: SecuritySettings(
          isEnabled: true,
          pinEnabled: true,
          pinHash: SecurityHasher.hash('123456'),
        ),
        status: SecurityStatus.locked,
        failedAttempts: 1,
      ),
      act: (cubit) => cubit.authenticateWithPin('123456'),
      expect: () => [
        predicate<SecurityState>((s) => s.status == SecurityStatus.authenticating),
        predicate<SecurityState>(
          (s) =>
              s.status == SecurityStatus.unlocked &&
              s.authResult == SecurityAuthResult.success &&
              s.failedAttempts == 0,
        ),
      ],
    );

    blocTest<SecurityCubit, SecurityState>(
      'emits [authenticating, locked/failed] and increments failedAttempts on a wrong PIN',
      build: () => SecurityCubit(mockStorage, mockBiometric),
      seed: () => SecurityState(
        settings: SecuritySettings(
          isEnabled: true,
          pinEnabled: true,
          pinHash: SecurityHasher.hash('123456'),
        ),
        status: SecurityStatus.locked,
        failedAttempts: 1,
      ),
      act: (cubit) => cubit.authenticateWithPin('000000'),
      expect: () => [
        predicate<SecurityState>((s) => s.status == SecurityStatus.authenticating),
        predicate<SecurityState>(
          (s) =>
              s.status == SecurityStatus.locked &&
              s.authResult == SecurityAuthResult.failed &&
              s.failedAttempts == 2 &&
              s.errorMessage == 'Incorrect PIN',
        ),
      ],
    );
  });

  group('authenticateWithPassword', () {
    blocTest<SecurityCubit, SecurityState>(
      'does nothing when password cannot be used (not enabled / no hash)',
      build: () => SecurityCubit(mockStorage, mockBiometric),
      seed: () => const SecurityState(
        settings: SecuritySettings(isEnabled: true, passwordEnabled: false),
      ),
      act: (cubit) => cubit.authenticateWithPassword('secret123'),
      expect: () => [],
    );

    blocTest<SecurityCubit, SecurityState>(
      'emits [authenticating, unlocked] and resets failedAttempts on a correct password',
      build: () => SecurityCubit(mockStorage, mockBiometric),
      seed: () => SecurityState(
        settings: SecuritySettings(
          isEnabled: true,
          passwordEnabled: true,
          passwordHash: SecurityHasher.hash('secret123'),
        ),
        status: SecurityStatus.locked,
        failedAttempts: 3,
      ),
      act: (cubit) => cubit.authenticateWithPassword('secret123'),
      expect: () => [
        predicate<SecurityState>((s) => s.status == SecurityStatus.authenticating),
        predicate<SecurityState>(
          (s) =>
              s.status == SecurityStatus.unlocked &&
              s.authResult == SecurityAuthResult.success &&
              s.failedAttempts == 0,
        ),
      ],
    );

    blocTest<SecurityCubit, SecurityState>(
      'emits [authenticating, locked/failed] and increments failedAttempts on a wrong password',
      build: () => SecurityCubit(mockStorage, mockBiometric),
      seed: () => SecurityState(
        settings: SecuritySettings(
          isEnabled: true,
          passwordEnabled: true,
          passwordHash: SecurityHasher.hash('secret123'),
        ),
        status: SecurityStatus.locked,
      ),
      act: (cubit) => cubit.authenticateWithPassword('wrong'),
      expect: () => [
        predicate<SecurityState>((s) => s.status == SecurityStatus.authenticating),
        predicate<SecurityState>(
          (s) =>
              s.status == SecurityStatus.locked &&
              s.authResult == SecurityAuthResult.failed &&
              s.failedAttempts == 1 &&
              s.errorMessage == 'Incorrect password',
        ),
      ],
    );
  });

  group('clearAuthResult', () {
    blocTest<SecurityCubit, SecurityState>(
      'resets authResult to idle without touching other fields',
      build: () => SecurityCubit(mockStorage, mockBiometric),
      seed: () => const SecurityState(
        status: SecurityStatus.locked,
        authResult: SecurityAuthResult.failed,
        failedAttempts: 2,
        errorMessage: 'Incorrect PIN',
      ),
      act: (cubit) => cubit.clearAuthResult(),
      expect: () => [
        predicate<SecurityState>(
          (s) =>
              s.authResult == SecurityAuthResult.idle &&
              s.status == SecurityStatus.locked &&
              s.failedAttempts == 2,
        ),
      ],
    );
  });

  group('updateSettings', () {
    blocTest<SecurityCubit, SecurityState>(
      'saves and emits the new settings with fresh biometric availability',
      build: () {
        when(() => mockBiometric.isAvailable).thenAnswer((_) async => true);
        return SecurityCubit(mockStorage, mockBiometric);
      },
      act: (cubit) => cubit.updateSettings(
        const SecuritySettings(isEnabled: true, autoLockMinutes: 10),
      ),
      expect: () => [
        predicate<SecurityState>(
          (s) => s.settings.isEnabled && s.settings.autoLockMinutes == 10 && s.biometricAvailable,
        ),
      ],
      verify: (_) {
        verify(() => mockStorage.save(any())).called(1);
      },
    );

    blocTest<SecurityCubit, SecurityState>(
      'does not emit when saving fails (error is caught and logged)',
      build: () {
        when(() => mockStorage.save(any())).thenThrow(Exception('write failed'));
        return SecurityCubit(mockStorage, mockBiometric);
      },
      act: (cubit) => cubit.updateSettings(const SecuritySettings(isEnabled: true)),
      expect: () => [],
      verify: (_) {
        verify(() => mockStorage.save(any())).called(1);
        verifyNever(() => mockBiometric.isAvailable);
      },
    );
  });

  group('toggleSecurity', () {
    blocTest<SecurityCubit, SecurityState>(
      'enabling only updates settings (single emit)',
      build: () => SecurityCubit(mockStorage, mockBiometric),
      act: (cubit) => cubit.toggleSecurity(true),
      expect: () => [predicate<SecurityState>((s) => s.settings.isEnabled)],
    );

    blocTest<SecurityCubit, SecurityState>(
      'disabling updates settings then forces status back to unlocked/idle',
      build: () => SecurityCubit(mockStorage, mockBiometric),
      seed: () => const SecurityState(
        settings: SecuritySettings(isEnabled: true),
        status: SecurityStatus.locked,
      ),
      act: (cubit) => cubit.toggleSecurity(false),
      expect: () => [
        predicate<SecurityState>((s) => !s.settings.isEnabled),
        predicate<SecurityState>(
          (s) => s.status == SecurityStatus.unlocked && s.authResult == SecurityAuthResult.idle,
        ),
      ],
    );
  });

  group('setPin / removePin', () {
    blocTest<SecurityCubit, SecurityState>(
      'hashes the PIN and enables it with the correct length',
      build: () => SecurityCubit(mockStorage, mockBiometric),
      act: (cubit) => cubit.setPin('123456'),
      expect: () => [
        predicate<SecurityState>(
          (s) =>
              s.settings.pinEnabled &&
              s.settings.pinLength == 6 &&
              s.settings.pinHash == SecurityHasher.hash('123456'),
        ),
      ],
    );

    blocTest<SecurityCubit, SecurityState>(
      'hashes a 4-digit PIN and records its length',
      build: () => SecurityCubit(mockStorage, mockBiometric),
      act: (cubit) => cubit.setPin('4321'),
      expect: () => [
        predicate<SecurityState>(
          (s) => s.settings.pinEnabled && s.settings.pinLength == 4,
        ),
      ],
    );

    blocTest<SecurityCubit, SecurityState>(
      'removes the PIN but keeps other settings intact',
      build: () => SecurityCubit(mockStorage, mockBiometric),
      seed: () => const SecurityState(
        settings: SecuritySettings(
          isEnabled: true,
          pinEnabled: true,
          pinHash: 'somehash',
          biometricEnabled: true,
        ),
      ),
      act: (cubit) => cubit.removePin(),
      expect: () => [
        predicate<SecurityState>(
          (s) =>
              !s.settings.pinEnabled &&
              s.settings.pinHash == null &&
              s.settings.isEnabled &&
              s.settings.biometricEnabled,
        ),
      ],
    );
  });

  group('setPassword / removePassword', () {
    blocTest<SecurityCubit, SecurityState>(
      'hashes the password and enables it',
      build: () => SecurityCubit(mockStorage, mockBiometric),
      act: (cubit) => cubit.setPassword('secret123'),
      expect: () => [
        predicate<SecurityState>(
          (s) =>
              s.settings.passwordEnabled &&
              s.settings.passwordHash == SecurityHasher.hash('secret123'),
        ),
      ],
    );

    blocTest<SecurityCubit, SecurityState>(
      'removes the password but keeps other settings intact',
      build: () => SecurityCubit(mockStorage, mockBiometric),
      seed: () => const SecurityState(
        settings: SecuritySettings(
          isEnabled: true,
          passwordEnabled: true,
          passwordHash: 'somehash',
          pinEnabled: true,
          pinHash: 'pinhash',
        ),
      ),
      act: (cubit) => cubit.removePassword(),
      expect: () => [
        predicate<SecurityState>(
          (s) =>
              !s.settings.passwordEnabled &&
              s.settings.passwordHash == null &&
              s.settings.isEnabled &&
              s.settings.pinEnabled &&
              s.settings.pinHash == 'pinhash',
        ),
      ],
    );
  });

  group('toggleBiometric', () {
    blocTest<SecurityCubit, SecurityState>(
      'enables biometric in settings',
      build: () => SecurityCubit(mockStorage, mockBiometric),
      act: (cubit) => cubit.toggleBiometric(true),
      expect: () => [predicate<SecurityState>((s) => s.settings.biometricEnabled)],
    );

    blocTest<SecurityCubit, SecurityState>(
      'disables biometric in settings',
      build: () => SecurityCubit(mockStorage, mockBiometric),
      seed: () => const SecurityState(settings: SecuritySettings(biometricEnabled: true)),
      act: (cubit) => cubit.toggleBiometric(false),
      expect: () => [predicate<SecurityState>((s) => !s.settings.biometricEnabled)],
    );
  });

  group('setLockTrigger', () {
    blocTest<SecurityCubit, SecurityState>(
      'updates the lock trigger',
      build: () => SecurityCubit(mockStorage, mockBiometric),
      act: (cubit) => cubit.setLockTrigger(LockTrigger.both),
      expect: () => [
        predicate<SecurityState>((s) => s.settings.lockTrigger == LockTrigger.both),
      ],
    );
  });

  group('setAutoLockMinutes', () {
    blocTest<SecurityCubit, SecurityState>(
      'updates the auto-lock duration',
      build: () => SecurityCubit(mockStorage, mockBiometric),
      act: (cubit) => cubit.setAutoLockMinutes(15),
      expect: () => [
        predicate<SecurityState>((s) => s.settings.autoLockMinutes == 15),
      ],
    );
  });

  group('resetSecurity', () {
    blocTest<SecurityCubit, SecurityState>(
      'clears storage and resets state back to defaults',
      build: () => SecurityCubit(mockStorage, mockBiometric),
      seed: () => const SecurityState(
        settings: SecuritySettings(isEnabled: true, pinEnabled: true),
        status: SecurityStatus.locked,
        failedAttempts: 3,
      ),
      act: (cubit) => cubit.resetSecurity(),
      expect: () => [const SecurityState()],
      verify: (_) {
        verify(() => mockStorage.clear()).called(1);
      },
    );
  });

  group('refreshBiometricAvailability', () {
    blocTest<SecurityCubit, SecurityState>(
      'updates biometricAvailable to true',
      build: () {
        when(() => mockBiometric.isAvailable).thenAnswer((_) async => true);
        return SecurityCubit(mockStorage, mockBiometric);
      },
      act: (cubit) => cubit.refreshBiometricAvailability(),
      expect: () => [predicate<SecurityState>((s) => s.biometricAvailable)],
    );

    blocTest<SecurityCubit, SecurityState>(
      'updates biometricAvailable to false',
      build: () => SecurityCubit(mockStorage, mockBiometric),
      seed: () => const SecurityState(biometricAvailable: true),
      act: (cubit) => cubit.refreshBiometricAvailability(),
      expect: () => [predicate<SecurityState>((s) => !s.biometricAvailable)],
    );
  });

  group('onAppPaused / onAppResumed (auto-lock)', () {
    blocTest<SecurityCubit, SecurityState>(
      'does nothing when security is disabled',
      build: () => SecurityCubit(mockStorage, mockBiometric),
      act: (cubit) {
        cubit.onAppPaused();
        cubit.onAppResumed();
      },
      expect: () => [],
    );

    blocTest<SecurityCubit, SecurityState>(
      'locks immediately when autoLockMinutes is 0 (elapsed >= threshold)',
      build: () => SecurityCubit(mockStorage, mockBiometric),
      seed: () => const SecurityState(
        settings: SecuritySettings(isEnabled: true, autoLockMinutes: 0),
        status: SecurityStatus.unlocked,
      ),
      act: (cubit) {
        cubit.onAppPaused();
        cubit.onAppResumed();
      },
      expect: () => [
        predicate<SecurityState>(
          (s) => s.status == SecurityStatus.locked && s.failedAttempts == 0,
        ),
      ],
    );

    blocTest<SecurityCubit, SecurityState>(
      'does not lock when the elapsed time is below the auto-lock threshold',
      build: () => SecurityCubit(mockStorage, mockBiometric),
      seed: () => const SecurityState(
        settings: SecuritySettings(isEnabled: true, autoLockMinutes: 5),
        status: SecurityStatus.unlocked,
      ),
      act: (cubit) {
        cubit.onAppPaused();
        cubit.onAppResumed();
      },
      expect: () => [],
    );

    blocTest<SecurityCubit, SecurityState>(
      'does nothing when resume is called without a prior pause',
      build: () => SecurityCubit(mockStorage, mockBiometric),
      seed: () => const SecurityState(
        settings: SecuritySettings(isEnabled: true, autoLockMinutes: 0),
        status: SecurityStatus.unlocked,
      ),
      act: (cubit) => cubit.onAppResumed(),
      expect: () => [],
    );

    blocTest<SecurityCubit, SecurityState>(
      'does nothing when already locked',
      build: () => SecurityCubit(mockStorage, mockBiometric),
      seed: () => const SecurityState(
        settings: SecuritySettings(isEnabled: true, autoLockMinutes: 0),
        status: SecurityStatus.locked,
      ),
      act: (cubit) {
        cubit.onAppPaused();
        cubit.onAppResumed();
      },
      expect: () => [],
    );
  });

  group('onScreenOff', () {
    blocTest<SecurityCubit, SecurityState>(
      'locks when the trigger is onScreenOff',
      build: () => SecurityCubit(mockStorage, mockBiometric),
      seed: () => const SecurityState(
        settings: SecuritySettings(isEnabled: true, lockTrigger: LockTrigger.onScreenOff),
        status: SecurityStatus.unlocked,
      ),
      act: (cubit) => cubit.onScreenOff(),
      expect: () => [predicate<SecurityState>((s) => s.status == SecurityStatus.locked)],
    );

    blocTest<SecurityCubit, SecurityState>(
      'locks when the trigger is both',
      build: () => SecurityCubit(mockStorage, mockBiometric),
      seed: () => const SecurityState(
        settings: SecuritySettings(isEnabled: true, lockTrigger: LockTrigger.both),
        status: SecurityStatus.unlocked,
      ),
      act: (cubit) => cubit.onScreenOff(),
      expect: () => [predicate<SecurityState>((s) => s.status == SecurityStatus.locked)],
    );

    blocTest<SecurityCubit, SecurityState>(
      'does not lock when the trigger is onAppClose only',
      build: () => SecurityCubit(mockStorage, mockBiometric),
      seed: () => const SecurityState(
        settings: SecuritySettings(isEnabled: true, lockTrigger: LockTrigger.onAppClose),
        status: SecurityStatus.unlocked,
      ),
      act: (cubit) => cubit.onScreenOff(),
      expect: () => [],
    );

    blocTest<SecurityCubit, SecurityState>(
      'does nothing when security is disabled',
      build: () => SecurityCubit(mockStorage, mockBiometric),
      act: (cubit) => cubit.onScreenOff(),
      expect: () => [],
    );
  });

  group('onAppClose', () {
    blocTest<SecurityCubit, SecurityState>(
      'locks when the trigger is onAppClose',
      build: () => SecurityCubit(mockStorage, mockBiometric),
      seed: () => const SecurityState(
        settings: SecuritySettings(isEnabled: true, lockTrigger: LockTrigger.onAppClose),
        status: SecurityStatus.unlocked,
      ),
      act: (cubit) => cubit.onAppClose(),
      expect: () => [predicate<SecurityState>((s) => s.status == SecurityStatus.locked)],
    );

    blocTest<SecurityCubit, SecurityState>(
      'locks when the trigger is both',
      build: () => SecurityCubit(mockStorage, mockBiometric),
      seed: () => const SecurityState(
        settings: SecuritySettings(isEnabled: true, lockTrigger: LockTrigger.both),
        status: SecurityStatus.unlocked,
      ),
      act: (cubit) => cubit.onAppClose(),
      expect: () => [predicate<SecurityState>((s) => s.status == SecurityStatus.locked)],
    );

    blocTest<SecurityCubit, SecurityState>(
      'does not lock when the trigger is onScreenOff only',
      build: () => SecurityCubit(mockStorage, mockBiometric),
      seed: () => const SecurityState(
        settings: SecuritySettings(isEnabled: true, lockTrigger: LockTrigger.onScreenOff),
        status: SecurityStatus.unlocked,
      ),
      act: (cubit) => cubit.onAppClose(),
      expect: () => [],
    );

    blocTest<SecurityCubit, SecurityState>(
      'does nothing when security is disabled',
      build: () => SecurityCubit(mockStorage, mockBiometric),
      act: (cubit) => cubit.onAppClose(),
      expect: () => [],
    );
  });
}
