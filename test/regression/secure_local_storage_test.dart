// Regression: P05 / R10 (SecureLocalStorage lets platform keystore errors
// escape into Supabase auth and has no fallback-free failure policy). Only
// the OS keystore boundary (FlutterSecureStorage) is faked.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/core/storage/secure_local_storage.dart';
import 'package:ikuyo_finance/core/storage/storage_keys.dart';

import '../support/test_logger.dart';

class _Keystore extends Fake implements FlutterSecureStorage {
  final Map<String, String> values = {};
  bool failRead = false;
  bool failWrite = false;
  bool failDelete = false;

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
    if (failRead) throw Exception('keystore read failed');
    return values[key];
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
  }) async {
    if (failWrite) throw Exception('keystore write failed');
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failDelete) throw Exception('keystore delete failed');
    values.remove(key);
  }
}

void main() {
  setUpAll(bootstrapTestLogger);

  late _Keystore keystore;
  late SecureLocalStorage storage;
  setUp(() {
    keystore = _Keystore();
    storage = SecureLocalStorage(keystore);
  });

  test('a keystore read failure reports no session instead of throwing and '
      'never deletes the stored session', () async {
    keystore.values[StorageKeys.supabaseAuthToken] = 'session';
    keystore.failRead = true;
    expect(await storage.accessToken(), isNull);
    expect(await storage.hasAccessToken(), isFalse);
    expect(keystore.values[StorageKeys.supabaseAuthToken], 'session');
  });

  test('a keystore write failure does not throw into the auth client and '
      'writes nothing anywhere else', () async {
    keystore.failWrite = true;
    await storage.persistSession('session');
    expect(keystore.values, isEmpty);
  });

  test('a failed delete never leaves the old session readable', () async {
    keystore.values[StorageKeys.supabaseAuthToken] = 'session';
    keystore.failDelete = true;
    await storage.removePersistedSession();
    expect(await storage.accessToken(), isNull);
    expect(await storage.hasAccessToken(), isFalse);
  });

  test('a delete that fails twice surfaces the error', () async {
    keystore.values[StorageKeys.supabaseAuthToken] = 'session';
    keystore.failDelete = true;
    keystore.failWrite = true;
    await expectLater(storage.removePersistedSession(), throwsException);
  });

  test('normal round trip', () async {
    await storage.persistSession('session');
    expect(await storage.accessToken(), 'session');
    expect(await storage.hasAccessToken(), isTrue);
    await storage.removePersistedSession();
    expect(await storage.hasAccessToken(), isFalse);
  });
}
