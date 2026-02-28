import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';
import 'package:ikuyo_finance/features/security/models/security_settings.dart';

/// Service untuk menyimpan & membaca pengaturan keamanan via FlutterSecureStorage
class SecurityStorageService {
  static const String _key = 'app_security_settings';
  final FlutterSecureStorage _storage;

  SecurityStorageService(this._storage);

  Future<SecuritySettings> load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return const SecuritySettings();
      return SecuritySettings.decode(raw);
    } catch (e, s) {
      logError('Failed to load security settings', e, s);
      return const SecuritySettings();
    }
  }

  Future<void> save(SecuritySettings settings) async {
    try {
      await _storage.write(key: _key, value: settings.encode());
    } catch (e, s) {
      logError('Failed to save security settings', e, s);
      rethrow;
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (e, s) {
      logError('Failed to clear security settings', e, s);
    }
  }
}
