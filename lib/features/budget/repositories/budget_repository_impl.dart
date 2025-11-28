import 'package:fpdart/fpdart.dart' hide Order;
import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';
import 'package:ikuyo_finance/core/wrapper/failure.dart';
import 'package:ikuyo_finance/core/wrapper/success.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/budget/models/create_budget_params.dart';
import 'package:ikuyo_finance/features/budget/models/get_budgets_params.dart';
import 'package:ikuyo_finance/features/budget/models/update_budget_params.dart';
import 'package:ikuyo_finance/features/budget/repositories/budget_repository.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/objectbox.g.dart';

class BudgetRepositoryImpl implements BudgetRepository {
  final ObjectBoxStorage _storage;

  const BudgetRepositoryImpl(this._storage);

  Box<Budget> get _box => _storage.box<Budget>();
  Box<Category> get _categoryBox => _storage.box<Category>();

  @override
  TaskEither<Failure, Success<Budget>> createBudget(CreateBudgetParams params) {
    return TaskEither.tryCatch(
      () async {
        logService('Create budget', 'category: ${params.categoryUlid}');

        // * Get category
        final category = _categoryBox
            .query(Category_.ulid.equals(params.categoryUlid))
            .build()
            .findFirst();

        if (category == null) {
          throw Exception('Category not found');
        }

        final budget = Budget(
          amountLimit: params.amountLimit,
          period: params.period.index,
          startDate: params.startDate,
          endDate: params.endDate,
        );

        budget.category.target = category;

        _box.put(budget);
        logInfo('Budget created successfully');

        return Success(message: 'Budget created', data: budget);
      },
      (error, stackTrace) {
        logError('Create budget failed', error, stackTrace);
        return Failure(
          message: error.toString().contains('not found')
              ? error.toString()
              : 'Failed to create budget. Please try again.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, SuccessCursor<Budget>> getBudgets(
    GetBudgetsParams params,
  ) {
    return TaskEither.tryCatch(
      () async {
        logService(
          'Get budgets',
          'cursor: ${params.cursor}, limit: ${params.limit}',
        );

        var query = _box.query();

        // * Filter by period jika ada
        if (params.period != null) {
          query = _box.query(Budget_.period.equals(params.period!.index));
        }

        // * Pagination dengan cursor (offset-based)
        final offset = params.cursor != null
            ? int.tryParse(params.cursor!) ?? 0
            : 0;
        query = query..order(Budget_.createdAt, flags: Order.descending);

        final builtQuery = query.build();
        final allResults = builtQuery.find();
        builtQuery.close();

        // * Filter by category jika ada
        var filteredResults = allResults;
        if (params.categoryUlid != null) {
          filteredResults = allResults
              .where((b) => b.category.target?.ulid == params.categoryUlid)
              .toList();
        }

        // * Manual offset & limit
        final startIndex = offset < filteredResults.length
            ? offset
            : filteredResults.length;
        final endIndex =
            (startIndex + params.limit + 1) < filteredResults.length
            ? startIndex + params.limit + 1
            : filteredResults.length;
        final results = filteredResults.sublist(startIndex, endIndex);

        final hasMore = results.length > params.limit;
        final budgets = hasMore ? results.sublist(0, params.limit) : results;

        final cursorInfo = CursorInfo(
          nextCursor: hasMore ? (offset + params.limit).toString() : '',
          hasNextPage: hasMore,
          perPage: params.limit,
        );

        logInfo('Budgets retrieved: ${budgets.length}');

        return SuccessCursor(
          message: 'Budgets retrieved',
          data: budgets,
          cursor: cursorInfo,
        );
      },
      (error, stackTrace) {
        logError('Get budgets failed', error, stackTrace);
        return Failure(
          message: 'Failed to retrieve budgets. Please try again.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, Success<Budget>> getBudgetById({required String ulid}) {
    return TaskEither.tryCatch(
      () async {
        logService('Get budget by id', ulid);

        final budget = _box
            .query(Budget_.ulid.equals(ulid))
            .build()
            .findFirst();

        if (budget == null) {
          throw Exception('Budget not found');
        }

        logInfo('Budget retrieved');
        return Success(message: 'Budget retrieved', data: budget);
      },
      (error, stackTrace) {
        logError('Get budget by id failed', error, stackTrace);
        return Failure(
          message: error.toString().contains('not found')
              ? 'Budget not found'
              : 'Failed to retrieve budget. Please try again.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, Success<Budget>> updateBudget(UpdateBudgetParams params) {
    return TaskEither.tryCatch(
      () async {
        logService('Update budget', params.ulid);

        final budget = _box
            .query(Budget_.ulid.equals(params.ulid))
            .build()
            .findFirst();

        if (budget == null) {
          throw Exception('Budget not found');
        }

        // * Update fields jika ada
        if (params.amountLimit != null)
          budget.amountLimit = params.amountLimit!;
        if (params.period != null) budget.period = params.period!.index;
        if (params.startDate != null) budget.startDate = params.startDate;
        if (params.endDate != null) budget.endDate = params.endDate;

        // * Update category jika ada
        if (params.categoryUlid != null) {
          final category = _categoryBox
              .query(Category_.ulid.equals(params.categoryUlid!))
              .build()
              .findFirst();

          if (category == null) {
            throw Exception('Category not found');
          }

          budget.category.target = category;
        }

        budget.updatedAt = DateTime.now();
        _box.put(budget);

        logInfo('Budget updated successfully');
        return Success(message: 'Budget updated', data: budget);
      },
      (error, stackTrace) {
        logError('Update budget failed', error, stackTrace);
        return Failure(
          message: error.toString().contains('not found')
              ? error.toString()
              : 'Failed to update budget. Please try again.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, ActionSuccess> deleteBudget({required String ulid}) {
    return TaskEither.tryCatch(
      () async {
        logService('Delete budget', ulid);

        final budget = _box
            .query(Budget_.ulid.equals(ulid))
            .build()
            .findFirst();

        if (budget == null) {
          throw Exception('Budget not found');
        }

        _box.remove(budget.id);
        logInfo('Budget deleted successfully');

        return const ActionSuccess(message: 'Budget deleted');
      },
      (error, stackTrace) {
        logError('Delete budget failed', error, stackTrace);
        return Failure(
          message: error.toString().contains('not found')
              ? 'Budget not found'
              : 'Failed to delete budget. Please try again.',
        );
      },
    );
  }
}
