part of 'wallet_bloc.dart';

sealed class WalletEvent {
  const WalletEvent();
}

// * Read Events
final class WalletFetched extends WalletEvent {
  const WalletFetched({this.type});

  final WalletType? type;
}

final class WalletFetchedMore extends WalletEvent {
  const WalletFetchedMore();
}

final class WalletRefreshed extends WalletEvent {
  const WalletRefreshed();
}

// * Write Events
final class WalletCreated extends WalletEvent {
  final CreateWalletParams params;

  const WalletCreated({required this.params});
}

final class WalletUpdated extends WalletEvent {
  final UpdateWalletParams params;

  const WalletUpdated({required this.params});
}

final class WalletDeleted extends WalletEvent {
  const WalletDeleted({required this.ulid});

  final String ulid;
}

// * Reset write status setelah UI handle
final class WalletWriteStatusReset extends WalletEvent {
  const WalletWriteStatusReset();
}
