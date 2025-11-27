import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/di/service_locator.dart';
import 'package:ikuyo_finance/features/auth/repositories/auth_repository.dart';
import 'package:ikuyo_finance/features/auth/repositories/auth_repository_impl.dart';
import 'package:ikuyo_finance/features/category/repositories/category_repository.dart';
import 'package:ikuyo_finance/features/category/repositories/category_repository_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void setupRepositories() {
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(getIt<SupabaseClient>()),
  );

  getIt.registerLazySingleton<CategoryRepository>(
    () => CategoryRepositoryImpl(getIt<ObjectBoxStorage>()),
  );
}
