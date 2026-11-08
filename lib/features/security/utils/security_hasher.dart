import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Utility untuk hashing PIN & password
///
/// * Format baru: `pbkdf2-sha256$<iterasi>$<salt b64>$<hash b64>` (salt acak).
/// * Format lama: hex SHA-256 tanpa salt; tetap diterima saat verifikasi dan
/// * di-rehash setelah autentikasi sukses (lihat [needsRehash]).
class SecurityHasher {
  SecurityHasher._();

  static const _scheme = 'pbkdf2-sha256';
  static const _iterations = 60000;
  static const _saltLength = 16;
  static final _random = Random.secure();

  /// Hash SHA-256 lama tanpa salt (hanya untuk kompatibilitas data lama)
  static String hash(String input) => legacySha256(input);

  static String legacySha256(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Hash bersalt untuk disimpan (PIN / password baru)
  static String hashSecret(String input) {
    final salt = Uint8List.fromList(
      List.generate(_saltLength, (_) => _random.nextInt(256)),
    );
    final derived = _pbkdf2(utf8.encode(input), salt, _iterations);
    return '$_scheme\$$_iterations\$${base64.encode(salt)}\$'
        '${base64.encode(derived)}';
  }

  /// True jika hash tersimpan masih format lama dan perlu di-rehash
  static bool needsRehash(String storedHash) =>
      !storedHash.startsWith('$_scheme\$');

  /// Verifikasi input terhadap hash (format baru maupun lama)
  static bool verify(String input, String expectedHash) {
    if (!expectedHash.startsWith('$_scheme\$')) {
      return _constantTimeEquals(
        utf8.encode(legacySha256(input)),
        utf8.encode(expectedHash),
      );
    }
    final parts = expectedHash.split('\$');
    if (parts.length != 4) return false;
    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations < 1) return false;
    try {
      final salt = base64.decode(parts[2]);
      final expected = base64.decode(parts[3]);
      final actual = _pbkdf2(utf8.encode(input), salt, iterations);
      return _constantTimeEquals(actual, expected);
    } on FormatException {
      return false;
    }
  }

  // * PBKDF2-HMAC-SHA256 dengan satu blok output (32 byte)
  static List<int> _pbkdf2(List<int> password, List<int> salt, int iterations) {
    final hmac = Hmac(sha256, password);
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final result = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return result;
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
