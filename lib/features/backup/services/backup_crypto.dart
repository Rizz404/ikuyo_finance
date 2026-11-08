import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';
import 'package:ikuyo_finance/features/backup/models/backup_data.dart';

enum BackupFileFormat { encrypted, legacyPlaintext, unknown }

enum BackupCryptoError {
  passphraseTooShort,
  passphraseRequired,
  wrongPassphraseOrTampered,
  truncated,
  unsupportedVersion,
  invalidParameters,
  notABackup,
}

/// Galat kripto backup; sengaja tidak membawa passphrase/kunci/isi file
class BackupCryptoException implements Exception {
  final BackupCryptoError error;

  const BackupCryptoException(this.error);

  @override
  String toString() => 'BackupCryptoException(${error.name})';
}

/// Header envelope backup terenkripsi (format v1, big-endian):
///   0  magic "IKYB" (4)
///   4  format version (1)
///   5  KDF id (1) — 1 = Argon2id v1.3
///   6  memory KiB (4)
///   10 iterations (4)
///   14 parallelism (1)
///   15 salt length (1) + salt (16)
///   32 nonce length (1) + nonce (12)
///   45 AES-256-GCM ciphertext || tag (16)
/// Seluruh header diikat sebagai AAD, jadi perubahan header gagal autentikasi.
class BackupEnvelopeHeader {
  final int formatVersion;
  final int kdfId;
  final int memoryKiB;
  final int iterations;
  final int parallelism;
  final Uint8List salt;
  final Uint8List nonce;
  final int length;

  const BackupEnvelopeHeader({
    required this.formatVersion,
    required this.kdfId,
    required this.memoryKiB,
    required this.iterations,
    required this.parallelism,
    required this.salt,
    required this.nonce,
    required this.length,
  });

  static const _fixedLength = 16;

  Uint8List encode() {
    final b = BytesBuilder()
      ..add(BackupCrypto._magic)
      ..addByte(formatVersion)
      ..addByte(kdfId)
      ..add(_u32(memoryKiB))
      ..add(_u32(iterations))
      ..addByte(parallelism)
      ..addByte(salt.length)
      ..add(salt)
      ..addByte(nonce.length)
      ..add(nonce);
    return b.toBytes();
  }

  static Uint8List _u32(int v) =>
      Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.big);

  /// Mem-parse dan memvalidasi header tanpa menyentuh ciphertext
  static BackupEnvelopeHeader parse(List<int> bytes) {
    if (bytes.length < _fixedLength) {
      throw const BackupCryptoException(BackupCryptoError.truncated);
    }
    for (var i = 0; i < 4; i++) {
      if (bytes[i] != BackupCrypto._magic[i]) {
        throw const BackupCryptoException(BackupCryptoError.notABackup);
      }
    }
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    final version = data.getUint8(4);
    if (version != BackupCrypto.formatVersion) {
      throw const BackupCryptoException(BackupCryptoError.unsupportedVersion);
    }
    var o = 15;
    final saltLength = data.getUint8(o++);
    if (bytes.length < o + saltLength + 1) {
      throw const BackupCryptoException(BackupCryptoError.truncated);
    }
    final salt = Uint8List.fromList(bytes.sublist(o, o + saltLength));
    o += saltLength;
    final nonceLength = data.getUint8(o++);
    if (bytes.length < o + nonceLength) {
      throw const BackupCryptoException(BackupCryptoError.truncated);
    }
    final nonce = Uint8List.fromList(bytes.sublist(o, o + nonceLength));
    o += nonceLength;

    final header = BackupEnvelopeHeader(
      formatVersion: version,
      kdfId: data.getUint8(5),
      memoryKiB: data.getUint32(6),
      iterations: data.getUint32(10),
      parallelism: data.getUint8(14),
      salt: salt,
      nonce: nonce,
      length: o,
    );
    header._validate();
    return header;
  }

  // * Batas atas mencegah file berbahaya memaksa KDF raksasa (DoS)
  void _validate() {
    final ok =
        kdfId == BackupCrypto._kdfArgon2id &&
        memoryKiB >= BackupCrypto._memoryKiB &&
        memoryKiB <= 256 * 1024 &&
        iterations >= BackupCrypto._iterations &&
        iterations <= 16 &&
        parallelism >= 1 &&
        parallelism <= 4 &&
        salt.length == BackupCrypto._saltLength &&
        nonce.length == BackupCrypto._nonceLength;
    if (!ok) {
      throw const BackupCryptoException(BackupCryptoError.invalidParameters);
    }
  }
}

