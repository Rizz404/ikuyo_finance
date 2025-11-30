import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:ikuyo_finance/core/theme/cubit/theme_cubit.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';
import 'package:ikuyo_finance/di/injection.dart';
import 'package:ikuyo_finance/features/auth/bloc/auth_bloc.dart';
import 'package:ikuyo_finance/features/budget/bloc/budget_bloc.dart';
import 'package:ikuyo_finance/features/category/bloc/category_bloc.dart';
import 'package:ikuyo_finance/features/transaction/bloc/transaction_bloc.dart';
import 'package:ikuyo_finance/features/asset/bloc/asset_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  await initializeDateFormatting();
  await setupDependencies();

  talker.logInfo('Ikuyo Finance started');

  runApp(const MyApp());
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
        BlocProvider(create: (_) => getIt<ThemeCubit>()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, themeState) {
          return MaterialApp.router(
            title: 'Ikuyo Finance',
            theme: themeState.lightTheme,
            darkTheme: themeState.darkTheme,
            themeMode: themeState.themeMode,
            routerConfig: getIt<GoRouter>(),
          );
        },
      ),
    );
  }
}
