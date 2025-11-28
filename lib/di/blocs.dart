import 'package:ikuyo_finance/di/service_locator.dart';
import 'package:ikuyo_finance/features/auth/bloc/auth_bloc.dart';
import 'package:ikuyo_finance/features/auth/repositories/auth_repository.dart';
import 'package:ikuyo_finance/features/category/bloc/category_bloc.dart';
import 'package:ikuyo_finance/features/category/repositories/category_repository.dart';

void setupBlocs() {
  getIt.registerFactory<AuthBloc>(() => AuthBloc(getIt<AuthRepository>()));
  getIt.registerFactory<CategoryBloc>(
    () => CategoryBloc(getIt<CategoryRepository>()),
  );
}
