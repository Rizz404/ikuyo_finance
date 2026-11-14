import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';
import 'package:ikuyo_finance/features/backup/services/backup_crypto.dart';

enum AutoBackupKeyState { ready, missing, unreadable }

class AutoBackupKeyException implements Exception {
  final String reason;

  const AutoBackupKeyException(this.reason);

  @override
  String toString() => 'AutoBackupKeyException($reason)';
}

/// Penyimpanan kunci auto backup (salt + kunci Argon2id, bukan passphrase)
/// di secure storage. Tidak ada fallback ke penyimpanan lain: kunci yang
/// hilang/tidak terbaca berarti auto backup berhenti menulis (F10).
class AutoBackupKeyStore {
  // * Opsi sama dengan registrasi DI (commons.dart) agar isolate WorkManager
  // *   membaca item yang sama tanpa DI
  // * iOS: item ini harus terbaca oleh task latar belakang saat layar
  // *   terkunci (setelah unlock pertama) dan tidak ikut migrasi perangkat
  static const defaultSecureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const storageKey = 'auto_backup.key.v1';
  static const _version = 1;

  final FlutterSecureStorage _storage;

  const AutoBackupKeyStore([this._storage = defaultSecureStorage]);

  /// null bila belum di-setup; [AutoBackupKeyException] bila tidak terbaca
  /// atau rusak (tidak pernah dianggap "tidak ada" agar tidak tertimpa diam)
  Future<BackupKeyMaterial?> read() async {
    final String? raw;
    try {
      raw = await _storage.read(key: storageKey);
    } catch (e) {
      talker.error('[AutoBackupKeyStore] kunci tidak terbaca: ${e.runtimeType}');
      throw const AutoBackupKeyException('unreadable');
    }
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['v'] != _version) {
        throw const FormatException('version');
      }
      return BackupKeyMaterial(
        salt: base64Decode(json['salt'] as String),
        key: base64Decode(json['key'] as String),
      );
    } catch (_) {
      talker.error('[AutoBackupKeyStore] kunci tersimpan rusak');
      throw const AutoBackupKeyException('corrupt');
    }
  }

  Future<AutoBackupKeyState> state() async {
    try {
      final key = await read();
      if (key == null) return AutoBackupKeyState.missing;
      key.destroy();
      return AutoBackupKeyState.ready;
    } on AutoBackupKeyException {
      return AutoBackupKeyState.unreadable;
    }
  }

  /// Menyimpan lalu membaca ulang untuk verifikasi. Gagal = kunci sebelumnya
  /// tetap/dipulihkan bila ada dan terbaca, selain itu dibersihkan; error
  /// diteruskan. Hasil akhirnya selalu kunci baru, kunci lama, atau kosong.
  Future<void> save(BackupKeyMaterial material) async {
    BackupKeyMaterial? previous;
    try {
      previous = await read();
    } on AutoBackupKeyException {
      previous = null;
    }
    try {
      await _writeVerified(material);
    } catch (e) {
      talker.error(
        '[AutoBackupKeyStore] gagal menyimpan kunci: ${e.runtimeType}',
      );
      await _rollback(previous);
      if (e is AutoBackupKeyException) rethrow;
      throw const AutoBackupKeyException('write');
    } finally {
      previous?.destroy();
    }
  }

  Future<void> _rollback(BackupKeyMaterial? previous) async {
    if (previous != null) {
      try {
        final current = await read();
        final intact =
            current != null &&
            _equal(current.salt, previous.salt) &&
            _equal(current.key, previous.key);
        current?.destroy();
        if (intact) return;
      } catch (_) {}
      try {
        await _writeVerified(previous);
        return;
      } catch (_) {}
    }
    try {
      await clear();
    } catch (_) {}
  }

  Future<void> _writeVerified(BackupKeyMaterial material) async {
    await _storage.write(
      key: storageKey,
      value: jsonEncode({
        'v': _version,
        'salt': base64Encode(material.salt),
        'key': base64Encode(material.key),
      }),
    );
    final back = await read();
    final ok =
        back != null &&
        _equal(back.salt, material.salt) &&
        _equal(back.key, material.key);
    back?.destroy();
    if (!ok) throw const AutoBackupKeyException('verify');
  }

  /// Hapus kunci; bila delete gagal, timpa kosong. Gagal dua kali = error.
  Future<void> clear() async {
    try {
      await _storage.delete(key: storageKey);
    } catch (e) {
      talker.error('[AutoBackupKeyStore] gagal menghapus kunci: ${e.runtimeType}');
      await _storage.write(key: storageKey, value: '');
    }
  }

  static bool _equal(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
