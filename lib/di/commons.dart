import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:ikuyo_finance/core/config/supabase_config.dart';
import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/core/storage/secure_local_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final getIt = GetIt.instance;

Future<void> setupCommons() async {
  await _setupStorage();
  await _setupSupabase();
}

Future<void> _setupStorage() async {
  const flutterSecureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  getIt.registerSingleton<FlutterSecureStorage>(flutterSecureStorage);

  getIt.registerSingletonAsync<ObjectBoxStorage>(() async {
    final objectBoxStorage = ObjectBoxStorage();
    await objectBoxStorage.init();
    return objectBoxStorage;
  });
}

Future<void> _setupSupabase() async {
  final secureStorage = getIt<FlutterSecureStorage>();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    authOptions: FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      localStorage: SecureLocalStorage(secureStorage),
    ),
    realtimeClientOptions: const RealtimeClientOptions(
      logLevel: RealtimeLogLevel.info,
    ),
  );

  getIt.registerSingleton<SupabaseClient>(Supabase.instance.client);
}
