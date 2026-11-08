// Regression: NEW-4 (BudgetRefreshed and the other list reads ran with the
// default concurrent transformer, so overlapping refreshes - transaction
// listener, app resume, category change - or a period change during a
// refresh could finish out of order and leave an older result, error or
// filter on screen). The latest started read must decide the final state.
// Real BudgetBloc; only the repository is faked, and each getBudgets call is
// completed by hand so the completion order is deterministic (no sleeps).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ikuyo_finance/core/wrapper/failure.dart';
import 'package:ikuyo_finance/core/wrapper/success.dart';
import 'package:ikuyo_finance/features/budget/bloc/budget_bloc.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/budget/models/budget_progress.dart';
import 'package:ikuyo_finance/features/budget/models/create_budget_params.dart';
import 'package:ikuyo_finance/features/budget/models/get_budgets_params.dart';
import 'package:ikuyo_finance/features/budget/models/update_budget_params.dart';
import 'package:ikuyo_finance/features/budget/repositories/budget_repository.dart';

typedef _Page = Either<Failure, SuccessCursor<Budget>>;

class _Call {
  _Call(this.params);
  final GetBudgetsParams params;
  final completer = Completer<_Page>();

  void succeed(List<Budget> budgets, {bool hasNextPage = false}) =>
      completer.complete(
        Right(
          SuccessCursor(
            message: 'ok',
            data: budgets,
            cursor: CursorInfo(
              nextCursor: hasNextPage ? 'next' : '',
              hasNextPage: hasNextPage,
              perPage: 20,
            ),
          ),
        ),
      );

  void fail(String message) =>
      completer.complete(Left(Failure(message: message)));
}

class _ControlledBudgetRepository implements BudgetRepository {
  final calls = <_Call>[];

  @override
  TaskEither<Failure, SuccessCursor<Budget>> getBudgets(
    GetBudgetsParams params,
  ) {
    final call = _Call(params);
    calls.add(call);
    return TaskEither(() => call.completer.future);
  }

  @override
  TaskEither<Failure, Success<Map<String, BudgetProgress>>> getBudgetsProgress({
    required List<Budget> budgets,
    DateTime? now,
  }) => TaskEither.right(const Success(data: {}));

  @override
  TaskEither<Failure, Success<Budget>> createBudget(CreateBudgetParams p) =>
      throw UnimplementedError();
  @override
  TaskEither<Failure, Success<Budget>> getBudgetById({required String ulid}) =>
      throw UnimplementedError();
  @override
  TaskEither<Failure, Success<Budget>> updateBudget(UpdateBudgetParams p) =>
      throw UnimplementedError();
  @override
  TaskEither<Failure, ActionSuccess> deleteBudget({required String ulid}) =>
      throw UnimplementedError();
  @override
  TaskEither<Failure, Success<BudgetProgress>> getBudgetProgress({
    required String ulid,
    DateTime? now,
  }) => throw UnimplementedError();
}

