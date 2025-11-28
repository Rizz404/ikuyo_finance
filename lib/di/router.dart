import 'package:go_router/go_router.dart';
import 'package:ikuyo_finance/core/router/app_router.dart';
import 'package:ikuyo_finance/core/router/router_listenables.dart';
import 'package:ikuyo_finance/di/service_locator.dart';

void setupRouter() {
  // * Register auth listenable
  getIt.registerLazySingleton<SupabaseAuthListenable>(
    () => SupabaseAuthListenable(),
  );

  // * Register router dengan auth listenable
  getIt.registerLazySingleton<GoRouter>(
    () => createAppRouter(getIt<SupabaseAuthListenable>()),
  );
}
