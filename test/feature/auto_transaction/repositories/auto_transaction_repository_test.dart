import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_schedule_frequency.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_group.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_log.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_log_status.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/create_auto_group_params.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/create_auto_item_params.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/update_auto_group_params.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/update_auto_item_params.dart';
import 'package:ikuyo_finance/features/auto_transaction/repositories/auto_transaction_repository_impl.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';

import '../../../support/objectbox_test_store.dart';
import '../../../support/test_logger.dart';

void main() {
  late ObjectBoxTestStore testStore;
  late AutoTransactionRepositoryImpl repository;

  setUpAll(bootstrapTestLogger);

  setUp(() async {
    testStore = await ObjectBoxTestStore.open();
    repository = AutoTransactionRepositoryImpl(testStore.storage);
  });

  tearDown(() => testStore.close());

  /// Puts a bare-bones [Transaction] directly into the store so it can be
  /// used as the template referenced by an [AutoTransactionItem].
  Transaction createTransactionFixture({double amount = 10000}) {
    final transaction = Transaction(amount: amount);
    testStore.storage.box<Transaction>().put(transaction);
    return transaction;
  }

  Future<AutoTransactionGroup> createGroupFixture({
    String name = 'Salary auto-entry',
    AutoScheduleFrequency frequency = AutoScheduleFrequency.daily,
    int scheduleHour = 8,
    int scheduleMinute = 0,
    int intervalDays = 1,
    DateTime? startDate,
  }) async {
    final result = await repository
        .createGroup(
          CreateAutoGroupParams(
            name: name,
            frequency: frequency,
            scheduleHour: scheduleHour,
            scheduleMinute: scheduleMinute,
            intervalDays: intervalDays,
            startDate: startDate ?? DateTime.now(),
          ),
        )
        .run();
    return result.getOrElse((_) => throw Exception()).data!;
  }

  group('createGroup', () {
    test('persists a group and computes nextExecutedAt', () async {
      final result = await repository
          .createGroup(
            CreateAutoGroupParams(
              name: 'Rent',
              frequency: AutoScheduleFrequency.monthly,
              scheduleHour: 9,
              scheduleMinute: 0,
              dayOfMonth: 1,
              startDate: DateTime.now(),
            ),
          )
          .run();

      expect(result.isRight(), isTrue);
      final group = result.getOrElse((_) => throw Exception()).data!;
      expect(group.ulid, isNotEmpty);
      expect(group.name, 'Rent');
      expect(group.nextExecutedAt, isNotNull);
      expect(group.isActive, isTrue);
      expect(group.isPaused, isFalse);
    });

    test('allows up to 10 active groups sharing the same schedule time', () async {
      for (var i = 0; i < 10; i++) {
        final result = await repository
            .createGroup(
              CreateAutoGroupParams(
                name: 'Group $i',
                frequency: AutoScheduleFrequency.daily,
                scheduleHour: 7,
                scheduleMinute: 30,
                startDate: DateTime.now(),
              ),
            )
            .run();
        expect(result.isRight(), isTrue, reason: 'group $i should succeed');
      }
    });

    test('rejects the 11th group sharing the same schedule time', () async {
      for (var i = 0; i < 10; i++) {
        await repository
            .createGroup(
              CreateAutoGroupParams(
                name: 'Group $i',
                frequency: AutoScheduleFrequency.daily,
                scheduleHour: 7,
                scheduleMinute: 30,
                startDate: DateTime.now(),
              ),
            )
            .run();
      }

      final eleventh = await repository
          .createGroup(
            CreateAutoGroupParams(
              name: 'Group 11',
              frequency: AutoScheduleFrequency.daily,
              scheduleHour: 7,
              scheduleMinute: 30,
              startDate: DateTime.now(),
            ),
          )
          .run();

      expect(eleventh.isLeft(), isTrue);
    });
  });

  group('updateGroup', () {
    test('updates the name and description', () async {
      final group = await createGroupFixture();

      final result = await repository
          .updateGroup(
            UpdateAutoGroupParams(
              ulid: group.ulid,
              name: 'New name',
              description: () => 'New description',
            ),
          )
          .run();

      final updated = result.getOrElse((_) => throw Exception()).data!;
      expect(updated.name, 'New name');
      expect(updated.description, 'New description');
    });

    test('recalculates nextExecutedAt when the schedule changes', () async {
      final group = await createGroupFixture(
        frequency: AutoScheduleFrequency.daily,
        scheduleHour: 8,
        scheduleMinute: 0,
      );
      final originalNext = group.nextExecutedAt;

      final result = await repository
          .updateGroup(
            UpdateAutoGroupParams(ulid: group.ulid, scheduleHour: 20, scheduleMinute: 30),
          )
          .run();

      final updated = result.getOrElse((_) => throw Exception()).data!;
      expect(updated.scheduleHour, 20);
      expect(updated.scheduleMinute, 30);
      expect(updated.nextExecutedAt, isNot(originalNext));
    });

    test('does not recalculate nextExecutedAt when the schedule is untouched', () async {
      final group = await createGroupFixture();
      final originalNext = group.nextExecutedAt;

      final result = await repository
          .updateGroup(UpdateAutoGroupParams(ulid: group.ulid, name: 'Renamed only'))
          .run();

      final updated = result.getOrElse((_) => throw Exception()).data!;
      expect(updated.nextExecutedAt, originalNext);
    });

    test('fails for an unknown ulid', () async {
      final result = await repository
          .updateGroup(const UpdateAutoGroupParams(ulid: 'unknown', name: 'x'))
          .run();

      expect(result.isLeft(), isTrue);
    });

    test('rejects a schedule-time change that would exceed the 10-group cap', () async {
      for (var i = 0; i < 10; i++) {
        await repository
            .createGroup(
              CreateAutoGroupParams(
                name: 'Group $i',
                frequency: AutoScheduleFrequency.daily,
                scheduleHour: 6,
                scheduleMinute: 0,
                startDate: DateTime.now(),
              ),
            )
            .run();
      }
      final other = await createGroupFixture(
        name: 'Other time',
        scheduleHour: 12,
        scheduleMinute: 0,
      );

      final result = await repository
          .updateGroup(
            UpdateAutoGroupParams(ulid: other.ulid, scheduleHour: 6, scheduleMinute: 0),
          )
          .run();

      expect(result.isLeft(), isTrue);
    });
  });

  group('deleteGroup', () {
    test('removes the group along with its items and logs', () async {
      final group = await createGroupFixture();
      final transaction = createTransactionFixture();
      await repository
          .createItem(
            CreateAutoItemParams(
              groupUlid: group.ulid,
              transactionUlid: transaction.ulid,
              sortOrder: 0,
            ),
          )
          .run();
      final log = AutoTransactionLog(scheduledAt: DateTime.now(), executedAt: DateTime.now());
      log.group.target = group;
      await repository.saveExecutionLog(log).run();

      final result = await repository.deleteGroup(ulid: group.ulid).run();

      expect(result.isRight(), isTrue);
      final getResult = await repository.getGroupByUlid(ulid: group.ulid).run();
      expect(getResult.isLeft(), isTrue);
      expect(
        (await repository.getItemsByGroup(groupUlid: group.ulid).run()).isLeft(),
        isTrue,
      );
    });

    test('fails for an unknown ulid', () async {
      final result = await repository.deleteGroup(ulid: 'unknown').run();

      expect(result.isLeft(), isTrue);
    });
  });

  group('getGroups', () {
    test('returns all groups sorted by createdAt descending', () async {
      await createGroupFixture(name: 'First');
      await createGroupFixture(name: 'Second');
      await createGroupFixture(name: 'Third');

      final result = await repository.getGroups().run();

      final groups = result.getOrElse((_) => throw Exception()).data!;
      expect(groups, hasLength(3));
      expect(groups.first.name, 'Third');
      expect(groups.last.name, 'First');
    });

    test('returns an empty list when there is no data', () async {
      final result = await repository.getGroups().run();

      final groups = result.getOrElse((_) => throw Exception()).data!;
      expect(groups, isEmpty);
    });
  });

  group('getGroupByUlid', () {
    test('returns the matching group', () async {
      final group = await createGroupFixture(name: 'Findable');

      final result = await repository.getGroupByUlid(ulid: group.ulid).run();

      expect(result.isRight(), isTrue);
      expect(result.getOrElse((_) => throw Exception()).data!.name, 'Findable');
    });

    test('fails for an unknown ulid', () async {
      final result = await repository.getGroupByUlid(ulid: 'unknown').run();

      expect(result.isLeft(), isTrue);
    });
  });

  group('createItem', () {
    test('creates an item linked to the group and transaction template', () async {
      final group = await createGroupFixture();
      final transaction = createTransactionFixture();

      final result = await repository
          .createItem(
            CreateAutoItemParams(
              groupUlid: group.ulid,
              transactionUlid: transaction.ulid,
              sortOrder: 0,
            ),
          )
          .run();

      expect(result.isRight(), isTrue);
      final item = result.getOrElse((_) => throw Exception()).data!;
      expect(item.group.target?.ulid, group.ulid);
      expect(item.transaction.target?.ulid, transaction.ulid);
      expect(item.isActive, isTrue);
    });

    test('fails when the group does not exist', () async {
      final transaction = createTransactionFixture();

      final result = await repository
          .createItem(
            CreateAutoItemParams(
              groupUlid: 'unknown',
              transactionUlid: transaction.ulid,
              sortOrder: 0,
            ),
          )
          .run();

      expect(result.isLeft(), isTrue);
    });

    test('fails when the transaction template does not exist', () async {
      final group = await createGroupFixture();

      final result = await repository
          .createItem(
            CreateAutoItemParams(
              groupUlid: group.ulid,
              transactionUlid: 'unknown',
              sortOrder: 0,
            ),
          )
          .run();

      expect(result.isLeft(), isTrue);
    });

    test('allows up to 20 active items in a group', () async {
      final group = await createGroupFixture();
      final transaction = createTransactionFixture();

      for (var i = 0; i < 20; i++) {
        final result = await repository
            .createItem(
              CreateAutoItemParams(
                groupUlid: group.ulid,
                transactionUlid: transaction.ulid,
                sortOrder: i,
              ),
            )
            .run();
        expect(result.isRight(), isTrue, reason: 'item $i should succeed');
      }
    });

    test('rejects the 21st active item in a group', () async {
      final group = await createGroupFixture();
      final transaction = createTransactionFixture();

      for (var i = 0; i < 20; i++) {
        await repository
            .createItem(
              CreateAutoItemParams(
                groupUlid: group.ulid,
                transactionUlid: transaction.ulid,
                sortOrder: i,
              ),
            )
            .run();
      }

      final result = await repository
          .createItem(
            CreateAutoItemParams(
              groupUlid: group.ulid,
              transactionUlid: transaction.ulid,
              sortOrder: 20,
            ),
          )
          .run();

      expect(result.isLeft(), isTrue);
    });
  });

  group('updateItem', () {
    test('updates sortOrder and isActive', () async {
      final group = await createGroupFixture();
      final transaction = createTransactionFixture();
      final item = (await repository
              .createItem(
                CreateAutoItemParams(
                  groupUlid: group.ulid,
                  transactionUlid: transaction.ulid,
                  sortOrder: 0,
                ),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;

      final result = await repository
          .updateItem(UpdateAutoItemParams(ulid: item.ulid, sortOrder: 5, isActive: false))
          .run();

      final updated = result.getOrElse((_) => throw Exception()).data!;
      expect(updated.sortOrder, 5);
      expect(updated.isActive, isFalse);
    });

    test('fails for an unknown ulid', () async {
      final result = await repository
          .updateItem(const UpdateAutoItemParams(ulid: 'unknown', sortOrder: 1))
          .run();

      expect(result.isLeft(), isTrue);
    });
  });

  group('deleteItem', () {
    test('removes the item', () async {
      final group = await createGroupFixture();
      final transaction = createTransactionFixture();
      final item = (await repository
              .createItem(
                CreateAutoItemParams(
                  groupUlid: group.ulid,
                  transactionUlid: transaction.ulid,
                  sortOrder: 0,
                ),
              )
              .run())
          .getOrElse((_) => throw Exception())
          .data!;

      final result = await repository.deleteItem(ulid: item.ulid).run();

      expect(result.isRight(), isTrue);
      final items = (await repository.getItemsByGroup(groupUlid: group.ulid).run())
          .getOrElse((_) => throw Exception())
          .data!;
      expect(items, isEmpty);
    });

    test('fails for an unknown ulid', () async {
      final result = await repository.deleteItem(ulid: 'unknown').run();

      expect(result.isLeft(), isTrue);
    });
  });

  group('getItemsByGroup', () {
    test('returns items ordered by sortOrder', () async {
      final group = await createGroupFixture();
      final transaction = createTransactionFixture();
      for (final order in [2, 0, 1]) {
        await repository
            .createItem(
              CreateAutoItemParams(
                groupUlid: group.ulid,
                transactionUlid: transaction.ulid,
                sortOrder: order,
              ),
            )
            .run();
      }

      final result = await repository.getItemsByGroup(groupUlid: group.ulid).run();

      final items = result.getOrElse((_) => throw Exception()).data!;
      expect(items.map((i) => i.sortOrder), [0, 1, 2]);
    });

    test('fails when the group does not exist', () async {
      final result = await repository.getItemsByGroup(groupUlid: 'unknown').run();

      expect(result.isLeft(), isTrue);
    });
  });

  group('reorderItems', () {
    test('persists the new sortOrder in the given order', () async {
      final group = await createGroupFixture();
      final transaction = createTransactionFixture();
      final items = <String>[];
      for (var i = 0; i < 3; i++) {
        final item = (await repository
                .createItem(
                  CreateAutoItemParams(
                    groupUlid: group.ulid,
                    transactionUlid: transaction.ulid,
                    sortOrder: i,
                  ),
                )
                .run())
            .getOrElse((_) => throw Exception())
            .data!;
        items.add(item.ulid);
      }
      final reversedOrder = items.reversed.toList();

      final result = await repository
          .reorderItems(groupUlid: group.ulid, orderedUlids: reversedOrder)
          .run();

      expect(result.isRight(), isTrue);
      final persisted = (await repository.getItemsByGroup(groupUlid: group.ulid).run())
          .getOrElse((_) => throw Exception())
          .data!;
      expect(persisted.map((i) => i.ulid), reversedOrder);
    });

    test('fails when the group does not exist', () async {
      final result = await repository
          .reorderItems(groupUlid: 'unknown', orderedUlids: const [])
          .run();

      expect(result.isLeft(), isTrue);
    });
  });

  group('pauseGroup / resumeGroup', () {
    test('pauseGroup sets isPaused with a scheduled resume date', () async {
      final group = await createGroupFixture();
      final resumeAt = DateTime.now().add(const Duration(days: 3));

      final result = await repository.pauseGroup(ulid: group.ulid, resumeAt: resumeAt).run();

      expect(result.isRight(), isTrue);
      final refreshed = (await repository.getGroupByUlid(ulid: group.ulid).run())
          .getOrElse((_) => throw Exception())
          .data!;
      expect(refreshed.isPaused, isTrue);
      // * ObjectBox stores DateTime with millisecond precision, so compare
      // * truncated to milliseconds rather than exact (microsecond) equality.
      expect(
        refreshed.pauseEndAt!.millisecondsSinceEpoch,
        resumeAt.millisecondsSinceEpoch,
      );
      expect(refreshed.isCurrentlyPaused(), isTrue);
    });

    test('pauseGroup without a resume date pauses manually (pauseEndAt null)', () async {
      final group = await createGroupFixture();

      await repository.pauseGroup(ulid: group.ulid).run();

      final refreshed = (await repository.getGroupByUlid(ulid: group.ulid).run())
          .getOrElse((_) => throw Exception())
          .data!;
      expect(refreshed.isPaused, isTrue);
      expect(refreshed.pauseEndAt, isNull);
      expect(refreshed.isCurrentlyPaused(), isTrue);
    });

    test('resumeGroup clears pause fields', () async {
      final group = await createGroupFixture();
      await repository
          .pauseGroup(
            ulid: group.ulid,
            resumeAt: DateTime.now().add(const Duration(days: 1)),
          )
          .run();

      final result = await repository.resumeGroup(ulid: group.ulid).run();

      expect(result.isRight(), isTrue);
      final refreshed = (await repository.getGroupByUlid(ulid: group.ulid).run())
          .getOrElse((_) => throw Exception())
          .data!;
      expect(refreshed.isPaused, isFalse);
      expect(refreshed.pauseStartAt, isNull);
      expect(refreshed.pauseEndAt, isNull);
    });

    test('pauseGroup fails for an unknown ulid', () async {
      final result = await repository.pauseGroup(ulid: 'unknown').run();

      expect(result.isLeft(), isTrue);
    });

    test('resumeGroup fails for an unknown ulid', () async {
      final result = await repository.resumeGroup(ulid: 'unknown').run();

      expect(result.isLeft(), isTrue);
    });
  });

  group('toggleGroup', () {
    test('deactivates and reactivates a group', () async {
      final group = await createGroupFixture();

      final offResult = await repository.toggleGroup(ulid: group.ulid, isActive: false).run();
      expect(offResult.isRight(), isTrue);
      var refreshed = (await repository.getGroupByUlid(ulid: group.ulid).run())
          .getOrElse((_) => throw Exception())
          .data!;
      expect(refreshed.isActive, isFalse);

      final onResult = await repository.toggleGroup(ulid: group.ulid, isActive: true).run();
      expect(onResult.isRight(), isTrue);
      refreshed = (await repository.getGroupByUlid(ulid: group.ulid).run())
          .getOrElse((_) => throw Exception())
          .data!;
      expect(refreshed.isActive, isTrue);
    });

    test('fails for an unknown ulid', () async {
      final result = await repository.toggleGroup(ulid: 'unknown', isActive: false).run();

      expect(result.isLeft(), isTrue);
    });
  });

  group('getPendingGroups', () {
    test('includes an active group whose nextExecutedAt is exactly now (boundary)', () async {
      final group = await createGroupFixture();
      final now = DateTime.now();
      await repository
          .updateGroupAfterExecution(
            ulid: group.ulid,
            nextExecutedAt: now,
            lastExecutedAt: now,
            isActive: true,
          )
          .run();

      final result = await repository.getPendingGroups().run();

      final pending = result.getOrElse((_) => throw Exception()).data!;
      expect(pending.any((g) => g.ulid == group.ulid), isTrue);
    });

    test('includes an active group whose nextExecutedAt is in the past', () async {
      final group = await createGroupFixture();
      await repository
          .updateGroupAfterExecution(
            ulid: group.ulid,
            nextExecutedAt: DateTime.now().subtract(const Duration(minutes: 5)),
            lastExecutedAt: DateTime.now(),
            isActive: true,
          )
          .run();

      final result = await repository.getPendingGroups().run();

      final pending = result.getOrElse((_) => throw Exception()).data!;
      expect(pending.any((g) => g.ulid == group.ulid), isTrue);
    });

    test('excludes a group whose nextExecutedAt is in the future', () async {
      final group = await createGroupFixture();
      await repository
          .updateGroupAfterExecution(
            ulid: group.ulid,
            nextExecutedAt: DateTime.now().add(const Duration(days: 1)),
            lastExecutedAt: DateTime.now(),
            isActive: true,
          )
          .run();

      final result = await repository.getPendingGroups().run();

      final pending = result.getOrElse((_) => throw Exception()).data!;
      expect(pending.any((g) => g.ulid == group.ulid), isFalse);
    });

    test('excludes an inactive group even if nextExecutedAt is due', () async {
      final group = await createGroupFixture();
      await repository
          .updateGroupAfterExecution(
            ulid: group.ulid,
            nextExecutedAt: DateTime.now().subtract(const Duration(minutes: 5)),
            lastExecutedAt: DateTime.now(),
            isActive: false,
          )
          .run();

      final result = await repository.getPendingGroups().run();

      final pending = result.getOrElse((_) => throw Exception()).data!;
      expect(pending.any((g) => g.ulid == group.ulid), isFalse);
    });
  });

  group('updateGroupAfterExecution', () {
    test('persists nextExecutedAt, lastExecutedAt and isActive', () async {
      final group = await createGroupFixture();
      final nextExecutedAt = DateTime.now().add(const Duration(days: 2));
      final lastExecutedAt = DateTime.now();

      final result = await repository
          .updateGroupAfterExecution(
            ulid: group.ulid,
            nextExecutedAt: nextExecutedAt,
            lastExecutedAt: lastExecutedAt,
            isActive: false,
          )
          .run();

      expect(result.isRight(), isTrue);
      final refreshed = (await repository.getGroupByUlid(ulid: group.ulid).run())
          .getOrElse((_) => throw Exception())
          .data!;
      // * ObjectBox stores DateTime with millisecond precision, so compare
      // * truncated to milliseconds rather than exact (microsecond) equality.
      expect(
        refreshed.nextExecutedAt!.millisecondsSinceEpoch,
        nextExecutedAt.millisecondsSinceEpoch,
      );
      expect(
        refreshed.lastExecutedAt!.millisecondsSinceEpoch,
        lastExecutedAt.millisecondsSinceEpoch,
      );
      expect(refreshed.isActive, isFalse);
    });

    test('fails for an unknown ulid', () async {
      final result = await repository
          .updateGroupAfterExecution(
            ulid: 'unknown',
            nextExecutedAt: DateTime.now(),
            lastExecutedAt: DateTime.now(),
            isActive: true,
          )
          .run();

      expect(result.isLeft(), isTrue);
    });
  });

  group('saveExecutionLog / getLogsByGroup / deleteLog', () {
    test('saves a log and retrieves it by group, newest first', () async {
      final group = await createGroupFixture();
      final olderLog = AutoTransactionLog(
        scheduledAt: DateTime.now().subtract(const Duration(days: 2)),
        executedAt: DateTime.now().subtract(const Duration(days: 2)),
        status: AutoTransactionLogStatus.success.index,
      )..group.target = group;
      final newerLog = AutoTransactionLog(
        scheduledAt: DateTime.now(),
        executedAt: DateTime.now(),
        status: AutoTransactionLogStatus.failed.index,
        errorMessage: 'insufficient balance',
      )..group.target = group;

      await repository.saveExecutionLog(olderLog).run();
      await repository.saveExecutionLog(newerLog).run();

      final result = await repository.getLogsByGroup(groupUlid: group.ulid).run();

      final logs = result.getOrElse((_) => throw Exception()).data!;
      expect(logs, hasLength(2));
      expect(logs.first.ulid, newerLog.ulid);
      expect(logs.last.ulid, olderLog.ulid);
      expect(logs.first.logStatus, AutoTransactionLogStatus.failed);
      expect(logs.first.errorMessage, 'insufficient balance');
    });

    test('getLogsByGroup fails when the group does not exist', () async {
      final result = await repository.getLogsByGroup(groupUlid: 'unknown').run();

      expect(result.isLeft(), isTrue);
    });

    test('deleteLog removes the log', () async {
      final group = await createGroupFixture();
      final log = AutoTransactionLog(scheduledAt: DateTime.now(), executedAt: DateTime.now())
        ..group.target = group;
      await repository.saveExecutionLog(log).run();

      final result = await repository.deleteLog(ulid: log.ulid).run();

      expect(result.isRight(), isTrue);
      final logs = (await repository.getLogsByGroup(groupUlid: group.ulid).run())
          .getOrElse((_) => throw Exception())
          .data!;
      expect(logs, isEmpty);
    });

    test('deleteLog fails for an unknown ulid', () async {
      final result = await repository.deleteLog(ulid: 'unknown').run();

      expect(result.isLeft(), isTrue);
    });
  });
}
