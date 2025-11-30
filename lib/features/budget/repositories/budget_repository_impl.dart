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
          'cursor: ${params.cursor}, limit: ${params.limit}, search: ${params.searchQuery}, sortBy: ${params.sortBy}',
        );

        // * Build conditions list
        final List<Condition<Budget>> conditions = [];

        // * Filter by period
        if (params.period != null) {
          conditions.add(Budget_.period.equals(params.period!.index));
        }

        // * Amount limit range filter
        if (params.minAmountLimit != null && params.maxAmountLimit != null) {
          conditions.add(
            Budget_.amountLimit.between(
              params.minAmountLimit!,
              params.maxAmountLimit!,
            ),
          );
        } else if (params.minAmountLimit != null) {
          conditions.add(
            Budget_.amountLimit.greaterOrEqual(params.minAmountLimit!),
          );
        } else if (params.maxAmountLimit != null) {
          conditions.add(
            Budget_.amountLimit.lessOrEqual(params.maxAmountLimit!),
          );
        }

        // * Start date range filter
        if (params.startDateFrom != null && params.startDateTo != null) {
          conditions.add(
            Budget_.startDate.betweenDate(
              params.startDateFrom!,
              params.startDateTo!,
            ),
          );
        } else if (params.startDateFrom != null) {
          conditions.add(
            Budget_.startDate.greaterOrEqualDate(params.startDateFrom!),
          );
        } else if (params.startDateTo != null) {
          conditions.add(
            Budget_.startDate.lessOrEqualDate(params.startDateTo!),
          );
        }

        // * End date range filter
        if (params.endDateFrom != null && params.endDateTo != null) {
          conditions.add(
            Budget_.endDate.betweenDate(params.endDateFrom!, params.endDateTo!),
          );
        } else if (params.endDateFrom != null) {
          conditions.add(
            Budget_.endDate.greaterOrEqualDate(params.endDateFrom!),
          );
        } else if (params.endDateTo != null) {
          conditions.add(Budget_.endDate.lessOrEqualDate(params.endDateTo!));
        }

        // * Build query with conditions
        QueryBuilder<Budget> queryBuilder;
        if (conditions.isNotEmpty) {
          Condition<Budget> combinedCondition = conditions.first;
          for (int i = 1; i < conditions.length; i++) {
            combinedCondition = combinedCondition.and(conditions[i]);
          }
          queryBuilder = _box.query(combinedCondition);
        } else {
          queryBuilder = _box.query();
        }

        // * Apply sorting based on sortBy parameter
        final orderFlags = params.sortOrder == BudgetSortOrder.descending
            ? Order.descending
            : 0;

        switch (params.sortBy) {
          case BudgetSortBy.amountLimit:
            queryBuilder.order(Budget_.amountLimit, flags: orderFlags);
            break;
          case BudgetSortBy.startDate:
            queryBuilder.order(Budget_.startDate, flags: orderFlags);
            break;
          case BudgetSortBy.endDate:
            queryBuilder.order(Budget_.endDate, flags: orderFlags);
            break;
          case BudgetSortBy.createdAt:
            queryBuilder.order(Budget_.createdAt, flags: orderFlags);
            break;
        }

        final builtQuery = queryBuilder.build();
        final allResults = builtQuery.find();
        builtQuery.close();

        // * Filter by category (ObjectBox doesn't support ToOne query directly)
        var filteredResults = allResults;
        if (params.categoryUlid != null) {
          filteredResults = filteredResults
              .where((b) => b.category.target?.ulid == params.categoryUlid)
              .toList();
        }

        // * Filter by search query (search by category name)
        if (params.searchQuery != null && params.searchQuery!.isNotEmpty) {
          final searchLower = params.searchQuery!.toLowerCase();
          filteredResults = filteredResults
              .where(
                (b) =>
                    b.category.target?.name.toLowerCase().contains(
                      searchLower,
                    ) ??
                    false,
              )
              .toList();
        }

        // * Cursor-based pagination (offset-based internally)
        final offset = params.cursor != null
            ? int.tryParse(params.cursor!) ?? 0
            : 0;

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

        logInfo('Budgets retrieved: ${budgets.length}, hasMore: $hasMore');

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
