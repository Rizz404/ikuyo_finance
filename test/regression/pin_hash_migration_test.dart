// Regression: A10. New PINs and passwords are stored as salted PBKDF2 hashes.
// Legacy unsalted SHA-256 hashes still unlock (no lockout) and are rehashed
// only after a successful unlock. A failed rehash write keeps the legacy hash,
// which still works.
// Real SecurityCubit + SecurityStorageService; only the platform secure
// storage and the biometric plugin are mocked/faked.
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/security/cubit/security_cubit.dart';
import 'package:ikuyo_finance/features/security/models/security_settings.dart';
import 'package:ikuyo_finance/features/security/services/biometric_service.dart';
import 'package:ikuyo_finance/features/security/services/security_storage_service.dart';
import 'package:ikuyo_finance/features/security/utils/security_hasher.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_logger.dart';

class _NoBiometrics extends Fake implements LocalAuthentication {
  @override
  Future<bool> get canCheckBiometrics async => false;
  @override
  Future<bool> isDeviceSupported() async => false;
}

/// Secure storage whose writes can be made to fail (reads stay real).
class _WriteFailingStorage extends Fake implements FlutterSecureStorage {
  bool failWrites = false;
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
  }) => _real.read(key: key);

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
  }) {
    if (failWrites) {
      throw PlatformException(code: 'keystore', message: 'write failed');
    }
    return _real.write(key: key, value: value);
  }
}

const _key = 'app_security_settings';

Future<SecuritySettings> _stored() async =>
    SecuritySettings.decode((await const FlutterSecureStorage().read(key: _key))!);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(bootstrapTestLogger);

  late SharedPreferences prefs;

  Future<SecurityCubit> boot(SecuritySettings settings,
      [FlutterSecureStorage storage = const FlutterSecureStorage()]) async {
    FlutterSecureStorage.setMockInitialValues({_key: settings.encode()});
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final cubit = SecurityCubit(
      SecurityStorageService(storage, prefs),
      BiometricService(_NoBiometrics()),
    );
    await pumpEventQueue();
    if (settings.isEnabled) {
      expect(cubit.state.status, SecurityStatus.locked);
    }
    return cubit;
  }

  test('setPin stores a salted hash, not the unsalted SHA-256', () async {
    final cubit = await boot(const SecuritySettings());
    await cubit.setPin('123456');
    final a = (await _stored()).pinHash!;
    await cubit.setPin('123456');
    final b = (await _stored()).pinHash!;

    expect(a, isNot(SecurityHasher.legacySha256('123456')));
    expect(a, isNot(b), reason: 'random salt per hash');
    expect(SecurityHasher.verify('123456', a), isTrue);
    expect(SecurityHasher.verify('654321', a), isFalse);
    expect(SecurityHasher.needsRehash(a), isFalse);
    await cubit.close();
  });

  test('legacy SHA-256 PIN unlocks and is rehashed after success', () async {
    final legacy = SecurityHasher.legacySha256('123456');
    final cubit = await boot(
      SecuritySettings(isEnabled: true, pinEnabled: true, pinHash: legacy),
    );

    cubit.authenticateWithPin('123456');
    await pumpEventQueue();

    expect(cubit.state.status, SecurityStatus.unlocked);
    final stored = (await _stored()).pinHash!;
    expect(stored, isNot(legacy));
    expect(SecurityHasher.needsRehash(stored), isFalse);
    expect(SecurityHasher.verify('123456', stored), isTrue);
    await cubit.close();
  });

  test('a wrong PIN against a legacy hash does not rehash', () async {
    final legacy = SecurityHasher.legacySha256('123456');
    final cubit = await boot(
      SecuritySettings(isEnabled: true, pinEnabled: true, pinHash: legacy),
    );

    cubit.authenticateWithPin('000000');
    await pumpEventQueue();

    expect(cubit.state.status, SecurityStatus.locked);
    expect((await _stored()).pinHash, legacy);
    await cubit.close();
  });

  test('legacy password unlocks and is rehashed after success', () async {
    final legacy = SecurityHasher.legacySha256('secret123');
    final cubit = await boot(
      SecuritySettings(
        isEnabled: true,
        passwordEnabled: true,
        passwordHash: legacy,
      ),
    );

    cubit.authenticateWithPassword('secret123');
    await pumpEventQueue();

    expect(cubit.state.status, SecurityStatus.unlocked);
    final stored = (await _stored()).passwordHash!;
    expect(stored, isNot(legacy));
    expect(SecurityHasher.needsRehash(stored), isFalse);
    expect(SecurityHasher.verify('secret123', stored), isTrue);
    await cubit.close();
  });

  test('a failed rehash write keeps the legacy hash usable (no lockout)',
      () async {
    final legacy = SecurityHasher.legacySha256('123456');
    final storage = _WriteFailingStorage();
    final cubit = await boot(
      SecuritySettings(isEnabled: true, pinEnabled: true, pinHash: legacy),
      storage,
    );
    storage.failWrites = true;

    cubit.authenticateWithPin('123456');
    await pumpEventQueue();

    expect(cubit.state.status, SecurityStatus.unlocked);
    expect((await _stored()).pinHash, legacy);

    // * Relaunch: legacy PIN still unlocks
    storage.failWrites = false;
    final relaunched = SecurityCubit(
      SecurityStorageService(storage, prefs),
      BiometricService(_NoBiometrics()),
    );
    await pumpEventQueue();
    relaunched.authenticateWithPin('123456');
    await pumpEventQueue();
    expect(relaunched.state.status, SecurityStatus.unlocked);
    await relaunched.close();
    await cubit.close();
  });
}
