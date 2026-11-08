// Regression: AAOB-8. Custom budget dates must be complete and ordered, and
// switching a custom budget to another period must drop the stale range.
// Real ObjectBox + real BudgetRepositoryImpl + validators with real assets.
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/budget/models/create_budget_params.dart';
import 'package:ikuyo_finance/features/budget/models/update_budget_params.dart';
import 'package:ikuyo_finance/features/budget/repositories/budget_repository_impl.dart';
import 'package:ikuyo_finance/features/budget/validators/create_budget_validator.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';

import '../support/locale_test_helper.dart';
import '../support/objectbox_test_store.dart';
import '../support/test_logger.dart';

void main() {
  setUpAll(bootstrapTestLogger);

  late ObjectBoxTestStore store;
  late BudgetRepositoryImpl repo;
  late Category food;

  setUp(() async {
    store = await ObjectBoxTestStore.open();
    repo = BudgetRepositoryImpl(store.storage);
    food = Category(name: 'Food', type: CategoryType.expense.index);
    store.storage.box<Category>().put(food);
  });
  tearDown(() => store.close());

  Future<Budget> createCustom() async => (await repo
          .createBudget(
            CreateBudgetParams(
              categoryUlid: food.ulid,
              amountLimit: 10,
              period: BudgetPeriod.custom,
              startDate: DateTime(2026, 1, 1),
              endDate: DateTime(2026, 1, 31),
            ),
          )
          .run())
      .getOrElse((f) => throw Exception(f.message))
      .data!;

  test('a custom budget without dates is rejected and not stored', () async {
    final result = await repo
        .createBudget(
          CreateBudgetParams(
            categoryUlid: food.ulid,
            amountLimit: 10,
            period: BudgetPeriod.custom,
          ),
        )
        .run();
    expect(result.isLeft(), isTrue);
    expect(store.storage.box<Budget>().count(), 0);
  });

  test('a custom budget ending before it starts is rejected', () async {
    final result = await repo
        .createBudget(
          CreateBudgetParams(
            categoryUlid: food.ulid,
            amountLimit: 10,
            period: BudgetPeriod.custom,
            startDate: DateTime(2026, 2, 1),
            endDate: DateTime(2026, 1, 1),
          ),
        )
        .run();
    expect(result.isLeft(), isTrue);
    expect(store.storage.box<Budget>().count(), 0);
  });

  test('updating a custom budget to an inverted range is rejected and the '
      'stored range is unchanged', () async {
    final b = await createCustom();
    final result = await repo
        .updateBudget(
          UpdateBudgetParams(ulid: b.ulid, endDate: DateTime(2025, 12, 1)),
        )
        .run();
    expect(result.isLeft(), isTrue);
    final stored = store.storage.box<Budget>().get(b.id)!;
    expect(stored.endDate, DateTime(2026, 1, 31));
  });

  test('switching a custom budget to monthly clears the stale range',
      () async {
    final b = await createCustom();
    final result = await repo
        .updateBudget(
          UpdateBudgetParams(ulid: b.ulid, period: BudgetPeriod.monthly),
        )
        .run();
    expect(result.isRight(), isTrue);
    final stored = store.storage.box<Budget>().get(b.id)!;
    expect(stored.budgetPeriod, BudgetPeriod.monthly);
    expect(stored.startDate, isNull);
    expect(stored.endDate, isNull);
  });

  testWidgets('the form validator reports an end date before the start date',
      (tester) async {
    await loadTestLocale(tester);
    expect(
      CreateBudgetValidator.dateRange(
        BudgetPeriod.custom,
        DateTime(2026, 2, 1),
        DateTime(2026, 1, 1),
      ),
      isNotNull,
    );
    expect(
      CreateBudgetValidator.dateRange(BudgetPeriod.custom, null, null),
      isNotNull,
    );
    expect(
      CreateBudgetValidator.dateRange(
        BudgetPeriod.custom,
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 1),
      ),
      isNull,
    );
    expect(
      CreateBudgetValidator.dateRange(BudgetPeriod.monthly, null, null),
      isNull,
    );
  });
}
