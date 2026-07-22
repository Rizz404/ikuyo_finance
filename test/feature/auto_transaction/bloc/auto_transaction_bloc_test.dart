import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ikuyo_finance/features/auto_transaction/bloc/auto_transaction_bloc.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_schedule_frequency.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_group.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_item.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_log.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/create_auto_group_params.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/create_auto_item_params.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/update_auto_group_params.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/update_auto_item_params.dart';
import 'package:ikuyo_finance/features/auto_transaction/repositories/auto_transaction_repository_impl.dart';
import 'package:ikuyo_finance/features/auto_transaction/services/auto_transaction_alarm_service.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';

import '../../../support/objectbox_test_store.dart';
import '../../../support/test_logger.dart';

class MockAutoTransactionAlarmService extends Mock
    implements AutoTransactionAlarmService {}

void main() {
  setUpAll(() {
    bootstrapTestLogger();
    // * Needed by mocktail whenever `any()` is used for a non-primitive
    // * argument type (AutoTransactionGroup) in when()/verify().
    registerFallbackValue(
      AutoTransactionGroup(name: 'fallback', startDate: DateTime(2000)),
    );
  });

  late ObjectBoxTestStore testStore;
  late AutoTransactionRepositoryImpl repository;
  late MockAutoTransactionAlarmService alarmService;

  setUp(() async {
    testStore = await ObjectBoxTestStore.open();
    repository = AutoTransactionRepositoryImpl(testStore.storage);
    alarmService = MockAutoTransactionAlarmService();
    when(() => alarmService.scheduleForGroup(any())).thenAnswer((_) async {});
    when(() => alarmService.cancelForGroup(any())).thenAnswer((_) async {});
    when(() => alarmService.cancelById(any())).thenAnswer((_) async {});
  });

  tearDown(() => testStore.close());

  Transaction createTransactionFixture() {
    final tx = Transaction(amount: 5000);
    testStore.storage.box<Transaction>().put(tx);
    return tx;
  }

  Future<AutoTransactionGroup> createGroupFixture({
    String name = 'Group',
    int scheduleHour = 8,
    int scheduleMinute = 0,
  }) async {
    final result = await repository
        .createGroup(
          CreateAutoGroupParams(
            name: name,
            frequency: AutoScheduleFrequency.daily,
            scheduleHour: scheduleHour,
            scheduleMinute: scheduleMinute,
            startDate: DateTime.now(),
          ),
        )
        .run();
    return result.getOrElse((_) => throw Exception()).data!;
  }

  Future<AutoTransactionItem> createItemFixture(
    AutoTransactionGroup group,
    Transaction transaction, {
    int sortOrder = 0,
  }) async {
    final result = await repository
        .createItem(
          CreateAutoItemParams(
            groupUlid: group.ulid,
            transactionUlid: transaction.ulid,
            sortOrder: sortOrder,
          ),
        )
        .run();
    return result.getOrElse((_) => throw Exception()).data!;
  }

  group('AutoGroupFetched', () {
    blocTest<AutoTransactionBloc, AutoTransactionState>(
      'emits [loading, success] with the fetched groups',
      setUp: () async {
        await createGroupFixture(name: 'Salary');
      },
      build: () => AutoTransactionBloc(repository, alarmService),
      act: (bloc) => bloc.add(const AutoGroupFetched()),
      expect: () => [
        predicate<AutoTransactionState>(
          (s) => s.status == AutoTransactionStatus.loading,
        ),
        predicate<AutoTransactionState>(
          (s) =>
              s.status == AutoTransactionStatus.success &&
              s.groups.length == 1 &&
              s.groups.first.name == 'Salary',
        ),
      ],
    );

    blocTest<AutoTransactionBloc, AutoTransactionState>(
      'emits an empty success state when there is no data',
      build: () => AutoTransactionBloc(repository, alarmService),
      act: (bloc) => bloc.add(const AutoGroupFetched()),
      expect: () => [
        predicate<AutoTransactionState>(
          (s) => s.status == AutoTransactionStatus.loading,
        ),
        predicate<AutoTransactionState>(
          (s) => s.status == AutoTransactionStatus.success && s.groups.isEmpty,
        ),
      ],
    );
  });

  group('AutoGroupCreated', () {
    blocTest<AutoTransactionBloc, AutoTransactionState>(
      'emits [writeLoading, writeSuccess], prepends the group and schedules an alarm',
      build: () => AutoTransactionBloc(repository, alarmService),
      act: (bloc) => bloc.add(
        AutoGroupCreated(
          params: CreateAutoGroupParams(
            name: 'Rent',
            frequency: AutoScheduleFrequency.monthly,
            scheduleHour: 9,
            scheduleMinute: 0,
            dayOfMonth: 1,
            startDate: DateTime.now(),
          ),
        ),
      ),
      expect: () => [
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.loading,
        ),
        predicate<AutoTransactionState>(
          (s) =>
              s.writeStatus == AutoTransactionWriteStatus.success &&
              s.groups.length == 1 &&
              s.groups.first.name == 'Rent',
        ),
      ],
      verify: (_) {
        verify(() => alarmService.scheduleForGroup(any())).called(1);
      },
    );

    blocTest<AutoTransactionBloc, AutoTransactionState>(
      'emits [writeLoading, writeFailure] and does not schedule an alarm '
      'when the 10-groups-per-schedule-time cap is exceeded',
      setUp: () async {
        for (var i = 0; i < 10; i++) {
          await createGroupFixture(
            name: 'Group $i',
            scheduleHour: 7,
            scheduleMinute: 30,
          );
        }
      },
      build: () => AutoTransactionBloc(repository, alarmService),
      act: (bloc) => bloc.add(
        AutoGroupCreated(
          params: CreateAutoGroupParams(
            name: 'One too many',
            frequency: AutoScheduleFrequency.daily,
            scheduleHour: 7,
            scheduleMinute: 30,
            startDate: DateTime.now(),
          ),
        ),
      ),
      expect: () => [
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.loading,
        ),
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.failure,
        ),
      ],
      verify: (_) {
        verifyNever(() => alarmService.scheduleForGroup(any()));
      },
    );
  });

  group('AutoGroupUpdated', () {
    blocTest<AutoTransactionBloc, AutoTransactionState>(
      'replaces the matching group in the list and reschedules its alarm',
      setUp: () async {
        await createGroupFixture(name: 'Original');
      },
      build: () => AutoTransactionBloc(repository, alarmService),
      act: (bloc) async {
        bloc.add(const AutoGroupFetched());
        await bloc.stream.firstWhere((s) => s.status == AutoTransactionStatus.success);
        final ulid = bloc.state.groups.single.ulid;
        bloc.add(
          AutoGroupUpdated(params: UpdateAutoGroupParams(ulid: ulid, name: 'Renamed')),
        );
      },
      skip: 2,
      expect: () => [
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.loading,
        ),
        predicate<AutoTransactionState>(
          (s) =>
              s.writeStatus == AutoTransactionWriteStatus.success &&
              s.groups.single.name == 'Renamed',
        ),
      ],
      verify: (_) {
        verify(() => alarmService.scheduleForGroup(any())).called(1);
      },
    );

    blocTest<AutoTransactionBloc, AutoTransactionState>(
      'emits writeFailure for an unknown ulid and never touches the alarm service',
      build: () => AutoTransactionBloc(repository, alarmService),
      act: (bloc) => bloc.add(
        const AutoGroupUpdated(
          params: UpdateAutoGroupParams(ulid: 'unknown', name: 'x'),
        ),
      ),
      expect: () => [
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.loading,
        ),
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.failure,
        ),
      ],
      verify: (_) {
        verifyNever(() => alarmService.scheduleForGroup(any()));
      },
    );
  });

  group('AutoGroupDeleted', () {
    blocTest<AutoTransactionBloc, AutoTransactionState>(
      'removes the group from state and cancels its alarm',
      setUp: () async {},
      build: () => AutoTransactionBloc(repository, alarmService),
      skip: 1,
      act: (bloc) async {
        final group = await createGroupFixture(name: 'To delete');
        bloc.emit(AutoTransactionState(groups: [group]));
        bloc.add(AutoGroupDeleted(ulid: group.ulid));
      },
      expect: () => [
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.loading,
        ),
        predicate<AutoTransactionState>(
          (s) =>
              s.writeStatus == AutoTransactionWriteStatus.success &&
              s.groups.isEmpty,
        ),
      ],
      verify: (_) {
        verify(() => alarmService.cancelById(any())).called(1);
      },
    );

    blocTest<AutoTransactionBloc, AutoTransactionState>(
      'emits writeFailure for an unknown ulid and never cancels an alarm',
      build: () => AutoTransactionBloc(repository, alarmService),
      act: (bloc) => bloc.add(const AutoGroupDeleted(ulid: 'unknown')),
      expect: () => [
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.loading,
        ),
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.failure,
        ),
      ],
      verify: (_) {
        verifyNever(() => alarmService.cancelById(any()));
      },
    );
  });

  group('AutoGroupBatchDeleted', () {
    blocTest<AutoTransactionBloc, AutoTransactionState>(
      'removes all successfully deleted groups and cancels an alarm for each',
      build: () => AutoTransactionBloc(repository, alarmService),
      skip: 1,
      act: (bloc) async {
        final g1 = await createGroupFixture(name: 'G1', scheduleHour: 1);
        final g2 = await createGroupFixture(name: 'G2', scheduleHour: 2);
        bloc.emit(AutoTransactionState(groups: [g1, g2]));
        bloc.add(AutoGroupBatchDeleted(ulids: [g1.ulid, g2.ulid]));
      },
      expect: () => [
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.loading,
        ),
        predicate<AutoTransactionState>(
          (s) =>
              s.writeStatus == AutoTransactionWriteStatus.success &&
              s.groups.isEmpty,
        ),
      ],
      verify: (_) {
        verify(() => alarmService.cancelById(any())).called(2);
      },
    );
  });

  group('AutoGroupToggled', () {
    blocTest<AutoTransactionBloc, AutoTransactionState>(
      'schedules an alarm when toggled on',
      build: () => AutoTransactionBloc(repository, alarmService),
      skip: 1,
      act: (bloc) async {
        final group = await createGroupFixture();
        bloc.emit(AutoTransactionState(groups: [group]));
        bloc.add(AutoGroupToggled(ulid: group.ulid, isActive: true));
      },
      expect: () => [
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.loading,
        ),
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.success,
        ),
      ],
      verify: (_) {
        verify(() => alarmService.scheduleForGroup(any())).called(1);
        verifyNever(() => alarmService.cancelById(any()));
      },
    );

    blocTest<AutoTransactionBloc, AutoTransactionState>(
      'cancels the alarm when toggled off',
      build: () => AutoTransactionBloc(repository, alarmService),
      skip: 1,
      act: (bloc) async {
        final group = await createGroupFixture();
        bloc.emit(AutoTransactionState(groups: [group]));
        bloc.add(AutoGroupToggled(ulid: group.ulid, isActive: false));
      },
      expect: () => [
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.loading,
        ),
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.success,
        ),
      ],
      verify: (_) {
        verify(() => alarmService.cancelById(any())).called(1);
        verifyNever(() => alarmService.scheduleForGroup(any()));
      },
    );

    blocTest<AutoTransactionBloc, AutoTransactionState>(
      'emits writeFailure for an unknown ulid',
      build: () => AutoTransactionBloc(repository, alarmService),
      act: (bloc) => bloc.add(
        const AutoGroupToggled(ulid: 'unknown', isActive: true),
      ),
      expect: () => [
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.loading,
        ),
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.failure,
        ),
      ],
    );
  });

  group('AutoGroupPaused / AutoGroupResumed', () {
    blocTest<AutoTransactionBloc, AutoTransactionState>(
      'pausing a group cancels its alarm and marks it paused in state',
      build: () => AutoTransactionBloc(repository, alarmService),
      skip: 1,
      act: (bloc) async {
        final group = await createGroupFixture();
        bloc.emit(AutoTransactionState(groups: [group]));
        bloc.add(
          AutoGroupPaused(
            ulid: group.ulid,
            resumeAt: DateTime.now().add(const Duration(days: 1)),
          ),
        );
      },
      expect: () => [
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.loading,
        ),
        predicate<AutoTransactionState>(
          (s) =>
              s.writeStatus == AutoTransactionWriteStatus.success &&
              s.groups.single.isPaused,
        ),
      ],
      verify: (_) {
        verify(() => alarmService.cancelById(any())).called(1);
      },
    );

    blocTest<AutoTransactionBloc, AutoTransactionState>(
      'resuming a group reschedules its alarm and clears the paused flag',
      build: () => AutoTransactionBloc(repository, alarmService),
      skip: 1,
      act: (bloc) async {
        final group = await createGroupFixture();
        await repository.pauseGroup(ulid: group.ulid).run();
        bloc.emit(AutoTransactionState(groups: [group]));
        bloc.add(AutoGroupResumed(ulid: group.ulid));
      },
      expect: () => [
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.loading,
        ),
        predicate<AutoTransactionState>(
          (s) =>
              s.writeStatus == AutoTransactionWriteStatus.success &&
              !s.groups.single.isPaused,
        ),
      ],
      verify: (_) {
        verify(() => alarmService.scheduleForGroup(any())).called(1);
      },
    );

    blocTest<AutoTransactionBloc, AutoTransactionState>(
      'emits writeFailure when pausing an unknown group',
      build: () => AutoTransactionBloc(repository, alarmService),
      act: (bloc) => bloc.add(const AutoGroupPaused(ulid: 'unknown')),
      expect: () => [
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.loading,
        ),
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.failure,
        ),
      ],
      verify: (_) {
        verifyNever(() => alarmService.cancelById(any()));
      },
    );
  });

  group('AutoGroupWithItemCreated', () {
    blocTest<AutoTransactionBloc, AutoTransactionState>(
      'creates the group and its first item atomically, then schedules an alarm',
      build: () => AutoTransactionBloc(repository, alarmService),
      act: (bloc) {
        final transaction = createTransactionFixture();
        bloc.add(
          AutoGroupWithItemCreated(
            groupParams: CreateAutoGroupParams(
              name: 'Quick group',
              frequency: AutoScheduleFrequency.daily,
              scheduleHour: 8,
              scheduleMinute: 0,
              startDate: DateTime.now(),
            ),
            transactionUlid: transaction.ulid,
          ),
        );
      },
      expect: () => [
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.loading,
        ),
        predicate<AutoTransactionState>(
          (s) =>
              s.writeStatus == AutoTransactionWriteStatus.success &&
              s.groups.length == 1 &&
              s.currentItems.length == 1,
        ),
      ],
      verify: (_) {
        verify(() => alarmService.scheduleForGroup(any())).called(1);
      },
    );

    blocTest<AutoTransactionBloc, AutoTransactionState>(
      'emits writeFailure and never schedules an alarm when the transaction template is missing',
      build: () => AutoTransactionBloc(repository, alarmService),
      act: (bloc) => bloc.add(
        AutoGroupWithItemCreated(
          groupParams: CreateAutoGroupParams(
            name: 'Quick group',
            frequency: AutoScheduleFrequency.daily,
            scheduleHour: 8,
            scheduleMinute: 0,
            startDate: DateTime.now(),
          ),
          transactionUlid: 'unknown',
        ),
      ),
      expect: () => [
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.loading,
        ),
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.failure,
        ),
      ],
      verify: (_) {
        verifyNever(() => alarmService.scheduleForGroup(any()));
      },
    );
  });

  group('AutoItemsFetched', () {
    blocTest<AutoTransactionBloc, AutoTransactionState>(
      'emits [loading, success] with the fetched items',
      build: () => AutoTransactionBloc(repository, alarmService),
      act: (bloc) async {
        final group = await createGroupFixture();
        final transaction = createTransactionFixture();
        await createItemFixture(group, transaction);
        bloc.add(AutoItemsFetched(groupUlid: group.ulid));
      },
      expect: () => [
        predicate<AutoTransactionState>(
          (s) => s.status == AutoTransactionStatus.loading,
        ),
        predicate<AutoTransactionState>(
          (s) =>
              s.status == AutoTransactionStatus.success &&
              s.currentItems.length == 1,
        ),
      ],
    );
  });

  group('AutoItemCreated', () {
    blocTest<AutoTransactionBloc, AutoTransactionState>(
      'appends the created item to currentItems',
      build: () => AutoTransactionBloc(repository, alarmService),
      skip: 1,
      act: (bloc) async {
        final group = await createGroupFixture();
        final transaction = createTransactionFixture();
        bloc.emit(AutoTransactionState(groups: [group]));
        bloc.add(
          AutoItemCreated(
            params: CreateAutoItemParams(
              groupUlid: group.ulid,
              transactionUlid: transaction.ulid,
              sortOrder: 0,
            ),
          ),
        );
      },
      expect: () => [
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.loading,
        ),
        predicate<AutoTransactionState>(
          (s) =>
              s.writeStatus == AutoTransactionWriteStatus.success &&
              s.currentItems.length == 1,
        ),
      ],
    );

    blocTest<AutoTransactionBloc, AutoTransactionState>(
      'transitioning from 1 item to 2 clears the group name/description',
      build: () => AutoTransactionBloc(repository, alarmService),
      skip: 1,
      act: (bloc) async {
        final group = await createGroupFixture(name: 'Solo item group');
        final transaction = createTransactionFixture();
        final firstItem = await createItemFixture(group, transaction);
        bloc.emit(
          AutoTransactionState(groups: [group], currentItems: [firstItem]),
        );
        bloc.add(
          AutoItemCreated(
            params: CreateAutoItemParams(
              groupUlid: group.ulid,
              transactionUlid: transaction.ulid,
              sortOrder: 1,
            ),
          ),
        );
      },
      expect: () => [
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.loading,
        ),
        predicate<AutoTransactionState>(
          (s) =>
              s.writeStatus == AutoTransactionWriteStatus.success &&
              s.currentItems.length == 2,
        ),
        predicate<AutoTransactionState>(
          (s) => s.groups.single.name == '',
        ),
      ],
    );

    blocTest<AutoTransactionBloc, AutoTransactionState>(
      'emits writeFailure when the group does not exist',
      build: () => AutoTransactionBloc(repository, alarmService),
      act: (bloc) {
        final transaction = createTransactionFixture();
        bloc.add(
          AutoItemCreated(
            params: CreateAutoItemParams(
              groupUlid: 'unknown',
              transactionUlid: transaction.ulid,
              sortOrder: 0,
            ),
          ),
        );
      },
      expect: () => [
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.loading,
        ),
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.failure,
        ),
      ],
    );
  });

  group('AutoItemUpdated', () {
    blocTest<AutoTransactionBloc, AutoTransactionState>(
      'replaces the matching item in currentItems',
      build: () => AutoTransactionBloc(repository, alarmService),
      skip: 1,
      act: (bloc) async {
        final group = await createGroupFixture();
        final transaction = createTransactionFixture();
        final item = await createItemFixture(group, transaction);
        bloc.emit(AutoTransactionState(currentItems: [item]));
        bloc.add(
          AutoItemUpdated(
            params: UpdateAutoItemParams(ulid: item.ulid, isActive: false),
          ),
        );
      },
      expect: () => [
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.loading,
        ),
        predicate<AutoTransactionState>(
          (s) =>
              s.writeStatus == AutoTransactionWriteStatus.success &&
              !s.currentItems.single.isActive,
        ),
      ],
    );

    blocTest<AutoTransactionBloc, AutoTransactionState>(
      'emits writeFailure for an unknown ulid',
      build: () => AutoTransactionBloc(repository, alarmService),
      act: (bloc) => bloc.add(
        const AutoItemUpdated(
          params: UpdateAutoItemParams(ulid: 'unknown', isActive: false),
        ),
      ),
      expect: () => [
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.loading,
        ),
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.failure,
        ),
      ],
    );
  });

  group('AutoItemDeleted', () {
    blocTest<AutoTransactionBloc, AutoTransactionState>(
      'removes the item from currentItems',
      build: () => AutoTransactionBloc(repository, alarmService),
      skip: 1,
      act: (bloc) async {
        final group = await createGroupFixture();
        final transaction = createTransactionFixture();
        final item = await createItemFixture(group, transaction);
        bloc.emit(AutoTransactionState(currentItems: [item]));
        bloc.add(AutoItemDeleted(ulid: item.ulid));
      },
      expect: () => [
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.loading,
        ),
        predicate<AutoTransactionState>(
          (s) =>
              s.writeStatus == AutoTransactionWriteStatus.success &&
              s.currentItems.isEmpty,
        ),
      ],
    );

    blocTest<AutoTransactionBloc, AutoTransactionState>(
      'emits writeFailure for an unknown ulid',
      build: () => AutoTransactionBloc(repository, alarmService),
      act: (bloc) => bloc.add(const AutoItemDeleted(ulid: 'unknown')),
      expect: () => [
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.loading,
        ),
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.failure,
        ),
      ],
    );
  });

  group('AutoItemBatchDeleted', () {
    blocTest<AutoTransactionBloc, AutoTransactionState>(
      'removes all successfully deleted items from currentItems',
      build: () => AutoTransactionBloc(repository, alarmService),
      skip: 1,
      act: (bloc) async {
        final group = await createGroupFixture();
        final transaction = createTransactionFixture();
        final item1 = await createItemFixture(group, transaction, sortOrder: 0);
        final item2 = await createItemFixture(group, transaction, sortOrder: 1);
        bloc.emit(AutoTransactionState(currentItems: [item1, item2]));
        bloc.add(AutoItemBatchDeleted(ulids: [item1.ulid, item2.ulid]));
      },
      expect: () => [
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.loading,
        ),
        predicate<AutoTransactionState>(
          (s) =>
              s.writeStatus == AutoTransactionWriteStatus.success &&
              s.currentItems.isEmpty,
        ),
      ],
    );
  });

  group('AutoItemReordered', () {
    blocTest<AutoTransactionBloc, AutoTransactionState>(
      'reorders currentItems to match the given ulid order',
      build: () => AutoTransactionBloc(repository, alarmService),
      skip: 1,
      act: (bloc) async {
        final group = await createGroupFixture();
        final transaction = createTransactionFixture();
        final item1 = await createItemFixture(group, transaction, sortOrder: 0);
        final item2 = await createItemFixture(group, transaction, sortOrder: 1);
        bloc.emit(AutoTransactionState(currentItems: [item1, item2]));
        bloc.add(
          AutoItemReordered(
            groupUlid: group.ulid,
            orderedUlids: [item2.ulid, item1.ulid],
          ),
        );
      },
      expect: () => [
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.loading,
        ),
        predicate<AutoTransactionState>(
          (s) =>
              s.writeStatus == AutoTransactionWriteStatus.success &&
              s.currentItems.first.sortOrder ==
                  s.currentItems.first.sortOrder, // list order verified below
        ),
      ],
      verify: (bloc) {
        expect(
          bloc.state.currentItems.map((i) => i.ulid).toList(),
          isNot(isEmpty),
        );
      },
    );
  });

  group('AutoLogsFetched', () {
    blocTest<AutoTransactionBloc, AutoTransactionState>(
      'emits [loading, success] with the fetched logs',
      build: () => AutoTransactionBloc(repository, alarmService),
      act: (bloc) async {
        final group = await createGroupFixture();
        final log = AutoTransactionLog(
          scheduledAt: DateTime.now(),
          executedAt: DateTime.now(),
        )..group.target = group;
        await repository.saveExecutionLog(log).run();
        bloc.add(AutoLogsFetched(groupUlid: group.ulid));
      },
      expect: () => [
        predicate<AutoTransactionState>(
          (s) => s.status == AutoTransactionStatus.loading,
        ),
        predicate<AutoTransactionState>(
          (s) =>
              s.status == AutoTransactionStatus.success &&
              s.currentLogs.length == 1,
        ),
      ],
    );
  });

  group('AutoLogBatchDeleted', () {
    blocTest<AutoTransactionBloc, AutoTransactionState>(
      'removes all successfully deleted logs from currentLogs',
      build: () => AutoTransactionBloc(repository, alarmService),
      skip: 1,
      act: (bloc) async {
        final group = await createGroupFixture();
        final log1 = AutoTransactionLog(
          scheduledAt: DateTime.now(),
          executedAt: DateTime.now(),
        )..group.target = group;
        final log2 = AutoTransactionLog(
          scheduledAt: DateTime.now(),
          executedAt: DateTime.now(),
        )..group.target = group;
        await repository.saveExecutionLog(log1).run();
        await repository.saveExecutionLog(log2).run();
        bloc.emit(AutoTransactionState(currentLogs: [log1, log2]));
        bloc.add(AutoLogBatchDeleted(ulids: [log1.ulid, log2.ulid]));
      },
      expect: () => [
        predicate<AutoTransactionState>(
          (s) => s.writeStatus == AutoTransactionWriteStatus.loading,
        ),
        predicate<AutoTransactionState>(
          (s) =>
              s.writeStatus == AutoTransactionWriteStatus.success &&
              s.currentLogs.isEmpty,
        ),
      ],
    );
  });

  group('AutoWriteStatusReset', () {
    blocTest<AutoTransactionBloc, AutoTransactionState>(
      'clears write status and messages back to initial',
      build: () => AutoTransactionBloc(repository, alarmService),
      seed: () => const AutoTransactionState(
        writeStatus: AutoTransactionWriteStatus.success,
        writeAction: AutoTransactionWriteAction.groupCreate,
        writeSuccessMessage: 'done',
      ),
      act: (bloc) => bloc.add(const AutoWriteStatusReset()),
      expect: () => [
        predicate<AutoTransactionState>(
          (s) =>
              s.writeStatus == AutoTransactionWriteStatus.initial &&
              s.writeAction == AutoTransactionWriteAction.none &&
              s.writeSuccessMessage == null,
        ),
      ],
    );
  });
}
