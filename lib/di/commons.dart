import 'dart:async';

import 'package:flutter/foundation.dart';
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
import 'package:ikuyo_finance/core/extensions/logger_extension.dart';
import 'package:ikuyo_finance/di/service_locator.dart';
import 'package:ikuyo_finance/features/transaction/services/transaction_type_backfill.dart';
import 'package:ikuyo_finance/features/auto_transaction/repositories/auto_transaction_repository.dart';
import 'package:ikuyo_finance/features/auto_transaction/services/auto_transaction_alarm_service.dart';
import 'package:ikuyo_finance/features/auto_transaction/services/auto_transaction_background_task.dart';
import 'package:ikuyo_finance/features/auto_transaction/services/auto_transaction_notification_service.dart';
import 'package:ikuyo_finance/features/auto_transaction/services/auto_transaction_scheduler.dart';
import 'package:ikuyo_finance/features/backup/services/auto_backup_service.dart';
import 'package:ikuyo_finance/features/security/cubit/security_cubit.dart';
import 'package:ikuyo_finance/features/security/services/biometric_service.dart';
import 'package:ikuyo_finance/features/security/services/security_storage_service.dart';
import 'package:ikuyo_finance/features/auth/services/supabase_status_service.dart';
import 'package:ikuyo_finance/features/transaction/repositories/transaction_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talker_bloc_logger/talker_bloc_logger.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:workmanager/workmanager.dart';

Future<void> setupCommons() async {
  _setupLogger();
  await _setupStorage();
  await _setupSupabase();
  _setupSupabaseStatus();
  await _setupTheme();
}

void _setupLogger() {
  initLogger();
  getIt.registerSingleton<Talker>(talker);

  // * Setup TalkerBlocObserver untuk auto-logging semua bloc events/states
  Bloc.observer = TalkerBlocObserver(
    talker: talker,
    // * Event/transition memuat data keuangan; hanya di debug/profile (P04)
    settings: const TalkerBlocLoggerSettings(
      printEvents: !kReleaseMode,
      printTransitions: !kReleaseMode,
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

    // * Migrasi non-destruktif: isi arah transaksi untuk data lama
    try {
      TransactionTypeBackfill(objectBoxStorage).run();
    } catch (e, s) {
      talker.handle(e, s, 'Backfill arah transaksi gagal');
    }

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
  if (!SupabaseConfig.isConfigured) {
    talker.logWarning(
      'Supabase tidak dikonfigurasi — app berjalan tanpa cloud',
    );
    return;
  }

  final secureStorage = getIt<FlutterSecureStorage>();

  try {
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
  } catch (e, stack) {
    // ! Supabase init gagal (project dihapus / key tidak valid) — app
    // ! tetap berjalan dalam mode offline. SupabaseClient tidak terdaftar.
    talker.logError('Supabase init gagal — mode offline', e, stack);
  }
}

void _setupSupabaseStatus() {
  final client = getIt.isRegistered<SupabaseClient>()
      ? getIt<SupabaseClient>()
      : null;
  getIt.registerSingleton<SupabaseStatusService>(SupabaseStatusService(client));
}

Future<void> _setupTheme() async {
  final prefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(prefs);
  getIt.registerLazySingleton<ThemeCubit>(() => ThemeCubit(prefs));
  getIt.registerLazySingleton<LocaleCubit>(() => LocaleCubit(prefs));

  // * Security services & cubit
  final secureStorage = getIt<FlutterSecureStorage>();
  getIt.registerLazySingleton<SecurityStorageService>(
    () => SecurityStorageService(secureStorage, prefs),
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

Future<void> setupAutoTransactionServices() async {
  getIt.registerLazySingleton<AutoTransactionAlarmService>(
    () => AutoTransactionAlarmService(),
  );
  getIt.registerLazySingleton<AutoBackupService>(
    () => AutoBackupService(getIt<SharedPreferences>()),
  );
  getIt.registerLazySingleton<AutoTransactionNotificationService>(
    () => AutoTransactionNotificationService(),
  );
  getIt.registerLazySingleton<AutoTransactionScheduler>(
    () => AutoTransactionScheduler(
      repo: getIt<AutoTransactionRepository>(),
      transactionRepo: getIt<TransactionRepository>(),
      notifService: getIt<AutoTransactionNotificationService>(),
      alarmService: getIt<AutoTransactionAlarmService>(),
    ),
  );

  // * Layanan platform tidak boleh menggagalkan startup (CORE-1)
  await _guardStartup(
    'Inisialisasi notifikasi',
    () => getIt<AutoTransactionNotificationService>().initialize(),
  );
  await _guardStartup(
    'Izin notifikasi',
    () => getIt<AutoTransactionNotificationService>().requestPermission(),
  );

  final workmanagerReady = await _guardStartup(
    'Inisialisasi Workmanager',
    () => Workmanager().initialize(workmanagerCallbackDispatcher),
  );

  // * Pastikan task auto backup terdaftar (mis. setelah update / reinstall)
  // * tanpa mereset jadwal yang sudah berjalan
  final backupSettings = getIt<AutoBackupService>().loadSettings();
  if (workmanagerReady && backupSettings.isEnabled) {
    await _guardStartup(
      'Registrasi auto backup',
      () => getIt<AutoBackupService>().schedule(
        backupSettings,
        keepExisting: true,
      ),
    );
  }

  // * Eksekusi auto transaction di latar belakang (AUTO-8)
  if (workmanagerReady) {
    await _guardStartup(
      'Registrasi auto transaction background',
      AutoTransactionBackgroundTask.register,
    );
  }

  // * Pending auto transactions dijalankan sekali dari main.dart
}

Future<bool> _guardStartup(String label, Future<void> Function() action) async {
  try {
    await action();
    return true;
  } catch (e, s) {
    talker.handle(e, s, '$label gagal');
    return false;
  }
}
