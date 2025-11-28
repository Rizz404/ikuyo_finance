part of 'budget_bloc.dart';

sealed class BudgetEvent {
  const BudgetEvent();
}

// * Read Events
final class BudgetFetched extends BudgetEvent {
  const BudgetFetched({this.period, this.categoryUlid});

  final BudgetPeriod? period;
  final String? categoryUlid;
}

final class BudgetFetchedMore extends BudgetEvent {
  const BudgetFetchedMore();
}

final class BudgetRefreshed extends BudgetEvent {
  const BudgetRefreshed();
}

// * Write Events
final class BudgetCreated extends BudgetEvent {
  final CreateBudgetParams params;

  const BudgetCreated({required this.params});
}

final class BudgetUpdated extends BudgetEvent {
  final UpdateBudgetParams params;

  const BudgetUpdated({required this.params});
}

final class BudgetDeleted extends BudgetEvent {
  const BudgetDeleted({required this.ulid});

  final String ulid;
}

// * Reset write status setelah UI handle
final class BudgetWriteStatusReset extends BudgetEvent {
  const BudgetWriteStatusReset();
}
