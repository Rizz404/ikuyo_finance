import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Utility untuk hashing PIN & password
class SecurityHasher {
  SecurityHasher._();

  /// Hash string menggunakan SHA-256
  static String hash(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verifikasi input terhadap hash
  static bool verify(String input, String expectedHash) {
    return hash(input) == expectedHash;
  }
}
