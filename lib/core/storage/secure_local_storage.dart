import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SecureLocalStorage extends LocalStorage {
  final FlutterSecureStorage _secureStorage;

  SecureLocalStorage(this._secureStorage);

  @override
  Future<void> initialize() async {
    // * Cuma harus di init tanpa diisi
  }

  @override
  Future<String?> accessToken() async {
    return await _secureStorage.read(key: 'supabase.auth.token');
  }

  @override
  Future<bool> hasAccessToken() async {
    final token = await accessToken();
    return token != null;
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    await _secureStorage.write(
      key: 'supabase.auth.token',
      value: persistSessionString,
    );
  }

  @override
  Future<void> removePersistedSession() async {
    await _secureStorage.delete(key: 'supabase.auth.token');
  }
}
