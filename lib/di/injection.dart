import 'package:ikuyo_finance/di/blocs.dart';
import 'package:ikuyo_finance/di/commons.dart';
import 'package:ikuyo_finance/di/repositories.dart';
import 'package:ikuyo_finance/di/router.dart';

export 'package:ikuyo_finance/di/service_locator.dart';

// * Main entry point untuk setup semua dependencies
Future<void> setupDependencies() async {
  // * Setup commons (logger, storage, supabase)
  await setupCommons();

  // * Setup repositories (depends on supabase client)
  setupRepositories();

  // * Setup blocs (depends on repositories)
  setupBlocs();

  // * Setup router (depends on supabase auth)
  setupRouter();
}
