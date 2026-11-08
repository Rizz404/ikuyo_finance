import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ikuyo_finance/core/extensions/logger_extension.dart';
import 'package:ikuyo_finance/features/security/models/security_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dilempar saat settings keamanan tidak bisa dibaca / di-decode.
/// Pemanggil wajib fail-closed (anggap terkunci) kecuali lock diketahui off.
class SecurityStorageReadException implements Exception {
  final Object cause;
  const SecurityStorageReadException(this.cause);

  /// Jenis error non-rahasia untuk diagnostik (tanpa isi settings).
  String get kind {
    final c = cause;
    if (c is PlatformException) return 'platform:${c.code}';
    if (c is FormatException || c is TypeError) return 'corrupt';
    return 'unknown:${c.runtimeType}';
  }

  @override
  String toString() => 'SecurityStorageReadException: $kind';
}

/// Service untuk menyimpan & membaca pengaturan keamanan via FlutterSecureStorage
class SecurityStorageService {
  static const String _key = 'app_security_settings';

  /// ? Penanda non-rahasia apakah app lock aktif, dipakai hanya untuk
  /// ? memutuskan fail-closed saat secure storage gagal dibaca.
  static const String lockEnabledHintKey = 'security_lock_enabled_hint';

  final FlutterSecureStorage _storage;
  final SharedPreferences? _prefs;

  SecurityStorageService(this._storage, [this._prefs]);

  /// Status lock terakhir yang diketahui (null = belum pernah tercatat).
  bool? get lockEnabledHint => _prefs?.getBool(lockEnabledHintKey);

  /// ! Melempar [SecurityStorageReadException] jika gagal baca/decode.
  Future<SecuritySettings> load() async {
    final SecuritySettings settings;
    try {
      final raw = await _storage.read(key: _key);
      settings = raw == null
          ? const SecuritySettings()
          : SecuritySettings.decode(raw);
    } catch (e, s) {
      logError('Failed to load security settings', e, s);
      throw SecurityStorageReadException(e);
    }
    await _writeHint(settings.isEnabled);
    return settings;
  }

  Future<void> save(SecuritySettings settings) async {
    try {
      await _storage.write(key: _key, value: settings.encode());
    } catch (e, s) {
      logError('Failed to save security settings', e, s);
      rethrow;
    }
    await _writeHint(settings.isEnabled);
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
      await _writeHint(false);
    } catch (e, s) {
      logError('Failed to clear security settings', e, s);
    }
  }

  /// ! Hapus HANYA settings app lock (bukan DB / secret lain). Dipanggil
  /// ! setelah autentikasi kredensial device berhasil. Melempar jika gagal.
  Future<void> resetLock() async {
    try {
      await _storage.delete(key: _key);
    } catch (e, s) {
      logError('Failed to delete security settings, overwriting', e, s);
      await _storage.write(key: _key, value: const SecuritySettings().encode());
    }
    await _writeHint(false);
  }

  Future<void> _writeHint(bool enabled) async {
    try {
      await _prefs?.setBool(lockEnabledHintKey, enabled);
    } catch (e, s) {
      logError('Failed to write security hint', e, s);
    }
  }
}
