// Regression: F10 (owner decision option B). The scheduled auto backup wrote
// plaintext JSON with no key. It now seals every file as a standard IKYB v1
// envelope (Argon2id v1 profile salt in the header, fresh random nonce per
// file, header bound as AAD) with a key derived once from the user's backup
// passphrase and cached (salt + key, never the passphrase) in secure
// storage. The files import on any device with the passphrase through the
// unchanged BackupCrypto.decodeBackup path. A missing, corrupt or
// unreadable key fails closed: no file of any kind is written. Only the OS
// keystore boundary (FlutterSecureStorage) and the notification sink are
// faked; crypto, key store and file writing are real. All keys/passphrases
// here are synthetic.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/backup/models/backup_data.dart';
import 'package:ikuyo_finance/features/backup/services/auto_backup_key_store.dart';
import 'package:ikuyo_finance/features/backup/services/auto_backup_service.dart';
import 'package:ikuyo_finance/features/backup/services/backup_crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_secure_storage.dart';
import '../support/test_logger.dart';

const _pass = 'synthetic auto passphrase';
const _otherPass = 'another synthetic phrase';
final _when = DateTime(2026, 3, 1, 2, 0, 0);

BackupData _data({String name = 'SecretAutoCategory'}) {
  final now = DateTime(2026, 3, 1);
  return BackupData(
    version: BackupData.currentVersion,
    createdAt: now,
    appName: 'Ikuyo Finance',
    categories: [
      CategoryBackup(
        ulid: 'c1',
        name: name,
        type: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    assets: const [],
    transactions: const [],
    budgets: const [],
  );
}

Future<BackupCryptoError?> _errorOf(Future<Object?> Function() run) async {
  try {
    await run();
    return null;
  } on BackupCryptoException catch (e) {
    return e.error;
  }
}

List<File> _files(Directory dir) => dir.existsSync()
    ? (dir.listSync().whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
    : <File>[];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(bootstrapTestLogger);

  late Directory root;
  late Directory dir;
  late FakeSecureStorage keystore;
  late AutoBackupKeyStore keyStore;
  late AutoBackupService service;
  late List<AutoBackupOutcome> notified;
  late int exports;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('ikuyo_f10_enc_');
    dir = Directory('${root.path}/Auto Backup');
    keystore = FakeSecureStorage();
    keyStore = AutoBackupKeyStore(keystore);
    SharedPreferences.setMockInitialValues({});
    service = AutoBackupService(await SharedPreferences.getInstance(), keyStore);
    notified = [];
    exports = 0;
  });
  tearDown(() => root.deleteSync(recursive: true));

  Future<AutoBackupOutcome> run({BackupData? data, DateTime? now}) =>
      AutoBackupService.runEncryptedBackup(
        keyStore: keyStore,
        exportData: () async {
          exports++;
          return data ?? _data();
        },
        resolveTargetDir: () async => dir,
        notifyFailure: (o) async => notified.add(o),
        now: now ?? _when,
      );

  group('worker output', () {
    test('is an IKYB v1 envelope that decodes with the passphrase on the '
        'unchanged import path; wrong passphrase and tampering fail '
        'closed', () async {
      await service.setupKey(_pass);
      expect(await run(), AutoBackupOutcome.written);

      final file = _files(dir).single;
      expect(file.path, endsWith('ikuyo_backup_20260301_020000.ikuyo'));
      final bytes = file.readAsBytesSync();
      expect(bytes.sublist(0, 4), utf8.encode('IKYB'));
      expect(BackupCrypto.detect(bytes), BackupFileFormat.encrypted);
      expect(latin1.decode(bytes).contains('SecretAutoCategory'), isFalse);
      final header = BackupEnvelopeHeader.parse(bytes);
      expect(header.formatVersion, 1);

      // * "another device": only the file + passphrase, no key store
      final decoded = await BackupCrypto.decodeBackup(bytes, passphrase: _pass);
      expect(decoded.wasEncrypted, isTrue);
      expect(decoded.data.categories.single.name, 'SecretAutoCategory');

      expect(
        await _errorOf(
          () => BackupCrypto.decodeBackup(bytes, passphrase: _otherPass),
        ),
        BackupCryptoError.wrongPassphraseOrTampered,
      );
      final tampered = Uint8List.fromList(bytes);
      tampered[tampered.length - 20] ^= 0x01;
      expect(
        await _errorOf(
          () => BackupCrypto.decodeBackup(tampered, passphrase: _pass),
        ),
        BackupCryptoError.wrongPassphraseOrTampered,
      );
      // * header (salt byte) is bound as AAD
      final headerTampered = Uint8List.fromList(bytes);
      headerTampered[20] ^= 0x01;
      expect(
        await _errorOf(
          () => BackupCrypto.decodeBackup(headerTampered, passphrase: _pass),
        ),
        BackupCryptoError.wrongPassphraseOrTampered,
      );
      expect(notified, isEmpty);
      expect(_files(dir).where((f) => f.path.endsWith('.json')), isEmpty);
      expect(_files(dir).where((f) => f.path.endsWith('.tmp')), isEmpty);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('every file uses the cached salt and a fresh random nonce', () async {
      await service.setupKey(_pass);
      final key = (await keyStore.read())!;
      final nonces = <String>{};
      for (var i = 0; i < 5; i++) {
        expect(
          await run(now: _when.add(Duration(minutes: i))),
          AutoBackupOutcome.written,
        );
      }
      final files = _files(dir);
      expect(files, hasLength(5));
      for (final f in files) {
        final h = BackupEnvelopeHeader.parse(f.readAsBytesSync());
        expect(h.salt, key.salt);
        nonces.add(base64Encode(h.nonce));
      }
      expect(nonces, hasLength(5));
      key.destroy();
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('fail closed without a usable key', () {
    Future<void> expectNothingWritten(AutoBackupOutcome expected) async {
      expect(await run(), expected);
      expect(_files(dir), isEmpty);
      expect(dir.existsSync(), isFalse);
      expect(exports, 0, reason: 'data must not even be exported');
      expect(notified, [expected]);
    }

    test('missing key (upgrade with schedule on, never set up) pauses: no '
        'file, no plaintext, user notified', () async {
      await expectNothingWritten(AutoBackupOutcome.keyMissing);
    });

    test('corrupt stored key: no file, no plaintext', () async {
      keystore.values[AutoBackupKeyStore.storageKey] = '{"v":1,"salt":"x"}';
      await expectNothingWritten(AutoBackupOutcome.keyUnreadable);
      expect(
        keystore.values[AutoBackupKeyStore.storageKey],
        '{"v":1,"salt":"x"}',
        reason: 'a corrupt key is never silently replaced',
      );
    });

    test('wrong-length stored key: no file, no plaintext', () async {
      keystore.values[AutoBackupKeyStore.storageKey] = jsonEncode({
        'v': 1,
        'salt': base64Encode(List.filled(16, 1)),
        'key': base64Encode(List.filled(16, 2)),
      });
      await expectNothingWritten(AutoBackupOutcome.keyUnreadable);
    });

    test('unknown key record version: no file, no plaintext', () async {
      keystore.values[AutoBackupKeyStore.storageKey] = jsonEncode({
        'v': 2,
        'salt': base64Encode(List.filled(16, 1)),
        'key': base64Encode(List.filled(32, 2)),
      });
      await expectNothingWritten(AutoBackupOutcome.keyUnreadable);
    });

    test('keystore read failure: no file, no plaintext', () async {
      await service.setupKey(_pass);
      keystore.failRead = true;
      await expectNothingWritten(AutoBackupOutcome.keyUnreadable);
    }, timeout: const Timeout(Duration(minutes: 1)));

    test('an export failure writes nothing and keeps earlier backups', () async {
      await service.setupKey(_pass);
      dir.createSync(recursive: true);
      File('${dir.path}/ikuyo_backup_20250101_020000.json')
          .writeAsStringSync('{"legacy":true}');
      final outcome = await AutoBackupService.runEncryptedBackup(
        keyStore: keyStore,
        exportData: () async => throw StateError('db'),
        resolveTargetDir: () async => dir,
        notifyFailure: (o) async => notified.add(o),
      );
      expect(outcome, AutoBackupOutcome.failed);
      expect(_files(dir).map((f) => f.uri.pathSegments.last), [
        'ikuyo_backup_20250101_020000.json',
      ]);
      expect(notified, [AutoBackupOutcome.failed]);
    }, timeout: const Timeout(Duration(minutes: 1)));
  });

  group('key storage', () {
    test('stores only salt + derived key, never the passphrase; each setup '
        'uses a fresh random salt', () async {
      await service.setupKey(_pass);
      final raw1 = keystore.values[AutoBackupKeyStore.storageKey]!;
      expect(raw1.contains(_pass), isFalse);
      final rec1 = jsonDecode(raw1) as Map<String, dynamic>;
      expect(rec1.keys.toSet(), {'v', 'salt', 'key'});
      expect(base64Decode(rec1['salt'] as String), hasLength(16));
      expect(base64Decode(rec1['key'] as String), hasLength(32));

      await service.setupKey(_pass);
      final rec2 =
          jsonDecode(keystore.values[AutoBackupKeyStore.storageKey]!)
              as Map<String, dynamic>;
      expect(rec2['salt'], isNot(rec1['salt']));
      expect(rec2['key'], isNot(rec1['key']));
    }, timeout: const Timeout(Duration(minutes: 1)));

    test('a too-short passphrase is refused and nothing is stored', () async {
      await expectLater(
        service.setupKey('1234567'),
        throwsA(isA<BackupCryptoException>()),
      );
      expect(keystore.values, isEmpty);
    });

    test('write failure on first setup leaves no key (no half state)',
        () async {
      keystore.failWrite = true;
      await expectLater(
        service.setupKey(_pass),
        throwsA(isA<AutoBackupKeyException>()),
      );
      expect(keystore.values, isEmpty);
      expect(await keyStore.state(), AutoBackupKeyState.missing);
      expect(await run(), AutoBackupOutcome.keyMissing);
      expect(_files(dir), isEmpty);
    }, timeout: const Timeout(Duration(minutes: 1)));

    test('a write that does not persist fails verification and is rolled '
        'back', () async {
      keystore.dropWrites = true;
      await expectLater(
        service.setupKey(_pass),
        throwsA(isA<AutoBackupKeyException>()),
      );
      expect(keystore.values, isEmpty);
    }, timeout: const Timeout(Duration(minutes: 1)));

    test('a failed passphrase change keeps the previous working key',
        () async {
      await service.setupKey(_pass);
      final before = keystore.values[AutoBackupKeyStore.storageKey];
      keystore.failWrite = true;
      await expectLater(
        service.setupKey(_otherPass),
        throwsA(isA<AutoBackupKeyException>()),
      );
      expect(keystore.values[AutoBackupKeyStore.storageKey], before);
      keystore.failWrite = false;
      expect(await run(), AutoBackupOutcome.written);
      final bytes = _files(dir).single.readAsBytesSync();
      final decoded = await BackupCrypto.decodeBackup(bytes, passphrase: _pass);
      expect(decoded.data.categories, hasLength(1));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('after a passphrase change, older files still need the old '
        'passphrase and new files the new one', () async {
      await service.setupKey(_pass);
      expect(await run(now: _when), AutoBackupOutcome.written);
      await service.setupKey(_otherPass);
      expect(
        await run(now: _when.add(const Duration(days: 1))),
        AutoBackupOutcome.written,
      );
      final files = _files(dir);
      expect(files, hasLength(2));
      final oldBytes = files.first.readAsBytesSync();
      final newBytes = files.last.readAsBytesSync();
      expect(
        (await BackupCrypto.decodeBackup(oldBytes, passphrase: _pass))
            .wasEncrypted,
        isTrue,
      );
      expect(
        await _errorOf(
          () => BackupCrypto.decodeBackup(oldBytes, passphrase: _otherPass),
        ),
        BackupCryptoError.wrongPassphraseOrTampered,
      );
      expect(
        (await BackupCrypto.decodeBackup(newBytes, passphrase: _otherPass))
            .wasEncrypted,
        isTrue,
      );
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('clearing the key (disable) makes the worker pause again', () async {
      await service.setupKey(_pass);
      await service.clearKey();
      expect(keystore.values.containsKey(AutoBackupKeyStore.storageKey),
          isFalse);
      expect(await keyStore.state(), AutoBackupKeyState.missing);
      expect(await run(), AutoBackupOutcome.keyMissing);
      expect(_files(dir), isEmpty);
    }, timeout: const Timeout(Duration(minutes: 1)));

    test('a failed delete overwrites the key so it cannot be used', () async {
      await service.setupKey(_pass);
      keystore.failDelete = true;
      await service.clearKey();
      expect(await keyStore.state(), AutoBackupKeyState.missing);
    }, timeout: const Timeout(Duration(minutes: 1)));

    test('runBackup on the default secure storage: no key pauses without a '
        'WorkManager retry (true); a corrupt key reports failure (false)',
        () async {
      FlutterSecureStorage.setMockInitialValues({});
      expect(await AutoBackupService.runBackup(), isTrue);
      FlutterSecureStorage.setMockInitialValues({
        AutoBackupKeyStore.storageKey: 'not json',
      });
      expect(await AutoBackupService.runBackup(), isFalse);
    });
  });

  group('NEW-1 size bound on the sealed size', () {
    test('sealed size exactly at the limit is written; one byte more is '
        'refused with nothing written and no pruning', () async {
      final key = BackupKeyMaterial(
        salt: List.generate(16, (i) => i),
        key: List.generate(32, (i) => 255 - i),
      );
      final base = utf8.encode(_data(name: '').toJsonString()).length;
      final fit = BackupCrypto.maxBackupBytes - BackupCrypto.envelopeOverhead;

      dir.createSync(recursive: true);
      final legacy = File('${dir.path}/ikuyo_backup_20250101_020000.json')
        ..writeAsStringSync('{"legacy":true}');

      final over = _data(name: 'a' * (fit - base + 1));
      expect(
        utf8.encode(over.toJsonString()).length + BackupCrypto.envelopeOverhead,
        BackupCrypto.maxBackupBytes + 1,
      );
      expect(
        await AutoBackupService.writeBackupFile(dir, over, key, now: _when),
        isNull,
      );
      expect(_files(dir).map((f) => f.uri.pathSegments.last), [
        'ikuyo_backup_20250101_020000.json',
      ]);

      final exact = _data(name: 'a' * (fit - base));
      final path = await AutoBackupService.writeBackupFile(
        dir,
        exact,
        key,
        now: _when,
      );
      expect(path, isNotNull);
      expect(File(path!).lengthSync(), BackupCrypto.maxBackupBytes);
      final raf = File(path).openSync();
      final head = raf.readSync(4);
      raf.closeSync();
      expect(BackupCrypto.detect(head), BackupFileFormat.encrypted);
      expect(legacy.readAsStringSync(), '{"legacy":true}');
      key.destroy();
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('worker reports tooLarge and writes nothing', () async {
      await service.setupKey(_pass);
      final fit = BackupCrypto.maxBackupBytes - BackupCrypto.envelopeOverhead;
      expect(
        await run(data: _data(name: 'a' * (fit + 1))),
        AutoBackupOutcome.tooLarge,
      );
      expect(_files(dir), isEmpty);
      expect(notified, [AutoBackupOutcome.tooLarge]);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('retention with legacy files', () {
    test('the worker rotates only encrypted files and never touches the 12 '
        'legacy .json backups', () async {
      dir.createSync(recursive: true);
      final legacy = <String, String>{};
      for (var i = 1; i <= 12; i++) {
        final d = i.toString().padLeft(2, '0');
        final name = 'ikuyo_backup_202501${d}_020000.json';
        File('${dir.path}/$name').writeAsStringSync('{"legacy":$i}');
        legacy[name] = '{"legacy":$i}';
      }
      await service.setupKey(_pass);
      for (var i = 0; i < 12; i++) {
        expect(
          await run(now: _when.add(Duration(days: i))),
          AutoBackupOutcome.written,
        );
      }
      final files = _files(dir);
      expect(files.where((f) => f.path.endsWith('.ikuyo')), hasLength(10));
      for (final e in legacy.entries) {
        expect(File('${dir.path}/${e.key}').readAsStringSync(), e.value);
      }
      expect(
        files.map((f) => f.uri.pathSegments.last),
        isNot(contains('ikuyo_backup_20260301_020000.ikuyo')),
      );
      expect(
        files.map((f) => f.uri.pathSegments.last),
        contains('ikuyo_backup_20260312_020000.ikuyo'),
      );
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
