import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ikuyo_finance/core/config/supabase_config.dart';
import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/core/storage/secure_local_storage.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';
import 'package:ikuyo_finance/di/service_locator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talker_bloc_logger/talker_bloc_logger.dart';
import 'package:talker_flutter/talker_flutter.dart';

Future<void> setupCommons() async {
  _setupLogger();
  await _setupStorage();
  await _setupSupabase();
}

void _setupLogger() {
  initLogger();
  getIt.registerSingleton<Talker>(talker);

  // * Setup TalkerBlocObserver untuk auto-logging semua bloc events/states
  Bloc.observer = TalkerBlocObserver(
    talker: talker,
    settings: const TalkerBlocLoggerSettings(
      printEvents: true,
      printTransitions: true,
      printClosings: false,
      printCreations: false,
    ),
  );
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
