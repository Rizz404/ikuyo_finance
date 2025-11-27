import 'package:fpdart/fpdart.dart';
import 'package:ikuyo_finance/core/wrapper/failure.dart';
import 'package:ikuyo_finance/core/wrapper/success.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';

abstract class CategoryRepository {
  TaskEither<Failure, Success<Category>> createCategory({
    required String name,
    required CategoryType type,
    String? icon,
    String? color,
    String? parentUlid,
  });
  TaskEither<Failure, SuccessCursor<Category>> getCategories({
    String? cursor,
    int limit = 20,
    CategoryType? type,
  });
  TaskEither<Failure, Success<Category>> getCategoryById({
    required String ulid,
  });
  TaskEither<Failure, Success<Category>> updateCategory({
    required String ulid,
    String? name,
    CategoryType? type,
    String? icon,
    String? color,
    String? parentUlid,
  });
  TaskEither<Failure, ActionSuccess> deleteCategory({required String ulid});
}
