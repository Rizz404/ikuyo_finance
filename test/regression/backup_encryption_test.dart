// Regression: A14 (portable backups were written as plaintext JSON).
// Portable export is a passphrase-encrypted envelope by default:
//   magic "IKYB" | format version | KDF id + Argon2id params | salt | nonce
//   | AES-256-GCM ciphertext+tag, with the whole header bound as AAD.
// Wrong passphrase, tampering and truncation fail closed before any data is
// parsed; legacy plaintext JSON still imports; plaintext export is opt-in.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';
import 'package:ikuyo_finance/features/backup/models/backup_data.dart';
import 'package:ikuyo_finance/features/backup/services/backup_crypto.dart';

import '../support/test_logger.dart';

const _pass = 'correct horse battery';

BackupData _data() {
  final now = DateTime(2026, 2, 1);
  return BackupData(
    version: BackupData.currentVersion,
    createdAt: now,
    appName: 'Ikuyo Finance',
    categories: [
      CategoryBackup(
        ulid: 'c1',
        name: 'SecretSalaryCategory',
        type: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    assets: [
      AssetBackup(
        ulid: 'a1',
        name: 'Bank',
        type: 0,
        balance: 123456,
        createdAt: now,
        updatedAt: now,
      ),
    ],
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

void main() {
  setUpAll(bootstrapTestLogger);

  late Uint8List envelope;
  setUpAll(() async {
    envelope = await BackupCrypto.encodeBackup(_data(), passphrase: _pass);
  });

  test(
    'round-trip: encrypted export decodes back to the same backup',
    () async {
      expect(BackupCrypto.detect(envelope), BackupFileFormat.encrypted);
      final decoded = await BackupCrypto.decodeBackup(
        envelope,
        passphrase: _pass,
      );
      expect(decoded.wasEncrypted, isTrue);
      expect(decoded.data.toJson(), _data().toJson());
    },
  );

  test(
    'envelope header: magic, version, Argon2id params, 16B salt, 12B nonce',
    () async {
      expect(ascii.decode(envelope.sublist(0, 4)), 'IKYB');
      final h = BackupEnvelopeHeader.parse(envelope);
      expect(h.formatVersion, BackupCrypto.formatVersion);
      expect(h.kdfId, 1);
      expect(h.memoryKiB, greaterThanOrEqualTo(19 * 1024));
      expect(h.iterations, greaterThanOrEqualTo(2));
      expect(h.parallelism, 1);
      expect(h.salt.length, 16);
      expect(h.nonce.length, 12);
      // ciphertext + 16-byte GCM tag follow the header
      expect(envelope.length, greaterThan(h.length + 16));
    },
  );

  test(
    'the envelope carries no plaintext and is randomised per export',
    () async {
      final text = latin1.decode(envelope);
      expect(text.contains('SecretSalaryCategory'), isFalse);
      expect(text.contains('123456'), isFalse);
      final again = await BackupCrypto.encodeBackup(_data(), passphrase: _pass);
      final a = BackupEnvelopeHeader.parse(envelope);
      final b = BackupEnvelopeHeader.parse(again);
      expect(a.salt, isNot(b.salt));
      expect(a.nonce, isNot(b.nonce));
    },
  );

  test('wrong passphrase fails closed with a clear error', () async {
    expect(
      await _errorOf(
        () =>
            BackupCrypto.decodeBackup(envelope, passphrase: 'wrong passphrase'),
      ),
      BackupCryptoError.wrongPassphraseOrTampered,
    );
    expect(
      await _errorOf(() => BackupCrypto.decodeBackup(envelope)),
      BackupCryptoError.passphraseRequired,
    );
  });

  test('a flipped ciphertext bit fails authentication', () async {
    final t = Uint8List.fromList(envelope);
    t[t.length - 20] ^= 0x01;
    expect(
      await _errorOf(() => BackupCrypto.decodeBackup(t, passphrase: _pass)),
      BackupCryptoError.wrongPassphraseOrTampered,
    );
  });

  test(
    'a tampered header (salt, nonce, version, KDF params) fails closed',
    () async {
      final h = BackupEnvelopeHeader.parse(envelope);
      final cases = <String, (int, BackupCryptoError)>{
        // salt starts after the fixed fields; nonce is the last header field
        'salt': (
          h.length - 12 - 1 - 16,
          BackupCryptoError.wrongPassphraseOrTampered,
        ),
        'nonce': (h.length - 1, BackupCryptoError.wrongPassphraseOrTampered),
        // F1: v1 accepts only the writer KDF profile, so a changed cost is
        // refused before the KDF instead of after an expensive derivation
        'iterations (pre-KDF profile check)': (
          13,
          BackupCryptoError.invalidParameters,
        ),
        'format version': (4, BackupCryptoError.unsupportedVersion),
        'kdf id': (5, BackupCryptoError.invalidParameters),
      };
      for (final entry in cases.entries) {
        final t = Uint8List.fromList(envelope);
        t[entry.value.$1] ^= 0x01;
        expect(
          await _errorOf(() => BackupCrypto.decodeBackup(t, passphrase: _pass)),
          entry.value.$2,
          reason: entry.key,
        );
      }
      // an absurd memory cost is refused before running the KDF (DoS guard)
      final huge = Uint8List.fromList(envelope);
      huge.setRange(6, 10, [0x7f, 0xff, 0xff, 0xff]);
      expect(
        await _errorOf(
          () => BackupCrypto.decodeBackup(huge, passphrase: _pass),
        ),
        BackupCryptoError.invalidParameters,
      );
    },
  );

  test('a truncated file fails closed', () async {
    final h = BackupEnvelopeHeader.parse(envelope);
    for (final len in [5, h.length - 1, h.length, h.length + 15]) {
      expect(
        await _errorOf(
          () => BackupCrypto.decodeBackup(
            envelope.sublist(0, len),
            passphrase: _pass,
          ),
        ),
        BackupCryptoError.truncated,
        reason: 'length $len',
      );
    }
    expect(
      await _errorOf(
        () => BackupCrypto.decodeBackup(
          envelope.sublist(0, envelope.length - 1),
          passphrase: _pass,
        ),
      ),
      BackupCryptoError.wrongPassphraseOrTampered,
    );
  });

  test('legacy plaintext JSON is detected and still imports without a '
      'passphrase', () async {
    final legacy = utf8.encode(
      '\uFEFF  ${_data().toJsonString().replaceFirst(BackupData.currentVersion, '1.0.0')}',
    );
    expect(BackupCrypto.detect(legacy), BackupFileFormat.legacyPlaintext);
    final decoded = await BackupCrypto.decodeBackup(legacy);
    expect(decoded.wasEncrypted, isFalse);
    expect(decoded.data.version, '1.0.0');
    expect(decoded.data.categories.single.name, 'SecretSalaryCategory');
  });

  test('non-backup bytes are rejected', () async {
    final junk = utf8.encode('hello');
    expect(BackupCrypto.detect(junk), BackupFileFormat.unknown);
    expect(
      await _errorOf(() => BackupCrypto.decodeBackup(junk)),
      BackupCryptoError.notABackup,
    );
    expect(
      await _errorOf(() => BackupCrypto.decodeBackup(utf8.encode('{"x":1}'))),
      BackupCryptoError.notABackup,
    );
  });

  test('unencrypted export only happens when no passphrase is given '
      '(explicit opt-out) and produces legacy-compatible JSON', () async {
    final plain = await BackupCrypto.encodeBackup(_data());
    expect(BackupCrypto.detect(plain), BackupFileFormat.legacyPlaintext);
    expect(
      BackupData.fromJsonString(utf8.decode(plain)).toJson(),
      _data().toJson(),
    );
  });

  test('a passphrase shorter than 8 characters is rejected', () async {
    expect(
      await _errorOf(
        () => BackupCrypto.encodeBackup(_data(), passphrase: '1234567'),
      ),
      BackupCryptoError.passphraseTooShort,
    );
    // 8 characters, multi-byte, is enough
    final ok = await BackupCrypto.encodeBackup(_data(), passphrase: 'äöüßäöüß');
    expect(BackupCrypto.detect(ok), BackupFileFormat.encrypted);
  });

  test('the backup format version is bumped for encryption-capable builds', () {
    expect(BackupData.currentVersion, '2.0.0');
  });

  test('neither the passphrase nor key material reaches the logs', () async {
    const secret = 'Pa55phrase-NeverLogged';
    final env = await BackupCrypto.encodeBackup(_data(), passphrase: secret);
    await BackupCrypto.decodeBackup(env, passphrase: secret);
    final err = await _errorOf(
      () => BackupCrypto.decodeBackup(env, passphrase: '$secret!'),
    );
    expect(err, isNotNull);
    expect(
      const BackupCryptoException(BackupCryptoError.truncated).toString(),
      isNot(contains(secret)),
    );
    final logs = talker.history
        .map((e) => '${e.message} ${e.exception} ${e.error}')
        .join('\n');
    expect(logs, isNot(contains(secret)));
    expect(
      logs,
      contains('BackupCrypto'),
      reason: 'operations are logged, without secrets',
    );
  });
}
