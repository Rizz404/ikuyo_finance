// Regression: CSE-11 / edit-null semantics. In update params a null field
// means "unchanged", so a sub-category could never be promoted back to root,
// and type edits could leave a parent and its children with different types.
// Real ObjectBox + real CategoryRepositoryImpl.
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/category/models/create_category_params.dart';
import 'package:ikuyo_finance/features/category/models/update_category_params.dart';
import 'package:ikuyo_finance/features/category/repositories/category_repository_impl.dart';

import '../support/fake_app_file_storage.dart';
import '../support/objectbox_test_store.dart';
import '../support/test_logger.dart';

void main() {
  setUpAll(bootstrapTestLogger);

  late ObjectBoxTestStore store;
  late CategoryRepositoryImpl repo;

  setUp(() async {
    store = await ObjectBoxTestStore.open();
    repo = CategoryRepositoryImpl(store.storage, FakeAppFileStorage());
  });
  tearDown(() => store.close());

  Future<Category> create(String name, CategoryType type, {String? parent}) async =>
      (await repo
              .createCategory(
                CreateCategoryParams(name: name, type: type, parentUlid: parent),
              )
              .run())
          .getOrElse((f) => throw Exception(f.message))
          .data!;

  Category reload(String ulid) => store.storage
      .box<Category>()
      .getAll()
      .firstWhere((c) => c.ulid == ulid);

  test('clearParent promotes a sub-category to a root category', () async {
    final food = await create('Food', CategoryType.expense);
    final snacks = await create('Snacks', CategoryType.expense, parent: food.ulid);

    final result = await repo
        .updateCategory(
          UpdateCategoryParams(
            ulid: snacks.ulid,
            name: 'Snacks',
            type: CategoryType.expense,
            clearParent: true,
          ),
        )
        .run();

    expect(result.isRight(), isTrue);
    expect(reload(snacks.ulid).parent.target, isNull);
  });

  test('null parentUlid without clearParent keeps the existing parent', () async {
    final food = await create('Food', CategoryType.expense);
    final snacks = await create('Snacks', CategoryType.expense, parent: food.ulid);

    await repo
        .updateCategory(
          UpdateCategoryParams(ulid: snacks.ulid, name: 'Chips', type: null),
        )
        .run();

    final reloaded = reload(snacks.ulid);
    expect(reloaded.name, 'Chips');
    expect(reloaded.parent.target?.ulid, food.ulid);
  });

  test('rejects changing a sub-category type away from its parent type', () async {
    final food = await create('Food', CategoryType.expense);
    final snacks = await create('Snacks', CategoryType.expense, parent: food.ulid);

    final result = await repo
        .updateCategory(
          UpdateCategoryParams(
            ulid: snacks.ulid,
            name: 'Snacks',
            type: CategoryType.income,
          ),
        )
        .run();

    expect(result.isLeft(), isTrue);
    expect(reload(snacks.ulid).categoryType, CategoryType.expense);
  });

  test('allows changing type together with promotion to root', () async {
    final food = await create('Food', CategoryType.expense);
    final snacks = await create('Snacks', CategoryType.expense, parent: food.ulid);

    final result = await repo
        .updateCategory(
          UpdateCategoryParams(
            ulid: snacks.ulid,
            name: 'Snacks',
            type: CategoryType.income,
            clearParent: true,
          ),
        )
        .run();

    expect(result.isRight(), isTrue);
    final reloaded = reload(snacks.ulid);
    expect(reloaded.categoryType, CategoryType.income);
    expect(reloaded.parent.target, isNull);
  });

  test('rejects changing a parent category type while it has children', () async {
    final food = await create('Food', CategoryType.expense);
    await create('Snacks', CategoryType.expense, parent: food.ulid);

    final result = await repo
        .updateCategory(
          UpdateCategoryParams(
            ulid: food.ulid,
            name: 'Food',
            type: CategoryType.income,
          ),
        )
        .run();

    expect(result.isLeft(), isTrue);
    expect(reload(food.ulid).categoryType, CategoryType.expense);
  });

  test('rejects moving under a parent of a different type', () async {
    final salary = await create('Salary', CategoryType.income);
    final snacks = await create('Snacks', CategoryType.expense);

    final result = await repo
        .updateCategory(
          UpdateCategoryParams(
            ulid: snacks.ulid,
            name: 'Snacks',
            type: null,
            parentUlid: salary.ulid,
          ),
        )
        .run();

    expect(result.isLeft(), isTrue);
    expect(reload(snacks.ulid).parent.target, isNull);
  });
}
