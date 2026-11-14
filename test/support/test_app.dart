import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ikuyo_finance/core/currency/cubit/currency_cubit.dart';
import 'package:ikuyo_finance/core/currency/service/currency_migration_service.dart';
import 'package:ikuyo_finance/core/currency/service/exchange_rate_service.dart';
import 'package:ikuyo_finance/core/locale/cubit/locale_cubit.dart';
import 'package:ikuyo_finance/core/router/app_router.dart';
import 'package:ikuyo_finance/core/router/router_listenables.dart';
import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/core/theme/cubit/theme_cubit.dart';
import 'package:ikuyo_finance/core/wrapper/failure.dart';
import 'package:ikuyo_finance/features/backup/models/backup_schedule_settings.dart';
import 'package:ikuyo_finance/features/asset/bloc/asset_bloc.dart';
import 'package:ikuyo_finance/features/asset/repositories/asset_repository_impl.dart';
import 'package:ikuyo_finance/features/auth/bloc/auth_bloc.dart';
import 'package:ikuyo_finance/features/auth/repositories/auth_repository.dart';
import 'package:ikuyo_finance/features/auth/services/supabase_status_service.dart';
import 'package:ikuyo_finance/features/auto_transaction/bloc/auto_transaction_bloc.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_group.dart';
import 'package:ikuyo_finance/features/auto_transaction/repositories/auto_transaction_repository_impl.dart';
import 'package:ikuyo_finance/features/auto_transaction/services/auto_transaction_alarm_service.dart';
import 'package:ikuyo_finance/features/backup/bloc/backup_bloc.dart';
import 'package:ikuyo_finance/features/backup/repositories/backup_repository_impl.dart';
import 'package:ikuyo_finance/features/backup/services/auto_backup_key_store.dart';
import 'package:ikuyo_finance/features/backup/services/auto_backup_service.dart';
import 'package:ikuyo_finance/features/budget/bloc/budget_bloc.dart';
import 'package:ikuyo_finance/features/budget/repositories/budget_repository_impl.dart';
import 'package:ikuyo_finance/features/category/bloc/category_bloc.dart';
import 'package:ikuyo_finance/features/category/repositories/category_repository_impl.dart';
import 'package:ikuyo_finance/features/export/bloc/export_bloc.dart';
import 'package:ikuyo_finance/features/export/repositories/export_repository_impl.dart';
import 'package:ikuyo_finance/features/security/cubit/security_cubit.dart';
import 'package:ikuyo_finance/features/security/models/security_settings.dart';
import 'package:ikuyo_finance/features/security/services/biometric_service.dart';
import 'package:ikuyo_finance/features/security/services/security_storage_service.dart';
import 'package:ikuyo_finance/features/statistic/bloc/statistic_bloc.dart';
import 'package:ikuyo_finance/features/transaction/bloc/transaction_bloc.dart';
import 'package:ikuyo_finance/features/transaction/repositories/transaction_repository_impl.dart';
import 'package:ikuyo_finance/main.dart'
    show AppDataSyncListener, AppSecurityWrapper;

import 'fake_app_file_storage.dart';
import 'objectbox_test_store.dart';
import 'test_logger.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockAutoTransactionAlarmService extends Mock
    implements AutoTransactionAlarmService {}

class MockAutoBackupService extends Mock implements AutoBackupService {}

class MockSecurityStorageService extends Mock
    implements SecurityStorageService {}

class MockBiometricService extends Mock implements BiometricService {}

