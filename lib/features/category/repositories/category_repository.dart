import 'package:fpdart/fpdart.dart';
import 'package:ikuyo_finance/core/wrapper/failure.dart';
import 'package:ikuyo_finance/core/wrapper/success.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/category/models/create_category_params.dart';
import 'package:ikuyo_finance/features/category/models/get_categories_params.dart';
import 'package:ikuyo_finance/features/category/models/update_category_params.dart';

abstract class CategoryRepository {
  TaskEither<Failure, Success<Category>> createCategory(
    CreateCategoryParams params,
  );
  TaskEither<Failure, SuccessCursor<Category>> getCategories(
    GetCategoriesParams params,
  );
  TaskEither<Failure, Success<Category>> getCategoryById({
    required String ulid,
  });
  TaskEither<Failure, Success<Category>> updateCategory(
    UpdateCategoryParams params,
  );
  TaskEither<Failure, ActionSuccess> deleteCategory({required String ulid});
}
