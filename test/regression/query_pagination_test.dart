// Regression: P03 (asset, category and budget lists loaded every matching row
// and then sliced one page in Dart). Pages must come from ObjectBox
// offset/limit with the query closed, keeping filter/search/order/count
// semantics and page boundaries. Real ObjectBox + real repositories.
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/core/storage/query_extensions.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/asset/models/get_assets_params.dart';
import 'package:ikuyo_finance/features/asset/repositories/asset_repository_impl.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/budget/models/get_budgets_params.dart';
import 'package:ikuyo_finance/features/budget/repositories/budget_repository_impl.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/category/models/get_categories_params.dart';
import 'package:ikuyo_finance/features/category/repositories/category_repository_impl.dart';
import 'package:ikuyo_finance/core/wrapper/success.dart';

import '../support/fake_app_file_storage.dart';
import '../support/objectbox_test_store.dart';
import '../support/test_logger.dart';

void main() {
  setUpAll(bootstrapTestLogger);

  late ObjectBoxTestStore store;
  setUp(() async => store = await ObjectBoxTestStore.open());
  tearDown(() => store.close());

  const total = 45;
  const limit = 20;
  DateTime at(int i) => DateTime(2025, 1, 1).add(Duration(hours: i));
  String n(String p, int i) => '$p${i.toString().padLeft(2, '0')}';

  /// Walks every page via the returned cursor; asserts each page was
  /// read with at most limit + 1 rows (one look-ahead row for hasNextPage).
  Future<List<T>> walk<T, E>(
    Future<SuccessCursor<T>> Function(String? cursor) fetch, {
    required List<int> expectedSizes,
  }) async {
    final all = <T>[];
    String? cursor;
    final sizes = <int>[];
    while (true) {
      QueryStats.reset();
      final page = await fetch(cursor);
      expect(
        QueryStats.rowsOf<E>(),
        lessThanOrEqualTo(limit + 1),
        reason: 'page at cursor $cursor must not load every row',
      );
      sizes.add(page.data!.length);
      all.addAll(page.data!);
      if (!page.cursor.hasNextPage) {
        expect(page.cursor.nextCursor, '');
        break;
      }
      cursor = page.cursor.nextCursor;
    }
    expect(sizes, expectedSizes);
    return all;
  }

  group('assets', () {
    late AssetRepositoryImpl repo;
    setUp(() {
      repo = AssetRepositoryImpl(store.storage, FakeAppFileStorage());
      store.storage.box<Asset>().putMany([
        for (var i = 0; i < total; i++)
          Asset(
            name: n(i.isEven ? 'Even' : 'Odd', i),
            type: (i % 3 == 0 ? AssetType.bank : AssetType.cash).index,
            balance: i.toDouble(),
            createdAt: at(i),
          ),
      ]);
    });

    Future<SuccessCursor<Asset>> page(GetAssetsParams p) async =>
        (await repo.getAssets(p).run()).getOrElse((f) => throw f);

    test('>20 items span three pages in createdAt-desc order', () async {
      final got = await walk<Asset, Asset>(
        (c) => page(GetAssetsParams(cursor: c, limit: limit)),
        expectedSizes: [20, 20, 5],
      );
      expect(got.map((a) => a.name), [
        for (var i = total - 1; i >= 0; i--) n(i.isEven ? 'Even' : 'Odd', i),
      ]);
    });

    test('filtered and searched pages keep semantics', () async {
      final bank = await walk<Asset, Asset>(
        (c) => page(
          GetAssetsParams(
            cursor: c,
            limit: limit,
            type: AssetType.bank,
            sortBy: AssetSortBy.balance,
            sortOrder: AssetSortOrder.ascending,
          ),
        ),
        expectedSizes: [15],
      );
      expect(bank.map((a) => a.balance), [
        for (var i = 0; i < total; i += 3) i,
      ]);

      final even = await walk<Asset, Asset>(
        (c) =>
            page(GetAssetsParams(cursor: c, limit: limit, searchQuery: 'eVeN')),
        expectedSizes: [20, 3],
      );
      expect(even.every((a) => a.name.startsWith('Even')), isTrue);
    });

    test(
      'end and past-the-end pages are empty without a next cursor',
      () async {
        for (final c in ['45', '60']) {
          final p = await page(GetAssetsParams(cursor: c, limit: limit));
          expect(p.data, isEmpty);
          expect(p.cursor.hasNextPage, isFalse);
        }
        final exact = await page(
          const GetAssetsParams(cursor: '25', limit: limit),
        );
        expect(exact.data, hasLength(20));
        expect(exact.cursor.hasNextPage, isFalse);
      },
    );
  });

  group('categories', () {
    late CategoryRepositoryImpl repo;
    late Category parent;
    setUp(() {
      repo = CategoryRepositoryImpl(store.storage, FakeAppFileStorage());
      parent = Category(
        name: 'Parent',
        type: CategoryType.expense.index,
        createdAt: DateTime(2020),
      );
      store.storage.box<Category>().put(parent);
      final cats = [
        for (var i = 0; i < total; i++)
          Category(
            name: n('C', i),
            type: (i.isEven ? CategoryType.expense : CategoryType.income).index,
            createdAt: at(i),
          ),
      ];
      // * every 4th one is a child of [parent]
      for (var i = 0; i < total; i += 4) {
        cats[i].parent.target = parent;
      }
      store.storage.box<Category>().putMany(cats);
    });

    Future<SuccessCursor<Category>> page(GetCategoriesParams p) async =>
        (await repo.getCategories(p).run()).getOrElse((f) => throw f);

    test('>20 categories span pages; name order ascending', () async {
      final got = await walk<Category, Category>(
        (c) => page(
          GetCategoriesParams(
            cursor: c,
            limit: limit,
            sortBy: CategorySortBy.name,
            sortOrder: CategorySortOrder.ascending,
          ),
        ),
        expectedSizes: [20, 20, 6],
      );
      expect(got.map((c) => c.name), [
        for (var i = 0; i < total; i++) n('C', i),
        'Parent',
      ]);
    });

    test('parent and root-only filters page in the query', () async {
      final children = await walk<Category, Category>(
        (c) => page(
          GetCategoriesParams(cursor: c, limit: 5, parentUlid: parent.ulid),
        ),
        expectedSizes: [5, 5, 2],
      );
      expect(children.map((c) => c.name), [
        for (var i = 44; i >= 0; i -= 4) n('C', i),
      ]);

      final roots = await walk<Category, Category>(
        (c) => page(
          GetCategoriesParams(
            cursor: c,
            limit: limit,
            isRootOnly: true,
            type: CategoryType.income,
          ),
        ),
        expectedSizes: [20, 2],
      );
      expect(roots.every((c) => c.parent.target == null), isTrue);
      expect(roots.every((c) => c.categoryType == CategoryType.income), isTrue);
    });

    test('an empty filter result is one empty last page', () async {
      final none = await page(
        GetCategoriesParams(limit: limit, searchQuery: 'zzz-no-match'),
      );
      expect(none.data, isEmpty);
      expect(none.cursor.hasNextPage, isFalse);
    });
  });

  group('budgets', () {
    late BudgetRepositoryImpl repo;
    late Category food;
    late Category travel;
    setUp(() {
      repo = BudgetRepositoryImpl(store.storage);
      food = Category(name: 'Food', type: CategoryType.expense.index);
      travel = Category(name: 'Travel', type: CategoryType.expense.index);
      store.storage.box<Category>().putMany([food, travel]);
      store.storage.box<Budget>().putMany([
        for (var i = 0; i < total; i++)
          Budget(
            amountLimit: (i + 1).toDouble(),
            period:
                (i.isEven ? BudgetPeriod.monthly : BudgetPeriod.weekly).index,
            createdAt: at(i),
          )..category.target = i % 3 == 0 ? travel : food,
      ]);
    });

    Future<SuccessCursor<Budget>> page(GetBudgetsParams p) async =>
        (await repo.getBudgets(p).run()).getOrElse((f) => throw f);

    test('>20 budgets span pages in createdAt-desc order', () async {
      final got = await walk<Budget, Budget>(
        (c) => page(GetBudgetsParams(cursor: c, limit: limit)),
        expectedSizes: [20, 20, 5],
      );
      expect(got.map((b) => b.amountLimit), [
        for (var i = total; i >= 1; i--) i,
      ]);
    });

    test(
      'category filter and category-name search page in the query',
      () async {
        final travelBudgets = await walk<Budget, Budget>(
          (c) => page(
            GetBudgetsParams(
              cursor: c,
              limit: 10,
              categoryUlid: travel.ulid,
              sortBy: BudgetSortBy.amountLimit,
              sortOrder: BudgetSortOrder.ascending,
            ),
          ),
          expectedSizes: [10, 5],
        );
        expect(travelBudgets.map((b) => b.amountLimit), [
          for (var i = 0; i < total; i += 3) i + 1,
        ]);

        final foodMonthly = await walk<Budget, Budget>(
          (c) => page(
            GetBudgetsParams(
              cursor: c,
              limit: 10,
              searchQuery: 'fOo',
              period: BudgetPeriod.monthly,
            ),
          ),
          expectedSizes: [10, 5],
        );
        expect(
          foodMonthly.every(
            (b) =>
                b.category.target?.ulid == food.ulid &&
                b.budgetPeriod == BudgetPeriod.monthly,
          ),
          isTrue,
        );
      },
    );

    test('empty, end and past-the-end budget pages', () async {
      final none = await page(
        const GetBudgetsParams(limit: limit, searchQuery: 'nothing'),
      );
      expect(none.data, isEmpty);
      expect(none.cursor.hasNextPage, isFalse);
      final end = await page(
        const GetBudgetsParams(cursor: '45', limit: limit),
      );
      expect(end.data, isEmpty);
      expect(end.cursor.hasNextPage, isFalse);
    });
  });
}
