// Regression: NEW-5 (deleteCategory, hasChildren and the "edited category
// must not have children" update check loaded every category into memory and
// scanned parent links in Dart). They now ask ObjectBox whether a child exists
// via the parent relation (count query, no rows loaded). Correctness edges:
// children of another parent, a child of the category itself, and an
// unrelated large tree. Real ObjectBox; QueryStats counts loaded rows.
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/core/storage/query_extensions.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/category/models/update_category_params.dart';
import 'package:ikuyo_finance/features/category/repositories/category_repository_impl.dart';

import '../support/fake_app_file_storage.dart';
import '../support/objectbox_test_store.dart';
import '../support/test_logger.dart';

void main() {
  setUpAll(bootstrapTestLogger);

  late ObjectBoxTestStore store;
  late CategoryRepositoryImpl repo;
  late Category withChild;
  late Category leafRoot;
  late Category otherRoot;

  setUp(() async {
    store = await ObjectBoxTestStore.open();
    repo = CategoryRepositoryImpl(store.storage, FakeAppFileStorage());
    final box = store.storage.box<Category>();
    final type = CategoryType.expense.index;
    withChild = Category(name: 'Food', type: type);
    leafRoot = Category(name: 'Leaf', type: type);
    otherRoot = Category(name: 'Other', type: type);
    box.putMany([withChild, leafRoot, otherRoot]);
    box.put(Category(name: 'Snacks', type: type)..parent.target = withChild);
    // * a big unrelated tree: none of these is a child of leafRoot
    final roots = [
      for (var i = 0; i < 50; i++) Category(name: 'R$i', type: type),
    ];
    box.putMany(roots);
    box.putMany([
      for (var i = 0; i < 200; i++)
        Category(name: 'C$i', type: type)..parent.target = roots[i % 50],
    ]);
    QueryStats.reset();
  });
  tearDown(() => store.close());

  // * a child check must not materialise unrelated categories
  const rowBudget = 2;

  test(
    'NEW-5 hasChildren answers correctly without loading all categories',
    () async {
      final yes = await repo.hasChildren(ulid: withChild.ulid).run();
      final no = await repo.hasChildren(ulid: leafRoot.ulid).run();
      expect(yes.getOrElse((f) => throw Exception(f.message)).data, isTrue);
      expect(no.getOrElse((f) => throw Exception(f.message)).data, isFalse);
      expect(QueryStats.rowsOf<Category>(), lessThanOrEqualTo(rowBudget));
    },
  );

  test('NEW-5 deleteCategory blocks a parent and deletes a leaf root without '
      'loading all categories', () async {
    final blocked = await repo.deleteCategory(ulid: withChild.ulid).run();
    expect(blocked.isLeft(), isTrue);
    final deleted = await repo.deleteCategory(ulid: leafRoot.ulid).run();
    expect(deleted.isRight(), isTrue);
    expect(store.storage.box<Category>().get(leafRoot.id), isNull);
    expect(store.storage.box<Category>().get(withChild.id), isNotNull);
    expect(QueryStats.rowsOf<Category>(), lessThanOrEqualTo(rowBudget));
  });

  test(
    'NEW-5 updateCategory child check without loading all categories',
    () async {
      final rejected = await repo
          .updateCategory(
            UpdateCategoryParams(
              ulid: withChild.ulid,
              name: null,
              type: null,
              parentUlid: otherRoot.ulid,
            ),
          )
          .run();
      expect(rejected.isLeft(), isTrue);
      expect(
        store.storage.box<Category>().get(withChild.id)!.parent.target,
        isNull,
      );

      QueryStats.reset();
      final moved = await repo
          .updateCategory(
            UpdateCategoryParams(
              ulid: leafRoot.ulid,
              name: null,
              type: null,
              parentUlid: otherRoot.ulid,
            ),
          )
          .run();
      expect(moved.isRight(), isTrue);
      expect(
        store.storage.box<Category>().get(leafRoot.id)!.parent.target?.ulid,
        otherRoot.ulid,
      );
      // * the edited category and its new parent are the only rows needed
      expect(QueryStats.rowsOf<Category>(), lessThanOrEqualTo(rowBudget));
    },
  );
}