/// Boots the REAL app widget tree (real [GoRouter] with every route, real
/// blocs, real repositories) against an ephemeral ObjectBox store — the
/// same pattern as `main.dart`'s `MyApp`, minus the pieces that need
/// platform services this test harness can't/shouldn't touch:
///   - Supabase is never initialized; auth is a mocked [AuthRepository] in
///     "signed out" mode, matching how the app already behaves offline.
///   - Auto-transaction alarms and scheduled backups are mocked — they're
///     Android AlarmManager/WorkManager side effects, not user-visible UI.
///   - Biometric auth reports "unavailable" (mirrors any emulator/device
///     without enrolled biometrics — the app's own designed fallback).
/// Everything else — every screen, every bloc, every repository, every
/// ObjectBox read/write triggered by real widget interaction — is
/// production code.
class TestApp {
  TestApp._(
    this._testStore,
    this.storage,
    this.router,
    this.categoryRepository,
    this.assetRepository,
    this.budgetRepository,
    this.transactionRepository,
    this.autoTransactionRepository,
    this.backupRepository,
    this.exportRepository,
    this.alarmService,
    this.securityStorageService,
    this.biometricService,
  );

  final ObjectBoxTestStore _testStore;
  final ObjectBoxStorage storage;
  final GoRouter router;

  final CategoryRepositoryImpl categoryRepository;
  final AssetRepositoryImpl assetRepository;
  final BudgetRepositoryImpl budgetRepository;
  final TransactionRepositoryImpl transactionRepository;
  final AutoTransactionRepositoryImpl autoTransactionRepository;
  final BackupRepositoryImpl backupRepository;
  final ExportRepositoryImpl exportRepository;

  final MockAutoTransactionAlarmService alarmService;
  final MockSecurityStorageService securityStorageService;
  final MockBiometricService biometricService;

  static bool _fallbackValuesRegistered = false;

  static void _registerFallbackValues() {
    if (_fallbackValuesRegistered) return;
    registerFallbackValue(
      AutoTransactionGroup(name: 'fallback', startDate: DateTime(2000)),
    );
    registerFallbackValue(const SecuritySettings());
    _fallbackValuesRegistered = true;
  }

  static Future<TestApp> boot() async {
    bootstrapTestLogger();
    _registerFallbackValues();

    final testStore = await ObjectBoxTestStore.open();
    final storage = testStore.storage;
    final fileStorage = FakeAppFileStorage();

    final categoryRepository = CategoryRepositoryImpl(storage, fileStorage);
    final assetRepository = AssetRepositoryImpl(storage, fileStorage);
    final budgetRepository = BudgetRepositoryImpl(storage);
    final transactionRepository = TransactionRepositoryImpl(storage);
    final autoTransactionRepository = AutoTransactionRepositoryImpl(storage);
    final backupRepository = BackupRepositoryImpl(storage);
    final exportRepository = ExportRepositoryImpl(storage);

    final alarmService = MockAutoTransactionAlarmService();
    when(() => alarmService.scheduleForGroup(any())).thenAnswer((_) async {});
    when(() => alarmService.cancelForGroup(any())).thenAnswer((_) async {});
    when(() => alarmService.cancelById(any())).thenAnswer((_) async {});

    final securityStorageService = MockSecurityStorageService();
    when(() => securityStorageService.load())
        .thenAnswer((_) async => const SecuritySettings());
    when(() => securityStorageService.save(any())).thenAnswer((_) async {});
    when(() => securityStorageService.lockEnabledHint).thenReturn(null);

    final biometricService = MockBiometricService();
    when(() => biometricService.isAvailable).thenAnswer((_) async => false);
    when(() => biometricService.isDeviceSupported)
        .thenAnswer((_) async => false);

    // * SupabaseStatusService(null) -> no session -> auth-gated redirects
    // * never fire; the app's own redirect logic only kicks people OUT of
    // * the sign-in screens when authenticated, it never forces sign-in.
    final authListenable = SupabaseAuthListenable(SupabaseStatusService(null));
    final router = createAppRouter(authListenable);

    return TestApp._(
      testStore,
      storage,
      router,
      categoryRepository,
      assetRepository,
      budgetRepository,
      transactionRepository,
      autoTransactionRepository,
      backupRepository,
      exportRepository,
      alarmService,
      securityStorageService,
      biometricService,
    );
  }

  void close() => _testStore.close();

