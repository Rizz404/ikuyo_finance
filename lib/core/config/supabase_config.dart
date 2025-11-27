import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  SupabaseConfig._();

  static String get url {
    final url = dotenv.env['SUPABASE_URL'];
    if (url == null || url.isEmpty) {
      throw Exception(
        'SUPABASE_URL tidak ditemukan di file .env. '
        'Pastikan file .env sudah dibuat dan berisi SUPABASE_URL',
      );
    }
    return url;
  }

  static String get anonKey {
    final key = dotenv.env['SUPABASE_ANON_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception(
        'SUPABASE_ANON_KEY tidak ditemukan di file .env. '
        'Pastikan file .env sudah dibuat dan berisi SUPABASE_ANON_KEY',
      );
    }
    return key;
  }
}