class DecodedBackup {
  final BackupData data;
  final bool wasEncrypted;

  const DecodedBackup(this.data, {required this.wasEncrypted});
}

/// Enkripsi backup portabel berbasis passphrase pengguna (A14).
/// * Argon2id (19 MiB, 2 iterasi, paralelisme 1) → kunci 256-bit
/// * AES-256-GCM, nonce acak 12 byte, header sebagai AAD
/// * KDF + cipher berjalan di isolate terpisah, bukan isolate UI
/// * Passphrase & kunci tidak pernah dicatat; buffer byte di-nol-kan
class BackupCrypto {
  const BackupCrypto._();

  static const minPassphraseLength = 8;
  static const formatVersion = 1;
  static const fileExtension = 'ikuyo';

  static const _magic = [0x49, 0x4B, 0x59, 0x42]; // "IKYB"
  static const _kdfArgon2id = 1;
  static const _memoryKiB = 19 * 1024;
  static const _iterations = 2;
  static const _parallelism = 1;
  static const _saltLength = 16;
  static const _nonceLength = 12;
  static const _tagLength = 16;

  static BackupFileFormat detect(List<int> bytes) {
    if (bytes.length >= 4 &&
        bytes[0] == _magic[0] &&
        bytes[1] == _magic[1] &&
        bytes[2] == _magic[2] &&
        bytes[3] == _magic[3]) {
      return BackupFileFormat.encrypted;
    }
    var i = 0;
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      i = 3;
    }
    while (i < bytes.length &&
        const [0x20, 0x09, 0x0A, 0x0D].contains(bytes[i])) {
      i++;
    }
    return i < bytes.length && bytes[i] == 0x7B
        ? BackupFileFormat.legacyPlaintext
        : BackupFileFormat.unknown;
  }

  static void _checkPassphrase(String passphrase) {
    if (passphrase.runes.length < minPassphraseLength) {
      throw const BackupCryptoException(BackupCryptoError.passphraseTooShort);
    }
  }

  /// Ekspor portabel: terenkripsi bila [passphrase] diberikan; tanpa
  /// passphrase hanya untuk opt-out eksplisit (JSON polos format lama).
  static Future<Uint8List> encodeBackup(
    BackupData data, {
    String? passphrase,
  }) async {
    final json = data.toJsonString();
    if (passphrase == null) {
      talker.warning('[BackupCrypto] ekspor tanpa enkripsi (opt-out pengguna)');
      return Uint8List.fromList(utf8.encode(json));
    }
    return encrypt(json, passphrase);
  }

  /// Membaca file backup: dekripsi + parse penuh sebelum apa pun ditulis ke DB
  static Future<DecodedBackup> decodeBackup(
    List<int> bytes, {
    String? passphrase,
  }) async {
    final String json;
    final bool wasEncrypted;
    switch (detect(bytes)) {
      case BackupFileFormat.encrypted:
        if (passphrase == null || passphrase.isEmpty) {
          throw const BackupCryptoException(
            BackupCryptoError.passphraseRequired,
          );
        }
        json = await decrypt(bytes, passphrase);
        wasEncrypted = true;
      case BackupFileFormat.legacyPlaintext:
        talker.warning('[BackupCrypto] impor backup lama tanpa enkripsi');
        try {
          json = utf8.decode(bytes);
        } on FormatException {
          throw const BackupCryptoException(BackupCryptoError.notABackup);
        }
        wasEncrypted = false;
      case BackupFileFormat.unknown:
        throw const BackupCryptoException(BackupCryptoError.notABackup);
    }
    try {
      final text = json.startsWith('\uFEFF') ? json.substring(1) : json;
      return DecodedBackup(
        BackupData.fromJsonString(text),
        wasEncrypted: wasEncrypted,
      );
    } catch (_) {
      throw const BackupCryptoException(BackupCryptoError.notABackup);
    }
  }

  static Future<Uint8List> encrypt(String plaintext, String passphrase) async {
    _checkPassphrase(passphrase);
    final random = Random.secure();
    final header = BackupEnvelopeHeader(
      formatVersion: formatVersion,
      kdfId: _kdfArgon2id,
      memoryKiB: _memoryKiB,
      iterations: _iterations,
      parallelism: _parallelism,
      salt: _randomBytes(random, _saltLength),
      nonce: _randomBytes(random, _nonceLength),
      length: 0,
    );
    final headerBytes = header.encode();
    final passBytes = Uint8List.fromList(utf8.encode(passphrase));
    final clear = Uint8List.fromList(utf8.encode(plaintext));
    talker.info('[BackupCrypto] enkripsi backup (Argon2id + AES-256-GCM)');
    final sealed = await Isolate.run(
      () => _seal(passBytes, headerBytes, header, clear),
    );
    _zero(passBytes);
    _zero(clear);
    return sealed;
  }

  static Future<String> decrypt(List<int> bytes, String passphrase) async {
    final header = BackupEnvelopeHeader.parse(bytes);
    if (bytes.length < header.length + _tagLength + 1) {
      throw const BackupCryptoException(BackupCryptoError.truncated);
    }
    final envelope = Uint8List.fromList(bytes);
    final passBytes = Uint8List.fromList(utf8.encode(passphrase));
    talker.info('[BackupCrypto] dekripsi backup');
    try {
      final clear = await Isolate.run(() => _open(passBytes, envelope, header));
      try {
        return utf8.decode(clear);
      } on FormatException {
        throw const BackupCryptoException(BackupCryptoError.notABackup);
      } finally {
        _zero(clear);
      }
    } on BackupCryptoException catch (e) {
      talker.warning('[BackupCrypto] dekripsi gagal: ${e.error.name}');
      rethrow;
    } finally {
      _zero(passBytes);
    }
  }

  // ─── Isolate workers ──────────────────────────────────────────────────

  static Future<Uint8List> _seal(
    Uint8List passBytes,
    Uint8List headerBytes,
    BackupEnvelopeHeader header,
    Uint8List clear,
  ) async {
    final key = await _deriveKey(passBytes, header);
    try {
      final box = DartAesGcm.with256bits().encryptSync(
        clear,
        secretKeyData: key,
        nonce: header.nonce,
        aad: headerBytes,
      );
      return (BytesBuilder(copy: false)
            ..add(headerBytes)
            ..add(box.cipherText)
            ..add(box.mac.bytes))
          .toBytes();
    } finally {
      key.destroy();
      _zero(passBytes);
      _zero(clear);
    }
  }

  static Future<Uint8List> _open(
    Uint8List passBytes,
    Uint8List envelope,
    BackupEnvelopeHeader header,
  ) async {
    final key = await _deriveKey(passBytes, header);
    try {
      final headerBytes = envelope.sublist(0, header.length);
      final cipherText = envelope.sublist(
        header.length,
        envelope.length - _tagLength,
      );
      final mac = Mac(envelope.sublist(envelope.length - _tagLength));
      final clear = DartAesGcm.with256bits().decryptSync(
        SecretBox(cipherText, nonce: header.nonce, mac: mac),
        secretKeyData: key,
        aad: headerBytes,
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const BackupCryptoException(
        BackupCryptoError.wrongPassphraseOrTampered,
      );
    } finally {
      key.destroy();
      _zero(passBytes);
    }
  }

  static Future<SecretKeyData> _deriveKey(
    Uint8List passBytes,
    BackupEnvelopeHeader header,
  ) async {
    final kdf = DartArgon2id(
      parallelism: header.parallelism,
      memory: header.memoryKiB,
      iterations: header.iterations,
      hashLength: 32,
      maxIsolates: 0,
    );
    final derived = await kdf.deriveKey(
      secretKey: SecretKeyData(passBytes),
      nonce: header.salt,
    );
    final bytes = Uint8List.fromList(await derived.extractBytes());
    derived.destroy();
    return SecretKeyData(bytes, overwriteWhenDestroyed: true);
  }

  static Uint8List _randomBytes(Random random, int length) =>
      Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));

  static void _zero(Uint8List bytes) => bytes.fillRange(0, bytes.length, 0);
}
