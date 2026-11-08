// Regression: review F1 (verify-ikuyo-delivery-20261107T123306Z). The
// envelope header is read before authentication, so its Argon2id cost
// parameters are attacker-controlled. Format v1 accepted up to 256 MiB,
// 16 iterations and parallelism 4, letting a hostile file force a ~100x
// more expensive (and memory-hungry) KDF before failing. Header v1 now
// accepts only the writer profile (Argon2id, 19456 KiB, 2 iterations,
// parallelism 1); anything else fails closed before any derivation, and
// header parsing only touches the fixed 45-byte header.
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/backup/models/backup_data.dart';
import 'package:ikuyo_finance/features/backup/services/backup_crypto.dart';

import '../support/test_logger.dart';

const _pass = 'correct horse battery';

BackupData _data() => BackupData(
  version: BackupData.currentVersion,
  createdAt: DateTime(2026, 2, 1),
  appName: 'Ikuyo Finance',
  categories: const [],
  assets: const [],
  transactions: const [],
  budgets: const [],
);

Future<BackupCryptoError?> _errorOf(Future<Object?> Function() run) async {
  try {
    await run();
    return null;
  } on BackupCryptoException catch (e) {
    return e.error;
  }
}

BackupCryptoError? _parseError(List<int> bytes) {
  try {
    BackupEnvelopeHeader.parse(bytes);
    return null;
  } on BackupCryptoException catch (e) {
    return e.error;
  }
}

/// A byte list that fails the test if anything beyond the header is read
/// or the whole input is copied (e.g. Uint8List.fromList / toList).
class _HeaderOnlyList extends ListBase<int> {
  final Uint8List _bytes;
  final int _readable;
  _HeaderOnlyList(this._bytes, this._readable);

  @override
  int get length => _bytes.length;
  @override
  set length(int _) => throw UnsupportedError('fixed');
  @override
  int operator [](int index) {
    if (index >= _readable) {
      throw StateError('read past header at $index (whole-input copy)');
    }
    return _bytes[index];
  }

  @override
  void operator []=(int index, int value) => throw UnsupportedError('ro');
}

Uint8List _withParams(
  Uint8List envelope, {
  int? memoryKiB,
  int? iterations,
  int? parallelism,
}) {
  final t = Uint8List.fromList(envelope);
  final d = ByteData.sublistView(t);
  if (memoryKiB != null) d.setUint32(6, memoryKiB);
  if (iterations != null) d.setUint32(10, iterations);
  if (parallelism != null) d.setUint8(14, parallelism);
  return t;
}

void main() {
  setUpAll(bootstrapTestLogger);

  late Uint8List envelope;
  setUpAll(() async {
    envelope = await BackupCrypto.encodeBackup(_data(), passphrase: _pass);
  });

  test('the writer profile is Argon2id 19456 KiB, 2 iterations, p=1', () {
    final h = BackupEnvelopeHeader.parse(envelope);
    expect(h.kdfId, 1);
    expect(h.memoryKiB, 19456);
    expect(h.iterations, 2);
    expect(h.parallelism, 1);
    expect(h.length, 45);
  });

  test('header v1 rejects any KDF cost other than the writer profile '
      'while parsing, i.e. before any derivation', () {
    final cases = <String, Uint8List>{
      'reviewer max-cost 256 MiB/16/4': _withParams(
        envelope,
        memoryKiB: 256 * 1024,
        iterations: 16,
        parallelism: 4,
      ),
      'memory +1 KiB': _withParams(envelope, memoryKiB: 19457),
      'memory -1 KiB': _withParams(envelope, memoryKiB: 19455),
      'iterations 3': _withParams(envelope, iterations: 3),
      'iterations 1': _withParams(envelope, iterations: 1),
      'parallelism 2': _withParams(envelope, parallelism: 2),
      'parallelism 0': _withParams(envelope, parallelism: 0),
      'memory u32 max': _withParams(envelope, memoryKiB: 0xFFFFFFFF),
      'iterations u32 max': _withParams(envelope, iterations: 0xFFFFFFFF),
    };
    for (final entry in cases.entries) {
      expect(
        _parseError(entry.value),
        BackupCryptoError.invalidParameters,
        reason: entry.key,
      );
    }
  });

  test('a hostile max-cost header fails fast on decode instead of running '
      'the expensive KDF', () async {
    final hostile = _withParams(
      envelope,
      memoryKiB: 256 * 1024,
      iterations: 16,
      parallelism: 4,
    );
    final sw = Stopwatch()..start();
    final err = await _errorOf(
      () => BackupCrypto.decodeBackup(hostile, passphrase: _pass),
    );
    sw.stop();
    expect(err, BackupCryptoError.invalidParameters);
    // reviewer measured ~10.4 s for this header before the fix; a refusal
    // before derivation takes milliseconds
    expect(sw.elapsedMilliseconds, lessThan(1000));
  });

  test('header parsing reads only the 45-byte header, never copies the '
      'whole input', () async {
    final big = Uint8List(4096)..setRange(0, envelope.length, envelope);
    final h = BackupEnvelopeHeader.parse(_HeaderOnlyList(big, 45));
    expect(h.length, 45);
    final hostile = _withParams(big, memoryKiB: 256 * 1024);
    expect(
      _parseError(_HeaderOnlyList(hostile, 45)),
      BackupCryptoError.invalidParameters,
    );
    expect(
      await _errorOf(
        () => BackupCrypto.decrypt(_HeaderOnlyList(hostile, 45), _pass),
      ),
      BackupCryptoError.invalidParameters,
    );
  });

  test('default round-trip and tamper handling are unchanged', () async {
    final decoded = await BackupCrypto.decodeBackup(
      envelope,
      passphrase: _pass,
    );
    expect(decoded.data.toJson(), _data().toJson());
    final t = Uint8List.fromList(envelope);
    t[t.length - 20] ^= 0x01;
    expect(
      await _errorOf(() => BackupCrypto.decodeBackup(t, passphrase: _pass)),
      BackupCryptoError.wrongPassphraseOrTampered,
    );
    // salt and nonce remain AAD-bound
    for (final i in [20, 44]) {
      final s = Uint8List.fromList(envelope);
      s[i] ^= 0x01;
      expect(
        await _errorOf(() => BackupCrypto.decodeBackup(s, passphrase: _pass)),
        BackupCryptoError.wrongPassphraseOrTampered,
        reason: 'byte $i',
      );
    }
  });
}
