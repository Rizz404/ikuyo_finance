part of 'wallet_bloc.dart';

// * Status untuk read operations (fetch, load more)
enum WalletStatus { initial, loading, loadingMore, success, failure }

// * Status untuk write operations (create, update, delete)
enum WalletWriteStatus { initial, loading, success, failure }

final class WalletState extends Equatable {
  // * Read state
  final WalletStatus status;
  final List<Wallet> wallets;
  final String? errorMessage;
  final bool hasReachedMax;
  final String? nextCursor;
  final WalletType? currentFilter;

  // * Write state (terpisah dari read)
  final WalletWriteStatus writeStatus;
  final String? writeSuccessMessage;
  final String? writeErrorMessage;
  final Wallet? lastCreatedWallet;

  const WalletState({
    this.status = WalletStatus.initial,
    this.wallets = const [],
    this.errorMessage,
    this.hasReachedMax = false,
    this.nextCursor,
    this.currentFilter,
    this.writeStatus = WalletWriteStatus.initial,
    this.writeSuccessMessage,
    this.writeErrorMessage,
    this.lastCreatedWallet,
  });

  // * Factory constructors for cleaner state creation
  const WalletState.initial() : this();

  bool get isLoading => status == WalletStatus.loading;
  bool get isLoadingMore => status == WalletStatus.loadingMore;
  bool get isWriting => writeStatus == WalletWriteStatus.loading;

  WalletState copyWith({
    WalletStatus? status,
    List<Wallet>? wallets,
    String? Function()? errorMessage,
    bool? hasReachedMax,
    String? Function()? nextCursor,
    WalletType? Function()? currentFilter,
    WalletWriteStatus? writeStatus,
    String? Function()? writeSuccessMessage,
    String? Function()? writeErrorMessage,
    Wallet? Function()? lastCreatedWallet,
  }) {
    return WalletState(
      status: status ?? this.status,
      wallets: wallets ?? this.wallets,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      nextCursor: nextCursor != null ? nextCursor() : this.nextCursor,
      currentFilter: currentFilter != null
          ? currentFilter()
          : this.currentFilter,
      writeStatus: writeStatus ?? this.writeStatus,
      writeSuccessMessage: writeSuccessMessage != null
          ? writeSuccessMessage()
          : this.writeSuccessMessage,
      writeErrorMessage: writeErrorMessage != null
          ? writeErrorMessage()
          : this.writeErrorMessage,
      lastCreatedWallet: lastCreatedWallet != null
          ? lastCreatedWallet()
          : this.lastCreatedWallet,
    );
  }

  @override
  List<Object?> get props => [
    status,
    wallets,
    errorMessage,
    hasReachedMax,
    nextCursor,
    currentFilter,
    writeStatus,
    writeSuccessMessage,
    writeErrorMessage,
    lastCreatedWallet,
  ];
}