  /// [resumeRun] mounts the real [AppSecurityWrapper] (as in `MyApp`) with
  /// that scheduler run injected, so lifecycle resume paths are testable.
  Widget build({
    Future<void> Function()? resumeRun,
    BackupScheduleSettings autoBackupSettings = const BackupScheduleSettings(),
    AutoBackupKeyState autoBackupKeyState = AutoBackupKeyState.missing,
    MockAutoBackupService? autoBackupServiceOverride,
  }) {
    final authRepository = MockAuthRepository();
    when(() => authRepository.authStateChanges)
        .thenAnswer((_) => const Stream.empty());
    when(() => authRepository.getCurrentUser()).thenAnswer(
      (_) => TaskEither.left(const Failure(message: 'Not authenticated')),
    );

    final autoBackupService =
        autoBackupServiceOverride ?? MockAutoBackupService();
    if (autoBackupServiceOverride == null) {
      when(() => autoBackupService.loadSettings())
          .thenReturn(autoBackupSettings);
      when(() => autoBackupService.keyState())
          .thenAnswer((_) async => autoBackupKeyState);
    }

    return EasyLocalization(
      supportedLocales: const [Locale('en', 'US'), Locale('id', 'ID')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en', 'US'),
      startLocale: const Locale('en', 'US'),
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (_) =>
                AuthBloc(authRepository)..add(const AuthCheckRequested()),
          ),
          BlocProvider<CategoryBloc>(
            create: (_) =>
                CategoryBloc(categoryRepository)..add(const CategoryFetched()),
          ),
          BlocProvider<AssetBloc>(
            create: (_) => AssetBloc(assetRepository)..add(const AssetFetched()),
          ),
          BlocProvider<BudgetBloc>(
            create: (_) => BudgetBloc(budgetRepository)..add(const BudgetFetched()),
          ),
          BlocProvider<TransactionBloc>(
            create: (_) => TransactionBloc(transactionRepository)
              ..add(const TransactionFetched()),
          ),
          BlocProvider<StatisticBloc>(
            create: (_) => StatisticBloc(transactionRepository),
          ),
          BlocProvider<BackupBloc>(
            create: (_) => BackupBloc(backupRepository, autoBackupService)
              ..add(BackupScheduleLoaded()),
          ),
          BlocProvider<ExportBloc>(create: (_) => ExportBloc(exportRepository)),
          BlocProvider<AutoTransactionBloc>(
            create: (_) =>
                AutoTransactionBloc(autoTransactionRepository, alarmService)
                  ..add(const AutoGroupFetched()),
          ),
          BlocProvider<SecurityCubit>(
            create: (_) => SecurityCubit(securityStorageService, biometricService),
          ),
        ],
        child: Builder(
          builder: (context) {
            return FutureBuilder<SharedPreferences>(
              future: SharedPreferences.getInstance(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const MaterialApp(
                    home: Scaffold(body: Center(child: CircularProgressIndicator())),
                  );
                }
                final prefs = snapshot.data!;
                return MultiBlocProvider(
                  providers: [
                    BlocProvider<ThemeCubit>(create: (_) => ThemeCubit(prefs)),
                    BlocProvider<LocaleCubit>(create: (_) => LocaleCubit(prefs)),
                    BlocProvider<CurrencyCubit>(
                      create: (_) => CurrencyCubit(
                        prefs,
                        CurrencyMigrationService(storage),
                        ExchangeRateService(prefs),
                      ),
                    ),
                  ],
                  // * Same cross-bloc listeners as MyApp
                  child: AppDataSyncListener(
                    child: BlocBuilder<ThemeCubit, ThemeState>(
                      builder: (context, themeState) {
                        return MaterialApp.router(
                          title: 'Ikuyo Finance',
                          theme: themeState.lightTheme,
                          darkTheme: themeState.darkTheme,
                          themeMode: themeState.themeMode,
                          routerConfig: router,
                          localizationsDelegates: context.localizationDelegates,
                          supportedLocales: context.supportedLocales,
                          locale: context.locale,
                          builder: resumeRun == null
                              ? null
                              : (context, child) => AppSecurityWrapper(
                                  runPendingExecutions: resumeRun,
                                  child: child!,
                                ),
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