void main() {
  late _ControlledBudgetRepository repo;
  late BudgetBloc bloc;
  late List<BudgetState> emitted;
  late StreamSubscription<BudgetState> sub;

  final older = Budget(ulid: 'older', amountLimit: 1);
  final newer = Budget(ulid: 'newer', amountLimit: 2);

  List<String> ulids() => bloc.state.budgets.map((b) => b.ulid).toList();

  setUp(() {
    repo = _ControlledBudgetRepository();
    bloc = BudgetBloc(repo);
    emitted = [];
    sub = bloc.stream.listen(emitted.add);
  });

  tearDown(() async {
    await sub.cancel();
    await bloc.close();
  });

  Future<void> twoRefreshes() async {
    bloc
      ..add(const BudgetRefreshed())
      ..add(const BudgetRefreshed());
    await pumpEventQueue();
    expect(repo.calls, hasLength(2));
  }

  test(
    'NEW-4 newer refresh finishing first is not overwritten by the older',
    () async {
      await twoRefreshes();
      repo.calls[1].succeed([newer]);
      await pumpEventQueue();
      expect(bloc.state.status, BudgetStatus.success);
      expect(ulids(), ['newer']);

      repo.calls[0].succeed([older]);
      await pumpEventQueue();
      expect(ulids(), ['newer']);
      expect(bloc.state.status, BudgetStatus.success);
    },
  );

  test(
    'NEW-4 a late failure of the older refresh does not replace newer data',
    () async {
      await twoRefreshes();
      repo.calls[1].succeed([newer]);
      await pumpEventQueue();
      repo.calls[0].fail('old failure');
      await pumpEventQueue();
      expect(bloc.state.status, BudgetStatus.success);
      expect(bloc.state.errorMessage, isNull);
      expect(ulids(), ['newer']);
    },
  );

  test(
    'NEW-4 the newer refresh error wins over a late older success',
    () async {
      await twoRefreshes();
      repo.calls[1].fail('new failure');
      await pumpEventQueue();
      repo.calls[0].succeed([older]);
      await pumpEventQueue();
      expect(bloc.state.status, BudgetStatus.failure);
      expect(bloc.state.errorMessage, 'new failure');
    },
  );

  test(
    'NEW-4 an older refresh finishing first keeps loading until the newer',
    () async {
      await twoRefreshes();
      repo.calls[0].succeed([older]);
      await pumpEventQueue();
      expect(bloc.state.status, BudgetStatus.loading);

      repo.calls[1].succeed([newer]);
      await pumpEventQueue();
      expect(bloc.state.status, BudgetStatus.success);
      expect(ulids(), ['newer']);
      // * exactly one terminal state, the newer one
      expect(
        emitted
            .where((s) => s.status != BudgetStatus.loading)
            .map((s) => s.budgets.map((b) => b.ulid).toList()),
        [
          ['newer'],
        ],
      );
    },
  );

  test('NEW-4 a refresh started before a period change cannot restore the old '
      'period data', () async {
    bloc
      ..add(const BudgetRefreshed())
      ..add(const BudgetFetched(period: BudgetPeriod.weekly));
    await pumpEventQueue();
    expect(repo.calls, hasLength(2));
    expect(repo.calls[0].params.period, isNull);
    expect(repo.calls[1].params.period, BudgetPeriod.weekly);

    repo.calls[1].succeed([newer]);
    await pumpEventQueue();
    repo.calls[0].succeed([older]);
    await pumpEventQueue();
    expect(bloc.state.currentPeriodFilter, BudgetPeriod.weekly);
    expect(ulids(), ['newer']);
  });

  test(
    'NEW-4 a load-more page overtaken by a refresh is not appended',
    () async {
      bloc.add(const BudgetRefreshed());
      await pumpEventQueue();
      repo.calls[0].succeed([older], hasNextPage: true);
      await pumpEventQueue();

      bloc.add(const BudgetFetchedMore());
      await pumpEventQueue();
      bloc.add(const BudgetRefreshed());
      await pumpEventQueue();
      expect(repo.calls, hasLength(3));

      repo.calls[2].succeed([newer]);
      await pumpEventQueue();
      repo.calls[1].succeed([Budget(ulid: 'page2', amountLimit: 3)]);
      await pumpEventQueue();
      expect(ulids(), ['newer']);
      expect(bloc.state.status, BudgetStatus.success);
    },
  );

  test(
    'NEW-4 load-more is not started while the first page is loading',
    () async {
      bloc.add(const BudgetRefreshed());
      await pumpEventQueue();
      bloc.add(const BudgetFetchedMore());
      await pumpEventQueue();
      expect(repo.calls, hasLength(1));

      repo.calls.single.succeed([newer], hasNextPage: true);
      await pumpEventQueue();
      expect(ulids(), ['newer']);
      bloc.add(const BudgetFetchedMore());
      await pumpEventQueue();
      expect(repo.calls, hasLength(2));
      expect(repo.calls[1].params.cursor, 'next');
    },
  );

  test('NEW-4 a single refresh still loads normally', () async {
    bloc.add(const BudgetRefreshed());
    await pumpEventQueue();
    expect(bloc.state.status, BudgetStatus.loading);
    repo.calls.single.succeed([newer]);
    await pumpEventQueue();
    expect(bloc.state.status, BudgetStatus.success);
    expect(ulids(), ['newer']);
  });

  test(
    'NEW-4 nothing is emitted after close while a refresh is in flight',
    () async {
      bloc.add(const BudgetRefreshed());
      await pumpEventQueue();
      final before = emitted.length;
      final closing = bloc.close();
      repo.calls.single.succeed([newer]);
      await closing;
      await pumpEventQueue();
      expect(bloc.isClosed, isTrue);
      expect(emitted.length, before);
    },
  );
}
