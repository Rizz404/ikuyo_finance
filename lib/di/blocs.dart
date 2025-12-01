import 'package:ikuyo_finance/di/service_locator.dart';
import 'package:ikuyo_finance/features/auth/bloc/auth_bloc.dart';
import 'package:ikuyo_finance/features/auth/repositories/auth_repository.dart';
import 'package:ikuyo_finance/features/budget/bloc/budget_bloc.dart';
import 'package:ikuyo_finance/features/budget/repositories/budget_repository.dart';
import 'package:ikuyo_finance/features/category/bloc/category_bloc.dart';
import 'package:ikuyo_finance/features/category/repositories/category_repository.dart';
import 'package:ikuyo_finance/features/statistic/bloc/statistic_bloc.dart';
import 'package:ikuyo_finance/features/transaction/bloc/transaction_bloc.dart';
import 'package:ikuyo_finance/features/transaction/repositories/transaction_repository.dart';
import 'package:ikuyo_finance/features/asset/bloc/asset_bloc.dart';
import 'package:ikuyo_finance/features/asset/repositories/asset_repository.dart';

void setupBlocs() {
  getIt
    ..registerFactory<AuthBloc>(() => AuthBloc(getIt<AuthRepository>()))
    ..registerFactory<CategoryBloc>(
      () => CategoryBloc(getIt<CategoryRepository>()),
    )
    ..registerFactory<AssetBloc>(() => AssetBloc(getIt<AssetRepository>()))
    ..registerFactory<BudgetBloc>(() => BudgetBloc(getIt<BudgetRepository>()))
    ..registerFactory<TransactionBloc>(
      () => TransactionBloc(getIt<TransactionRepository>()),
    )
    ..registerFactory<StatisticBloc>(
      () => StatisticBloc(getIt<TransactionRepository>()),
    );
}
