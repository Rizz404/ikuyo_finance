part of 'auto_transaction_bloc.dart';

sealed class AutoTransactionEvent {
  const AutoTransactionEvent();
}

// * Group read
final class AutoGroupFetched extends AutoTransactionEvent {
  const AutoGroupFetched();
}

// * Group write
final class AutoGroupCreated extends AutoTransactionEvent {
  const AutoGroupCreated({required this.params});

  final CreateAutoGroupParams params;
}

final class AutoGroupUpdated extends AutoTransactionEvent {
  const AutoGroupUpdated({required this.params});

  final UpdateAutoGroupParams params;
}

final class AutoGroupDeleted extends AutoTransactionEvent {
  const AutoGroupDeleted({required this.ulid});

  final String ulid;
}

final class AutoGroupToggled extends AutoTransactionEvent {
  const AutoGroupToggled({required this.ulid, required this.isActive});

  final String ulid;
  final bool isActive;
}

final class AutoGroupPaused extends AutoTransactionEvent {
  const AutoGroupPaused({required this.ulid, this.pauseStartAt, this.resumeAt});

  final String ulid;
  final DateTime? pauseStartAt;

  // * null = pause manual (tidak ada auto-resume)
  final DateTime? resumeAt;
}

final class AutoGroupResumed extends AutoTransactionEvent {
  const AutoGroupResumed({required this.ulid});

  final String ulid;
}

// * Item read
final class AutoItemsFetched extends AutoTransactionEvent {
  const AutoItemsFetched({required this.groupUlid});

  final String groupUlid;
}

// * Item write
final class AutoItemCreated extends AutoTransactionEvent {
  const AutoItemCreated({required this.params});

  final CreateAutoItemParams params;
}

final class AutoItemUpdated extends AutoTransactionEvent {
  const AutoItemUpdated({required this.params});

  final UpdateAutoItemParams params;
}

final class AutoItemDeleted extends AutoTransactionEvent {
  const AutoItemDeleted({required this.ulid});

  final String ulid;
}

final class AutoItemReordered extends AutoTransactionEvent {
  const AutoItemReordered({
    required this.groupUlid,
    required this.orderedUlids,
  });

  final String groupUlid;
  final List<String> orderedUlids;
}

// * Log read
final class AutoLogsFetched extends AutoTransactionEvent {
  const AutoLogsFetched({required this.groupUlid});

  final String groupUlid;
}

// * Reset write status setelah UI handle success/error
final class AutoWriteStatusReset extends AutoTransactionEvent {
  const AutoWriteStatusReset();
}
