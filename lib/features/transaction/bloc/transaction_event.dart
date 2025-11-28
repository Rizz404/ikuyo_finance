part of 'transaction_bloc.dart';

sealed class TransactionEvent {
  const TransactionEvent();
}

// * Read Events
final class TransactionFetched extends TransactionEvent {
  const TransactionFetched({
    this.walletUlid,
    this.categoryUlid,
    this.startDate,
    this.endDate,
  });

  final String? walletUlid;
  final String? categoryUlid;
  final DateTime? startDate;
  final DateTime? endDate;
}

final class TransactionFetchedMore extends TransactionEvent {
  const TransactionFetchedMore();
}

final class TransactionRefreshed extends TransactionEvent {
  const TransactionRefreshed();
}

// * Write Events
final class TransactionCreated extends TransactionEvent {
  final CreateTransactionParams params;

  const TransactionCreated({required this.params});
}

final class TransactionUpdated extends TransactionEvent {
  final UpdateTransactionParams params;

  const TransactionUpdated({required this.params});
}

final class TransactionDeleted extends TransactionEvent {
  const TransactionDeleted({required this.ulid});

  final String ulid;
}

// * Reset write status setelah UI handle
final class TransactionWriteStatusReset extends TransactionEvent {
  const TransactionWriteStatusReset();
}
