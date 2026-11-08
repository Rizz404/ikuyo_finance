// Regression: review F2 (verify-ikuyo-delivery-20261107T123306Z). Portable
// backup import read the whole file with readAsBytes, then copied it again
// for decryption, with no size limit; export could produce any size. The
// documented maximum for a portable backup file is 32 MiB
// (BackupCrypto.maxBackupBytes). File length is checked before reading,
// the actual read is bounded again (a file can grow or lie about its
// length), and the codec refuses oversized input before detection,
// decryption or decoding. Export fails clearly instead of writing a file
// the app would refuse to import.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/backup/models/backup_data.dart';
import 'package:ikuyo_finance/features/backup/services/backup_crypto.dart';

import '../support/test_logger.dart';

const _pass = 'correct horse battery';
const _max = 32 * 1024 * 1024;

BackupData _data({String name = 'Food'}) {
  final now = DateTime(2026, 2, 1);
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

/// Backup whose UTF-8 JSON is exactly [bytes] long, using 2-byte 'é' so the
/// character count is well below the byte count.
BackupData _dataOfUtf8Length(int bytes) {
  final base = utf8.encode(_data(name: '').toJsonString()).length;
  final extra = bytes - base;
  final name = 'é' * (extra ~/ 2) + 'a' * (extra % 2);
  final data = _data(name: name);
  expect(utf8.encode(data.toJsonString()).length, bytes);
  expect(data.toJsonString().length, lessThan(bytes));
  return data;
}

/// Legacy plaintext JSON padded with trailing whitespace to [bytes] bytes.
Uint8List _legacyOfLength(int bytes) {
  final json = utf8.encode(_data(name: 'Héllo').toJsonString());
  final out = Uint8List(bytes)..fillRange(0, bytes, 0x20);
  out.setRange(0, json.length, json);
  return out;
}

Future<BackupCryptoError?> _errorOf(Future<Object?> Function() run) async {
  try {
    await run();
    return null;
  } on BackupCryptoException catch (e) {
    return e.error;
  }
}

class _Source {
  final int reportedLength;
  final int actualLength;
  int lengthCalls = 0;
  int openCalls = 0;
  int bytesEmitted = 0;
  bool cancelled = false;
  _Source(this.reportedLength, {int? actual})
    : actualLength = actual ?? reportedLength;

  Future<int> length() async {
    lengthCalls++;
    return reportedLength;
  }

  Stream<List<int>> openRead() {
    openCalls++;
    late StreamController<List<int>> c;
    var sent = 0;
    void pump() {
      while (sent < actualLength && !c.isPaused && !cancelled) {
        final n = (actualLength - sent).clamp(0, 1 << 20);
        sent += n;
        bytesEmitted += n;
        c.add(Uint8List(n)..fillRange(0, n, 0x20));
      }
      if (sent >= actualLength && !cancelled) c.close();
    }

    c = StreamController<List<int>>(
      onListen: pump,
      onResume: pump,
      onCancel: () => cancelled = true,
    );
    return c.stream;
  }
}

void main() {
  setUpAll(bootstrapTestLogger);

  test('the documented portable backup limit is 32 MiB', () {
    expect(BackupCrypto.maxBackupBytes, _max);
  });

  group('bounded file read', () {
    test(
      'a file reported over the limit is refused before opening it',
      () async {
        final src = _Source(_max + 1);
        expect(
          await _errorOf(
            () => BackupCrypto.readBounded(
              length: src.length,
              openRead: src.openRead,
            ),
          ),
          BackupCryptoError.tooLarge,
        );
        expect(src.lengthCalls, 1);
        expect(src.openCalls, 0, reason: 'no byte may be read');
      },
    );

    test('exactly the limit is read completely', () async {
      final src = _Source(_max);
      final bytes = await BackupCrypto.readBounded(
        length: src.length,
        openRead: src.openRead,
      );
      expect(bytes.length, _max);
    });

    test('a file that grows past the limit while reading is cut off and '
        'refused (actual read length re-checked)', () async {
      final src = _Source(10, actual: _max + 1);
      expect(
        await _errorOf(
          () => BackupCrypto.readBounded(
            length: src.length,
            openRead: src.openRead,
          ),
        ),
        BackupCryptoError.tooLarge,
      );
      expect(src.cancelled, isTrue);
      expect(src.bytesEmitted, lessThanOrEqualTo(_max + (1 << 20)));
    });
  });

  group('codec bounds', () {
    test('legacy JSON of exactly the limit decodes; one byte over is '
        'refused before decoding', () async {
      final ok = await BackupCrypto.decodeBackup(_legacyOfLength(_max));
      expect(ok.wasEncrypted, isFalse);
      expect(ok.data.categories.single.name, 'Héllo');
      expect(
        await _errorOf(
          () => BackupCrypto.decodeBackup(_legacyOfLength(_max + 1)),
        ),
        BackupCryptoError.tooLarge,
      );
    });

    test('an encrypted envelope over the limit is refused before the KDF '
        'or any copy', () async {
      final env = await BackupCrypto.encodeBackup(_data(), passphrase: _pass);
      final big = Uint8List(_max + 1)..setRange(0, env.length, env);
      final sw = Stopwatch()..start();
      expect(
        await _errorOf(() => BackupCrypto.decodeBackup(big, passphrase: _pass)),
        BackupCryptoError.tooLarge,
      );
      expect(
        await _errorOf(() => BackupCrypto.decrypt(big, _pass)),
        BackupCryptoError.tooLarge,
      );
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });

    test('truncated and malformed input still fails closed', () async {
      final legacy = utf8.encode(_data(name: 'Héllo').toJsonString());
      // cut inside the 2-byte 'é' and in the middle of the JSON
      final idx = legacy.indexOf(0xC3);
      expect(
        await _errorOf(
          () => BackupCrypto.decodeBackup(legacy.sublist(0, idx + 1)),
        ),
        BackupCryptoError.notABackup,
      );
      expect(
        await _errorOf(
          () =>
              BackupCrypto.decodeBackup(legacy.sublist(0, legacy.length ~/ 2)),
        ),
        BackupCryptoError.notABackup,
      );
      // invalid UTF-8 in otherwise JSON-looking input
      expect(
        await _errorOf(
          () => BackupCrypto.decodeBackup([0x7B, 0xFF, 0xFE, 0x7D]),
        ),
        BackupCryptoError.notABackup,
      );
      final env = await BackupCrypto.encodeBackup(_data(), passphrase: _pass);
      expect(
        await _errorOf(
          () =>
              BackupCrypto.decodeBackup(env.sublist(0, 30), passphrase: _pass),
        ),
        BackupCryptoError.truncated,
      );
    });
  });

  group('export bounds (UTF-8 bytes, not characters)', () {
    test('plaintext opt-out export of exactly the limit succeeds and the '
        'app can import it; one byte over fails clearly', () async {
      final ok = await BackupCrypto.encodeBackup(_dataOfUtf8Length(_max));
      expect(ok.length, _max);
      expect(
        (await BackupCrypto.decodeBackup(ok)).data.categories.single.name,
        startsWith('é'),
      );
      expect(
        await _errorOf(
          () => BackupCrypto.encodeBackup(_dataOfUtf8Length(_max + 1)),
        ),
        BackupCryptoError.exportTooLarge,
      );
    });

    test('encrypted export whose envelope would exceed the limit fails '
        'before deriving a key', () async {
      final overhead = BackupEnvelopeHeader.v1Length + 16;
      final sw = Stopwatch()..start();
      expect(
        await _errorOf(
          () => BackupCrypto.encodeBackup(
            _dataOfUtf8Length(_max - overhead + 1),
            passphrase: _pass,
          ),
        ),
        BackupCryptoError.exportTooLarge,
      );
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });

    test(
      'encrypted export of exactly the limit round-trips',
      () async {
        final overhead = BackupEnvelopeHeader.v1Length + 16;
        final data = _dataOfUtf8Length(_max - overhead);
        final env = await BackupCrypto.encodeBackup(data, passphrase: _pass);
        expect(env.length, _max);
        final decoded = await BackupCrypto.decodeBackup(env, passphrase: _pass);
        expect(
          decoded.data.categories.single.name,
          data.categories.single.name,
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
