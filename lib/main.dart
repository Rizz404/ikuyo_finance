import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:ikuyo_finance/core/currency/cubit/currency_cubit.dart';
import 'package:ikuyo_finance/core/locale/cubit/locale_cubit.dart';
import 'package:ikuyo_finance/core/theme/cubit/theme_cubit.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';
import 'package:ikuyo_finance/di/injection.dart';
import 'package:ikuyo_finance/features/auth/bloc/auth_bloc.dart';
import 'package:ikuyo_finance/features/backup/bloc/backup_bloc.dart';
import 'package:ikuyo_finance/features/budget/bloc/budget_bloc.dart';
import 'package:ikuyo_finance/features/category/bloc/category_bloc.dart';
import 'package:ikuyo_finance/features/security/cubit/security_cubit.dart';
import 'package:ikuyo_finance/features/security/screens/lock_screen.dart';
import 'package:ikuyo_finance/features/statistic/bloc/statistic_bloc.dart';
import 'package:ikuyo_finance/features/transaction/bloc/transaction_bloc.dart';
import 'package:ikuyo_finance/features/asset/bloc/asset_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  await EasyLocalization.ensureInitialized();
  await initializeDateFormatting();
  await setupDependencies();

  talker.logInfo('Ikuyo Finance started');

  runApp(
    EasyLocalization(
      supportedLocales: LocaleCubit.supportedLocales,
      path: 'assets/translations',
      fallbackLocale: const Locale('en', 'US'),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getIt<AuthBloc>()..add(const AuthCheckRequested()),
        ),
        BlocProvider(
          create: (_) => getIt<CategoryBloc>()..add(const CategoryFetched()),
        ),
        BlocProvider(
          create: (_) => getIt<AssetBloc>()..add(const AssetFetched()),
        ),
        BlocProvider(
          create: (_) => getIt<BudgetBloc>()..add(const BudgetFetched()),
        ),
        BlocProvider(
          create: (_) =>
              getIt<TransactionBloc>()..add(const TransactionFetched()),
        ),
        BlocProvider(create: (_) => getIt<StatisticBloc>()),
        BlocProvider(create: (_) => getIt<BackupBloc>()),
        BlocProvider(create: (_) => getIt<ThemeCubit>()),
        BlocProvider(create: (_) => getIt<CurrencyCubit>()),
        BlocProvider(create: (_) => getIt<LocaleCubit>()),
        BlocProvider(create: (_) => getIt<SecurityCubit>()),
      ],
      // * Use BlocListener for loose coupling between blocs (best practice)
      child: MultiBlocListener(
        listeners: [
          BlocListener<TransactionBloc, TransactionState>(
            listenWhen: (previous, current) =>
                previous.writeStatus != current.writeStatus &&
                current.writeStatus == TransactionWriteStatus.success,
            listener: (context, state) {
              // * Refresh asset list when transaction write succeeds
              context.read<AssetBloc>().add(const AssetRefreshed());
            },
          ),
          BlocListener<BackupBloc, BackupState>(
            listenWhen: (previous, current) =>
                previous.status != current.status &&
                current.status == BackupStatus.success,
            listener: (context, state) {
              // * Refetch all data blocs after successful backup import
              context.read<CategoryBloc>().add(const CategoryFetched());
              context.read<AssetBloc>().add(const AssetFetched());
              context.read<BudgetBloc>().add(const BudgetFetched());
              context.read<TransactionBloc>().add(const TransactionFetched());
            },
          ),
        ],
        child: BlocBuilder<ThemeCubit, ThemeState>(
          builder: (context, themeState) {
            return MaterialApp.router(
              title: 'Ikuyo Finance',
              theme: themeState.lightTheme,
              darkTheme: themeState.darkTheme,
              themeMode: themeState.themeMode,
              routerConfig: getIt<GoRouter>(),
              // * Easy localization setup
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              builder: (context, child) {
                return _AppSecurityWrapper(child: child!);
              },
            );
          },
        ),
      ),
    );
  }
}

/// Widget yang menangani app lifecycle & menampilkan lock screen overlay
class _AppSecurityWrapper extends StatefulWidget {
  final Widget child;
  const _AppSecurityWrapper({required this.child});

  @override
  State<_AppSecurityWrapper> createState() => _AppSecurityWrapperState();
}

class _AppSecurityWrapperState extends State<_AppSecurityWrapper>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cubit = context.read<SecurityCubit>();

    switch (state) {
      case AppLifecycleState.paused:
        cubit.onAppPaused();
        break;
      case AppLifecycleState.detached:
        cubit.onAppClose();
        break;
      case AppLifecycleState.inactive:
        cubit.onScreenOff();
        break;
      case AppLifecycleState.resumed:
        cubit.onAppResumed();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SecurityCubit, SecurityState>(
      buildWhen: (prev, curr) => prev.shouldLock != curr.shouldLock,
      builder: (context, state) {
        return Stack(
          children: [
            widget.child,
            if (state.shouldLock) const Positioned.fill(child: LockScreen()),
          ],
        );
      },
    );
  }
}
