import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/di/service_locator.dart';
import 'package:ikuyo_finance/features/auth/repositories/auth_repository.dart';
import 'package:ikuyo_finance/features/auth/repositories/auth_repository_impl.dart';
import 'package:ikuyo_finance/features/budget/repositories/budget_repository.dart';
import 'package:ikuyo_finance/features/budget/repositories/budget_repository_impl.dart';
import 'package:ikuyo_finance/features/category/repositories/category_repository.dart';
import 'package:ikuyo_finance/features/category/repositories/category_repository_impl.dart';
import 'package:ikuyo_finance/features/transaction/repositories/transaction_repository.dart';
import 'package:ikuyo_finance/features/transaction/repositories/transaction_repository_impl.dart';
import 'package:ikuyo_finance/features/asset/repositories/asset_repository.dart';
import 'package:ikuyo_finance/features/asset/repositories/asset_repository_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void setupRepositories() {
  getIt
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<CategoryRepository>(
      () => CategoryRepositoryImpl(getIt<ObjectBoxStorage>()),
    )
    ..registerLazySingleton<AssetRepository>(
      () => AssetRepositoryImpl(getIt<ObjectBoxStorage>()),
    )
    ..registerLazySingleton<BudgetRepository>(
      () => BudgetRepositoryImpl(getIt<ObjectBoxStorage>()),
    )
    ..registerLazySingleton<TransactionRepository>(
      () => TransactionRepositoryImpl(getIt<ObjectBoxStorage>()),
    );
}
