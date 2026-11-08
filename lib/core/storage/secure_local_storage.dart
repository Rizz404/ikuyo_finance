import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ikuyo_finance/core/storage/storage_keys.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';

/// Penyimpanan sesi Supabase di keystore. Kegagalan keystore tidak pernah
/// dialihkan ke penyimpanan tidak aman: baca gagal = tidak ada sesi (login
/// ulang), tulis gagal = sesi tidak dipersist, hapus gagal = sesi ditimpa
/// kosong agar tidak bisa dipakai lagi.
class SecureLocalStorage extends LocalStorage {
  final FlutterSecureStorage _secureStorage;

  SecureLocalStorage(this._secureStorage);

  @override
  Future<void> initialize() async {
    // * Cuma harus di init tanpa diisi
  }

  @override
  Future<String?> accessToken() async {
    try {
      final token = await _secureStorage.read(
        key: StorageKeys.supabaseAuthToken,
      );
      if (token == null || token.isEmpty) return null;
      return token;
    } catch (e, s) {
      talker.error('[SecureLocalStorage] Gagal membaca sesi', e, s);
      return null;
    }
  }

  @override
  Future<bool> hasAccessToken() async {
    final token = await accessToken();
    return token != null;
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    try {
      await _secureStorage.write(
        key: StorageKeys.supabaseAuthToken,
        value: persistSessionString,
      );
    } catch (e, s) {
      talker.error('[SecureLocalStorage] Gagal menyimpan sesi', e, s);
    }
  }

  @override
  Future<void> removePersistedSession() async {
    try {
      await _secureStorage.delete(key: StorageKeys.supabaseAuthToken);
    } catch (e, s) {
      talker.error('[SecureLocalStorage] Gagal menghapus sesi', e, s);
      // * Timpa dengan nilai kosong; bila ini juga gagal, sesi lama masih
      // * ada sehingga error harus diteruskan ke pemanggil
      await _secureStorage.write(
        key: StorageKeys.supabaseAuthToken,
        value: '',
      );
    }
  }
}
