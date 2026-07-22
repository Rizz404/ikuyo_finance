import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/category/models/create_category_params.dart';
import 'package:ikuyo_finance/features/category/models/get_categories_params.dart';
import 'package:ikuyo_finance/features/category/models/update_category_params.dart';
import 'package:ikuyo_finance/features/category/repositories/category_repository_impl.dart';

import '../../../support/fake_app_file_storage.dart';
import '../../../support/objectbox_test_store.dart';
import '../../../support/test_logger.dart';

void main() {
  late ObjectBoxTestStore testStore;
  late FakeAppFileStorage fileStorage;
  late CategoryRepositoryImpl repository;

  setUpAll(bootstrapTestLogger);

  setUp(() async {
    testStore = await ObjectBoxTestStore.open();
    fileStorage = FakeAppFileStorage();
    repository = CategoryRepositoryImpl(testStore.storage, fileStorage);
  });

  tearDown(() => testStore.close());

  group('createCategory', () {
    test('persists a root category and assigns a ulid', () async {
      final result = await repository
          .createCategory(
            const CreateCategoryParams(name: 'Salary', type: CategoryType.income),
          )
          .run();

      expect(result.isRight(), isTrue);
      final category = result.getOrElse((_) => throw Exception()).data!;
      expect(category.ulid, isNotEmpty);
      expect(category.name, 'Salary');
      expect(category.categoryType, CategoryType.income);
      expect(category.parent.target, isNull);
    });

    test('nests under an existing root category', () async {
      final parentResult = await repository
          .createCategory(
            const CreateCategoryParams(name: 'Food', type: CategoryType.expense),
          )
          .run();
      final parent = parentResult.getOrElse((_) => throw Exception()).data!;

      final childResult = await repository
          .createCategory(
            CreateCategoryParams(
              name: 'Groceries',
              type: CategoryType.expense,
              parentUlid: parent.ulid,
            ),
          )
          .run();

      expect(childResult.isRight(), isTrue);
      final child = childResult.getOrElse((_) => throw Exception()).data!;
      expect(child.parent.target?.ulid, parent.ulid);
    });

    test('fails when parent does not exist', () async {
      final result = await repository
          .createCategory(
            const CreateCategoryParams(
              name: 'Groceries',
              type: CategoryType.expense,
              parentUlid: 'unknown-ulid',
            ),
          )
          .run();

      expect(result.isLeft(), isTrue);
    });

    test('rejects nesting under a category that already has a parent (2-level nesting)', () async {
      final root = (await repository
              .createCategory(
                const CreateCategoryParams(name: 'Food', type: CategoryType.expense),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;
      final child = (await repository
              .createCategory(
                CreateCategoryParams(
                  name: 'Groceries',
                  type: CategoryType.expense,
                  parentUlid: root.ulid,
                ),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;

      final grandchildResult = await repository
          .createCategory(
            CreateCategoryParams(
              name: 'Vegetables',
              type: CategoryType.expense,
              parentUlid: child.ulid,
            ),
          )
          .run();

      expect(grandchildResult.isLeft(), isTrue);
    });

    test('saves the icon through AppFileStorage', () async {
      await repository
          .createCategory(
            const CreateCategoryParams(
              name: 'Food',
              type: CategoryType.expense,
              icon: '/tmp/source_icon.png',
            ),
          )
          .run();

      expect(fileStorage.savedPaths, hasLength(1));
    });
  });

  group('getCategories', () {
    setUp(() async {
      await repository
          .createCategory(
            const CreateCategoryParams(name: 'Salary', type: CategoryType.income),
          )
          .run();
      await repository
          .createCategory(
            const CreateCategoryParams(name: 'Food', type: CategoryType.expense),
          )
          .run();
      await repository
          .createCategory(
            const CreateCategoryParams(name: 'Transport', type: CategoryType.expense),
          )
          .run();
    });

    test('returns all categories with no filters', () async {
      final result = await repository.getCategories(const GetCategoriesParams()).run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data, hasLength(3));
    });

    test('filters by type', () async {
      final result = await repository
          .getCategories(const GetCategoriesParams(type: CategoryType.expense))
          .run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data, hasLength(2));
      expect(success.data!.every((c) => c.categoryType == CategoryType.expense), isTrue);
    });

    test('searches case-insensitively by name', () async {
      final result = await repository
          .getCategories(const GetCategoriesParams(searchQuery: 'foo'))
          .run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data, hasLength(1));
      expect(success.data!.single.name, 'Food');
    });

    test('paginates using cursor and reports hasNextPage', () async {
      final firstPage = (await repository
              .getCategories(const GetCategoriesParams(limit: 2))
              .run())
          .getOrElse((_) => throw Exception());

      expect(firstPage.data, hasLength(2));
      expect(firstPage.cursor.hasNextPage, isTrue);

      final secondPage = (await repository
              .getCategories(GetCategoriesParams(limit: 2, cursor: firstPage.cursor.nextCursor))
              .run())
          .getOrElse((_) => throw Exception());

      expect(secondPage.data, hasLength(1));
      expect(secondPage.cursor.hasNextPage, isFalse);
    });

    test('returns empty result set when no category matches', () async {
      final result = await repository
          .getCategories(const GetCategoriesParams(searchQuery: 'nonexistent'))
          .run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data, isEmpty);
      expect(success.cursor.hasNextPage, isFalse);
    });

    test('isRootOnly excludes categories that have a parent', () async {
      final food = (await repository
              .getCategories(const GetCategoriesParams(searchQuery: 'Food'))
              .run())
          .getOrElse((_) => throw Exception())
          .data!
          .single;
      await repository
          .createCategory(
            CreateCategoryParams(
              name: 'Snacks',
              type: CategoryType.expense,
              parentUlid: food.ulid,
            ),
          )
          .run();

      final result = await repository
          .getCategories(const GetCategoriesParams(isRootOnly: true))
          .run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data!.any((c) => c.name == 'Snacks'), isFalse);
    });

    test('filters by parentUlid', () async {
      final food = (await repository
              .getCategories(const GetCategoriesParams(searchQuery: 'Food'))
              .run())
          .getOrElse((_) => throw Exception())
          .data!
          .single;
      await repository
          .createCategory(
            CreateCategoryParams(
              name: 'Snacks',
              type: CategoryType.expense,
              parentUlid: food.ulid,
            ),
          )
          .run();

      final result = await repository
          .getCategories(GetCategoriesParams(parentUlid: food.ulid))
          .run();

      final success = result.getOrElse((_) => throw Exception());
      expect(success.data, hasLength(1));
      expect(success.data!.single.name, 'Snacks');
    });
  });

  group('getCategoryById', () {
    test('returns the matching category', () async {
      final created = (await repository
              .createCategory(
                const CreateCategoryParams(name: 'Salary', type: CategoryType.income),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;

      final result = await repository.getCategoryById(ulid: created.ulid).run();

      expect(result.isRight(), isTrue);
      expect(result.getOrElse((_) => throw Exception()).data!.name, 'Salary');
    });

    test('fails for an unknown ulid', () async {
      final result = await repository.getCategoryById(ulid: 'unknown').run();

      expect(result.isLeft(), isTrue);
    });
  });

  group('updateCategory', () {
    test('updates name, color and type', () async {
      final created = (await repository
              .createCategory(
                const CreateCategoryParams(name: 'Salary', type: CategoryType.income),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;

      final result = await repository
          .updateCategory(
            UpdateCategoryParams(
              ulid: created.ulid,
              name: 'Bonus',
              type: CategoryType.income,
              color: '#FF0000',
            ),
          )
          .run();

      final updated = result.getOrElse((_) => throw Exception()).data!;
      expect(updated.name, 'Bonus');
      expect(updated.color, '#FF0000');
    });

    test('fails for an unknown ulid', () async {
      final result = await repository
          .updateCategory(
            const UpdateCategoryParams(ulid: 'unknown', name: 'x', type: null),
          )
          .run();

      expect(result.isLeft(), isTrue);
    });

    test('rejects setting itself as its own parent', () async {
      final created = (await repository
              .createCategory(
                const CreateCategoryParams(name: 'Food', type: CategoryType.expense),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;

      final result = await repository
          .updateCategory(
            UpdateCategoryParams(
              ulid: created.ulid,
              name: null,
              type: null,
              parentUlid: created.ulid,
            ),
          )
          .run();

      expect(result.isLeft(), isTrue);
    });

    test('rejects becoming a sub-category when it already has children', () async {
      final parent = (await repository
              .createCategory(
                const CreateCategoryParams(name: 'Food', type: CategoryType.expense),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;
      await repository
          .createCategory(
            CreateCategoryParams(
              name: 'Snacks',
              type: CategoryType.expense,
              parentUlid: parent.ulid,
            ),
          )
          .run();
      final otherRoot = (await repository
              .createCategory(
                const CreateCategoryParams(name: 'Transport', type: CategoryType.expense),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;

      final result = await repository
          .updateCategory(
            UpdateCategoryParams(
              ulid: parent.ulid,
              name: null,
              type: null,
              parentUlid: otherRoot.ulid,
            ),
          )
          .run();

      expect(result.isLeft(), isTrue);
    });

    test('replaces the icon via AppFileStorage.updateFile and deletes the old one', () async {
      final created = (await repository
              .createCategory(
                const CreateCategoryParams(
                  name: 'Food',
                  type: CategoryType.expense,
                  icon: '/tmp/old_icon.png',
                ),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;
      final oldIcon = created.icon!;

      await repository
          .updateCategory(
            UpdateCategoryParams(
              ulid: created.ulid,
              name: null,
              type: null,
              icon: '/tmp/new_icon.png',
            ),
          )
          .run();

      expect(fileStorage.deletedPaths, contains(oldIcon));
    });
  });

  group('deleteCategory', () {
    test('removes the category', () async {
      final created = (await repository
              .createCategory(
                const CreateCategoryParams(name: 'Salary', type: CategoryType.income),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;

      final result = await repository.deleteCategory(ulid: created.ulid).run();

      expect(result.isRight(), isTrue);
      final getResult = await repository.getCategoryById(ulid: created.ulid).run();
      expect(getResult.isLeft(), isTrue);
    });

    test('fails for an unknown ulid', () async {
      final result = await repository.deleteCategory(ulid: 'unknown').run();

      expect(result.isLeft(), isTrue);
    });

    test('rejects deleting a category that has children', () async {
      final parent = (await repository
              .createCategory(
                const CreateCategoryParams(name: 'Food', type: CategoryType.expense),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;
      await repository
          .createCategory(
            CreateCategoryParams(
              name: 'Snacks',
              type: CategoryType.expense,
              parentUlid: parent.ulid,
            ),
          )
          .run();

      final result = await repository.deleteCategory(ulid: parent.ulid).run();

      expect(result.isLeft(), isTrue);
    });

    test('deletes the icon file through AppFileStorage', () async {
      final created = (await repository
              .createCategory(
                const CreateCategoryParams(
                  name: 'Food',
                  type: CategoryType.expense,
                  icon: '/tmp/icon.png',
                ),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;

      await repository.deleteCategory(ulid: created.ulid).run();

      expect(fileStorage.deletedPaths, contains(created.icon));
    });
  });

  group('getValidParentCategories', () {
    test('only returns root categories of the same type, excluding self', () async {
      final root1 = (await repository
              .createCategory(
                const CreateCategoryParams(name: 'Food', type: CategoryType.expense),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;
      final root2 = (await repository
              .createCategory(
                const CreateCategoryParams(name: 'Transport', type: CategoryType.expense),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;
      await repository
          .createCategory(
            CreateCategoryParams(
              name: 'Snacks',
              type: CategoryType.expense,
              parentUlid: root1.ulid,
            ),
          )
          .run();
      await repository
          .createCategory(
            const CreateCategoryParams(name: 'Salary', type: CategoryType.income),
          )
          .run();

      final result = await repository
          .getValidParentCategories(type: CategoryType.expense, excludeUlid: root1.ulid)
          .run();

      final valid = result.getOrElse((_) => throw Exception()).data!;
      expect(valid.map((c) => c.ulid), [root2.ulid]);
    });
  });

  group('hasChildren', () {
    test('is false for a category without children', () async {
      final created = (await repository
              .createCategory(
                const CreateCategoryParams(name: 'Food', type: CategoryType.expense),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;

      final result = await repository.hasChildren(ulid: created.ulid).run();

      expect(result.getOrElse((_) => throw Exception()).data, isFalse);
    });

    test('is true once a child is added', () async {
      final parent = (await repository
              .createCategory(
                const CreateCategoryParams(name: 'Food', type: CategoryType.expense),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;
      await repository
          .createCategory(
            CreateCategoryParams(
              name: 'Snacks',
              type: CategoryType.expense,
              parentUlid: parent.ulid,
            ),
          )
          .run();

      final result = await repository.hasChildren(ulid: parent.ulid).run();

      expect(result.getOrElse((_) => throw Exception()).data, isTrue);
    });
  });
}
