import 'package:fpdart/fpdart.dart';
import 'package:ikuyo_finance/core/wrapper/failure.dart';
import 'package:ikuyo_finance/core/wrapper/success.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/budget/models/budget_progress.dart';
import 'package:ikuyo_finance/features/budget/models/create_budget_params.dart';
import 'package:ikuyo_finance/features/budget/models/get_budgets_params.dart';
import 'package:ikuyo_finance/features/budget/models/update_budget_params.dart';

abstract class BudgetRepository {
  TaskEither<Failure, Success<Budget>> createBudget(CreateBudgetParams params);
  TaskEither<Failure, SuccessCursor<Budget>> getBudgets(
    GetBudgetsParams params,
  );
  TaskEither<Failure, Success<Budget>> getBudgetById({required String ulid});
  TaskEither<Failure, Success<Budget>> updateBudget(UpdateBudgetParams params);
  TaskEither<Failure, ActionSuccess> deleteBudget({required String ulid});

  /// Realisasi pengeluaran anggaran pada periode berjalan (AAOB-5)
  TaskEither<Failure, Success<BudgetProgress>> getBudgetProgress({
    required String ulid,
    DateTime? now,
  });

  /// Realisasi banyak anggaran sekaligus dengan kerja bersama (F7)
  TaskEither<Failure, Success<Map<String, BudgetProgress>>> getBudgetsProgress({
    required List<Budget> budgets,
    DateTime? now,
  });
}
