import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ikuyo_finance/core/config/supabase_config.dart';
import 'package:ikuyo_finance/core/currency/cubit/currency_cubit.dart';
import 'package:ikuyo_finance/core/currency/service/currency_migration_service.dart';
import 'package:ikuyo_finance/core/currency/service/exchange_rate_service.dart';
import 'package:ikuyo_finance/core/locale/cubit/locale_cubit.dart';
import 'package:ikuyo_finance/core/service/app_file_storage.dart';
import 'package:ikuyo_finance/core/service/workmanager_dispatcher.dart';
import 'package:ikuyo_finance/core/storage/database_seeder.dart';
import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/core/storage/secure_local_storage.dart';
import 'package:ikuyo_finance/core/storage/storage_keys.dart';
import 'package:ikuyo_finance/core/theme/cubit/theme_cubit.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';
import 'package:ikuyo_finance/di/service_locator.dart';
import 'package:ikuyo_finance/features/auto_transaction/repositories/auto_transaction_repository.dart';
import 'package:ikuyo_finance/features/auto_transaction/services/auto_transaction_notification_service.dart';
import 'package:ikuyo_finance/features/auto_transaction/services/auto_transaction_scheduler.dart';
import 'package:ikuyo_finance/features/backup/services/auto_backup_service.dart';
import 'package:ikuyo_finance/features/security/cubit/security_cubit.dart';
import 'package:ikuyo_finance/features/security/service/biometric_service.dart';
import 'package:ikuyo_finance/features/security/service/security_storage_service.dart';
import 'package:ikuyo_finance/features/transaction/repositories/transaction_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talker_bloc_logger/talker_bloc_logger.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:workmanager/workmanager.dart';

Future<void> setupCommons() async {
  _setupLogger();
  await _setupStorage();
  await _setupSupabase();
  await _setupTheme();
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
  // * Register AppFileStorage for file operations
  getIt.registerSingleton<AppFileStorage>(const AppFileStorageImpl());

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

/// Seed data hanya sekali saat pertama kali install
Future<void> seedDatabaseIfNeeded() async {
  final prefs = getIt<SharedPreferences>();
  final hasSeeded = prefs.getBool(StorageKeys.databaseSeeded) ?? false;

  if (!hasSeeded) {
    final objectBoxStorage = await getIt.getAsync<ObjectBoxStorage>();
    final seeder = DatabaseSeeder(objectBoxStorage);
    await seeder.seedAll();

    await prefs.setBool(StorageKeys.databaseSeeded, true);
  }
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

Future<void> _setupTheme() async {
  final prefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(prefs);
  getIt.registerLazySingleton<ThemeCubit>(() => ThemeCubit(prefs));
  getIt.registerLazySingleton<LocaleCubit>(() => LocaleCubit(prefs));

  // * Security services & cubit
  final secureStorage = getIt<FlutterSecureStorage>();
  getIt.registerLazySingleton<SecurityStorageService>(
    () => SecurityStorageService(secureStorage),
  );
  getIt.registerLazySingleton<BiometricService>(() => BiometricService());
  getIt.registerLazySingleton<SecurityCubit>(
    () => SecurityCubit(
      getIt<SecurityStorageService>(),
      getIt<BiometricService>(),
    ),
  );
}

/// Setup currency after ObjectBox is ready
Future<void> setupCurrency() async {
  final prefs = getIt<SharedPreferences>();
  final objectBox = await getIt.getAsync<ObjectBoxStorage>();
  final migrationService = CurrencyMigrationService(objectBox);
  final exchangeRateService = ExchangeRateService(prefs);
  getIt.registerSingleton<CurrencyMigrationService>(migrationService);
  getIt.registerSingleton<ExchangeRateService>(exchangeRateService);
  getIt.registerLazySingleton<CurrencyCubit>(
    () => CurrencyCubit(prefs, migrationService, exchangeRateService),
  );
}

/// * Init notification service + Workmanager — dipanggil setelah setupRepositories & setupBlocs
Future<void> setupAutoTransactionServices() async {
  // * Register AutoBackupService singleton
  getIt.registerLazySingleton<AutoBackupService>(
    () => AutoBackupService(getIt<SharedPreferences>()),
  );

  // * Register notification service singleton
  getIt.registerLazySingleton<AutoTransactionNotificationService>(
    () => AutoTransactionNotificationService(),
  );

  // * Register scheduler singleton (depends on repos + notif service)
  getIt.registerLazySingleton<AutoTransactionScheduler>(
    () => AutoTransactionScheduler(
      repo: getIt<AutoTransactionRepository>(),
      transactionRepo: getIt<TransactionRepository>(),
      notifService: getIt<AutoTransactionNotificationService>(),
    ),
  );

  // * Init notification channels
  await getIt<AutoTransactionNotificationService>().initialize();

  // * Request notification permission from user
  await getIt<AutoTransactionNotificationService>().requestPermission();

  // * Init Workmanager dengan callback dispatcher
  await Workmanager().initialize(
    workmanagerCallbackDispatcher,
    isInDebugMode: kDebugMode,
  );

  // * Register periodic task — existingWorkPolicy.keep agar tidak tumpang tindih
  await Workmanager().registerPeriodicTask(
    autoTransactionTaskUniqueName,
    autoTransactionTaskName,
    frequency: const Duration(minutes: 15),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}
