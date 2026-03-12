import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_group.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_item.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_log.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/create_auto_group_params.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/create_auto_item_params.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/update_auto_group_params.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/update_auto_item_params.dart';
import 'package:ikuyo_finance/features/auto_transaction/repositories/auto_transaction_repository.dart';

part 'auto_transaction_event.dart';
part 'auto_transaction_state.dart';

class AutoTransactionBloc
    extends Bloc<AutoTransactionEvent, AutoTransactionState> {
  AutoTransactionBloc(this._repo) : super(const AutoTransactionState()) {
    // * Group read
    on<AutoGroupFetched>(_onGroupFetched);

    // * Group write
    on<AutoGroupCreated>(_onGroupCreated);
    on<AutoGroupUpdated>(_onGroupUpdated);
    on<AutoGroupDeleted>(_onGroupDeleted);
    on<AutoGroupToggled>(_onGroupToggled);
    on<AutoGroupPaused>(_onGroupPaused);
    on<AutoGroupResumed>(_onGroupResumed);

    // * Group + item atomically
    on<AutoGroupWithItemCreated>(_onGroupWithItemCreated);

    // * Item read
    on<AutoItemsFetched>(_onItemsFetched);

    // * Item write
    on<AutoItemCreated>(_onItemCreated);
    on<AutoItemUpdated>(_onItemUpdated);
    on<AutoItemDeleted>(_onItemDeleted);
    on<AutoItemReordered>(_onItemReordered);

    // * Log read
    on<AutoLogsFetched>(_onLogsFetched);

    // * Reset
    on<AutoWriteStatusReset>(_onWriteStatusReset);
  }

  final AutoTransactionRepository _repo;

  // ─── Group read ───────────────────────────────────────────────────────────

  Future<void> _onGroupFetched(
    AutoGroupFetched event,
    Emitter<AutoTransactionState> emit,
  ) async {
    emit(state.copyWith(status: AutoTransactionStatus.loading));

    final result = await _repo.getGroups().run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: AutoTransactionStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: AutoTransactionStatus.success,
          groups: success.data ?? [],
          errorMessage: () => null,
        ),
      ),
    );
  }

  // ─── Group write ──────────────────────────────────────────────────────────

  Future<void> _onGroupCreated(
    AutoGroupCreated event,
    Emitter<AutoTransactionState> emit,
  ) async {
    emit(state.copyWith(writeStatus: AutoTransactionWriteStatus.loading));

    final result = await _repo.createGroup(event.params).run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          writeStatus: AutoTransactionWriteStatus.failure,
          writeErrorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          writeStatus: AutoTransactionWriteStatus.success,
          writeSuccessMessage: () => success.message,
          groups: [success.data!, ...state.groups],
        ),
      ),
    );
  }

  Future<void> _onGroupUpdated(
    AutoGroupUpdated event,
    Emitter<AutoTransactionState> emit,
  ) async {
    emit(state.copyWith(writeStatus: AutoTransactionWriteStatus.loading));

    final result = await _repo.updateGroup(event.params).run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          writeStatus: AutoTransactionWriteStatus.failure,
          writeErrorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          writeStatus: AutoTransactionWriteStatus.success,
          writeSuccessMessage: () => success.message,
          groups: state.groups
              .map((g) => g.ulid == event.params.ulid ? success.data! : g)
              .toList(),
        ),
      ),
    );
  }

  Future<void> _onGroupDeleted(
    AutoGroupDeleted event,
    Emitter<AutoTransactionState> emit,
  ) async {
    emit(state.copyWith(writeStatus: AutoTransactionWriteStatus.loading));

    final result = await _repo.deleteGroup(ulid: event.ulid).run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          writeStatus: AutoTransactionWriteStatus.failure,
          writeErrorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          writeStatus: AutoTransactionWriteStatus.success,
          writeSuccessMessage: () => success.message,
          groups: state.groups.where((g) => g.ulid != event.ulid).toList(),
        ),
      ),
    );
  }

  Future<void> _onGroupToggled(
    AutoGroupToggled event,
    Emitter<AutoTransactionState> emit,
  ) async {
    emit(state.copyWith(writeStatus: AutoTransactionWriteStatus.loading));

    final result = await _repo
        .toggleGroup(ulid: event.ulid, isActive: event.isActive)
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          writeStatus: AutoTransactionWriteStatus.failure,
          writeErrorMessage: () => failure.message,
        ),
      ),
      (success) {
        // * Mutate entity in place — state emits due to writeStatus change
        for (final g in state.groups) {
          if (g.ulid == event.ulid) {
            g.isActive = event.isActive;
            break;
          }
        }
        emit(
          state.copyWith(
            writeStatus: AutoTransactionWriteStatus.success,
            writeSuccessMessage: () => success.message,
            groups: [...state.groups],
          ),
        );
      },
    );
  }

  Future<void> _onGroupPaused(
    AutoGroupPaused event,
    Emitter<AutoTransactionState> emit,
  ) async {
    emit(state.copyWith(writeStatus: AutoTransactionWriteStatus.loading));

    final result = await _repo
        .pauseGroup(
          ulid: event.ulid,
          pauseStartAt: event.pauseStartAt,
          resumeAt: event.resumeAt,
        )
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          writeStatus: AutoTransactionWriteStatus.failure,
          writeErrorMessage: () => failure.message,
        ),
      ),
      (success) {
        for (final g in state.groups) {
          if (g.ulid == event.ulid) {
            g.isPaused = true;
            g.pauseStartAt = event.pauseStartAt ?? DateTime.now();
            g.pauseEndAt = event.resumeAt;
            break;
          }
        }
        emit(
          state.copyWith(
            writeStatus: AutoTransactionWriteStatus.success,
            writeSuccessMessage: () => success.message,
            groups: [...state.groups],
          ),
        );
      },
    );
  }

  Future<void> _onGroupResumed(
    AutoGroupResumed event,
    Emitter<AutoTransactionState> emit,
  ) async {
    emit(state.copyWith(writeStatus: AutoTransactionWriteStatus.loading));

    final result = await _repo.resumeGroup(ulid: event.ulid).run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          writeStatus: AutoTransactionWriteStatus.failure,
          writeErrorMessage: () => failure.message,
        ),
      ),
      (success) {
        for (final g in state.groups) {
          if (g.ulid == event.ulid) {
            g.isPaused = false;
            g.pauseStartAt = null;
            g.pauseEndAt = null;
            break;
          }
        }
        emit(
          state.copyWith(
            writeStatus: AutoTransactionWriteStatus.success,
            writeSuccessMessage: () => success.message,
            groups: [...state.groups],
          ),
        );
      },
    );
  }

  // ─── Group + item (quick single-item mode) ────────────────────────────────

  Future<void> _onGroupWithItemCreated(
    AutoGroupWithItemCreated event,
    Emitter<AutoTransactionState> emit,
  ) async {
    emit(state.copyWith(writeStatus: AutoTransactionWriteStatus.loading));

    final groupResult = await _repo.createGroup(event.groupParams).run();

    bool failed = false;
    AutoTransactionGroup? createdGroup;
    groupResult.fold((failure) {
      failed = true;
      emit(
        state.copyWith(
          writeStatus: AutoTransactionWriteStatus.failure,
          writeErrorMessage: () => failure.message,
        ),
      );
    }, (success) => createdGroup = success.data!);
    if (failed) return;

    final itemResult = await _repo
        .createItem(
          CreateAutoItemParams(
            groupUlid: createdGroup!.ulid,
            transactionUlid: event.transactionUlid,
            sortOrder: 0,
          ),
        )
        .run();

    itemResult.fold(
      (failure) => emit(
        state.copyWith(
          writeStatus: AutoTransactionWriteStatus.failure,
          writeErrorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          writeStatus: AutoTransactionWriteStatus.success,
          writeSuccessMessage: () => 'Grup berhasil dibuat',
          groups: [createdGroup!, ...state.groups],
          currentItems: [success.data!],
        ),
      ),
    );
  }

  // ─── Item read ────────────────────────────────────────────────────────────

  Future<void> _onItemsFetched(
    AutoItemsFetched event,
    Emitter<AutoTransactionState> emit,
  ) async {
    emit(state.copyWith(status: AutoTransactionStatus.loading));

    final result = await _repo
        .getItemsByGroup(groupUlid: event.groupUlid)
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: AutoTransactionStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: AutoTransactionStatus.success,
          currentItems: success.data ?? [],
          errorMessage: () => null,
        ),
      ),
    );
  }

  // ─── Item write ───────────────────────────────────────────────────────────

  Future<void> _onItemCreated(
    AutoItemCreated event,
    Emitter<AutoTransactionState> emit,
  ) async {
    emit(state.copyWith(writeStatus: AutoTransactionWriteStatus.loading));

    // * Capture count before creation to detect 1→2 transition
    final wasOnlyItem = state.currentItems.length == 1;

    final result = await _repo.createItem(event.params).run();

    bool creationSucceeded = false;
    result.fold(
      (failure) => emit(
        state.copyWith(
          writeStatus: AutoTransactionWriteStatus.failure,
          writeErrorMessage: () => failure.message,
        ),
      ),
      (success) {
        creationSucceeded = true;
        emit(
          state.copyWith(
            writeStatus: AutoTransactionWriteStatus.success,
            writeSuccessMessage: () => success.message,
            currentItems: [...state.currentItems, success.data!],
          ),
        );
      },
    );

    // * Auto-clear group name & description when transitioning from 1 item → 2 items
    if (creationSucceeded && wasOnlyItem) {
      final groupUpdateResult = await _repo
          .updateGroup(
            UpdateAutoGroupParams(
              ulid: event.params.groupUlid,
              name: '',
              description: () => null,
            ),
          )
          .run();
      groupUpdateResult.fold(
        (f) => null,
        (s) => emit(
          state.copyWith(
            groups: state.groups
                .map((g) => g.ulid == event.params.groupUlid ? s.data! : g)
                .toList(),
          ),
        ),
      );
    }
  }

  Future<void> _onItemUpdated(
    AutoItemUpdated event,
    Emitter<AutoTransactionState> emit,
  ) async {
    emit(state.copyWith(writeStatus: AutoTransactionWriteStatus.loading));

    final result = await _repo.updateItem(event.params).run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          writeStatus: AutoTransactionWriteStatus.failure,
          writeErrorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          writeStatus: AutoTransactionWriteStatus.success,
          writeSuccessMessage: () => success.message,
          currentItems: state.currentItems
              .map((i) => i.ulid == event.params.ulid ? success.data! : i)
              .toList(),
        ),
      ),
    );
  }

  Future<void> _onItemDeleted(
    AutoItemDeleted event,
    Emitter<AutoTransactionState> emit,
  ) async {
    emit(state.copyWith(writeStatus: AutoTransactionWriteStatus.loading));

    final result = await _repo.deleteItem(ulid: event.ulid).run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          writeStatus: AutoTransactionWriteStatus.failure,
          writeErrorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          writeStatus: AutoTransactionWriteStatus.success,
          writeSuccessMessage: () => success.message,
          currentItems: state.currentItems
              .where((i) => i.ulid != event.ulid)
              .toList(),
        ),
      ),
    );
  }

  Future<void> _onItemReordered(
    AutoItemReordered event,
    Emitter<AutoTransactionState> emit,
  ) async {
    emit(state.copyWith(writeStatus: AutoTransactionWriteStatus.loading));

    final result = await _repo
        .reorderItems(
          groupUlid: event.groupUlid,
          orderedUlids: event.orderedUlids,
        )
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          writeStatus: AutoTransactionWriteStatus.failure,
          writeErrorMessage: () => failure.message,
        ),
      ),
      (success) {
        final reordered = event.orderedUlids
            .map((ulid) => state.currentItems.firstWhere((i) => i.ulid == ulid))
            .toList();
        emit(
          state.copyWith(
            writeStatus: AutoTransactionWriteStatus.success,
            writeSuccessMessage: () => success.message,
            currentItems: reordered,
          ),
        );
      },
    );
  }

  // ─── Log read ─────────────────────────────────────────────────────────────

  Future<void> _onLogsFetched(
    AutoLogsFetched event,
    Emitter<AutoTransactionState> emit,
  ) async {
    emit(state.copyWith(status: AutoTransactionStatus.loading));

    final result = await _repo.getLogsByGroup(groupUlid: event.groupUlid).run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: AutoTransactionStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: AutoTransactionStatus.success,
          currentLogs: success.data ?? [],
          errorMessage: () => null,
        ),
      ),
    );
  }

  // ─── Reset ────────────────────────────────────────────────────────────────

  void _onWriteStatusReset(
    AutoWriteStatusReset event,
    Emitter<AutoTransactionState> emit,
  ) {
    emit(
      state.copyWith(
        writeStatus: AutoTransactionWriteStatus.initial,
        writeSuccessMessage: () => null,
        writeErrorMessage: () => null,
      ),
    );
  }
}
