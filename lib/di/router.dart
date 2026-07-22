import 'package:go_router/go_router.dart';
import 'package:ikuyo_finance/core/router/app_router.dart';
import 'package:ikuyo_finance/core/router/router_listenables.dart';
import 'package:ikuyo_finance/di/service_locator.dart';
import 'package:ikuyo_finance/features/auth/services/supabase_status_service.dart';

void setupRouter() {
  getIt.registerLazySingleton<SupabaseAuthListenable>(
    () => SupabaseAuthListenable(getIt<SupabaseStatusService>()),
  );

  getIt.registerLazySingleton<GoRouter>(
    () => createAppRouter(getIt<SupabaseAuthListenable>()),
  );
}
