import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/features/wallet/models/wallet.dart';
import 'package:ikuyo_finance/features/wallet/models/create_wallet_params.dart';
import 'package:ikuyo_finance/features/wallet/models/get_wallets_params.dart';
import 'package:ikuyo_finance/features/wallet/models/update_wallet_params.dart';
import 'package:ikuyo_finance/features/wallet/repositories/wallet_repository.dart';

part 'wallet_event.dart';
part 'wallet_state.dart';

class WalletBloc extends Bloc<WalletEvent, WalletState> {
  WalletBloc(this._walletRepository) : super(const WalletState()) {
    // * Read events
    on<WalletFetched>(_onWalletFetched);
    on<WalletFetchedMore>(_onWalletFetchedMore);
    on<WalletRefreshed>(_onWalletRefreshed);

    // * Write events
    on<WalletCreated>(_onWalletCreated);
    on<WalletUpdated>(_onWalletUpdated);
    on<WalletDeleted>(_onWalletDeleted);
    on<WalletWriteStatusReset>(_onWriteStatusReset);
  }

  final WalletRepository _walletRepository;

  // * Fetch initial wallets
  Future<void> _onWalletFetched(
    WalletFetched event,
    Emitter<WalletState> emit,
  ) async {
    emit(
      state.copyWith(
        status: WalletStatus.loading,
        currentFilter: () => event.type,
      ),
    );

    final result = await _walletRepository
        .getWallets(GetWalletsParams(type: event.type))
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: WalletStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: WalletStatus.success,
          wallets: success.data,
          hasReachedMax: !success.cursor.hasNextPage,
          nextCursor: () => success.cursor.nextCursor,
          errorMessage: () => null,
        ),
      ),
    );
  }

  // * Load more wallets (pagination)
  Future<void> _onWalletFetchedMore(
    WalletFetchedMore event,
    Emitter<WalletState> emit,
  ) async {
    if (state.hasReachedMax || state.isLoadingMore) return;

    emit(state.copyWith(status: WalletStatus.loadingMore));

    final result = await _walletRepository
        .getWallets(
          GetWalletsParams(cursor: state.nextCursor, type: state.currentFilter),
        )
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: WalletStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: WalletStatus.success,
          wallets: [...state.wallets, ...?success.data],
          hasReachedMax: !success.cursor.hasNextPage,
          nextCursor: () => success.cursor.nextCursor,
          errorMessage: () => null,
        ),
      ),
    );
  }

  // * Refresh wallets (reset & fetch)
  Future<void> _onWalletRefreshed(
    WalletRefreshed event,
    Emitter<WalletState> emit,
  ) async {
    emit(
      state.copyWith(
        status: WalletStatus.loading,
        hasReachedMax: false,
        nextCursor: () => null,
      ),
    );

    final result = await _walletRepository
        .getWallets(GetWalletsParams(type: state.currentFilter))
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: WalletStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: WalletStatus.success,
          wallets: success.data,
          hasReachedMax: !success.cursor.hasNextPage,
          nextCursor: () => success.cursor.nextCursor,
          errorMessage: () => null,
        ),
      ),
    );
  }

  // * Create wallet
  Future<void> _onWalletCreated(
    WalletCreated event,
    Emitter<WalletState> emit,
  ) async {
    emit(state.copyWith(writeStatus: WalletWriteStatus.loading));

    final result = await _walletRepository.createWallet(event.params).run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          writeStatus: WalletWriteStatus.failure,
          writeErrorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          writeStatus: WalletWriteStatus.success,
          writeSuccessMessage: () => success.message,
          lastCreatedWallet: () => success.data,
          // * Tambah ke list langsung untuk UX responsif
          wallets: [success.data!, ...state.wallets],
        ),
      ),
    );
  }

  // * Update wallet
  Future<void> _onWalletUpdated(
    WalletUpdated event,
    Emitter<WalletState> emit,
  ) async {
    emit(state.copyWith(writeStatus: WalletWriteStatus.loading));

    final result = await _walletRepository.updateWallet(event.params).run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          writeStatus: WalletWriteStatus.failure,
          writeErrorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          writeStatus: WalletWriteStatus.success,
          writeSuccessMessage: () => success.message,
          // * Update item di list
          wallets: state.wallets.map((wallet) {
            return wallet.ulid == event.params.ulid ? success.data! : wallet;
          }).toList(),
        ),
      ),
    );
  }

  // * Delete wallet
  Future<void> _onWalletDeleted(
    WalletDeleted event,
    Emitter<WalletState> emit,
  ) async {
    emit(state.copyWith(writeStatus: WalletWriteStatus.loading));

    final result = await _walletRepository.deleteWallet(ulid: event.ulid).run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          writeStatus: WalletWriteStatus.failure,
          writeErrorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          writeStatus: WalletWriteStatus.success,
          writeSuccessMessage: () => success.message,
          // * Hapus dari list
          wallets: state.wallets
              .where((wallet) => wallet.ulid != event.ulid)
              .toList(),
        ),
      ),
    );
  }

  // * Reset write status (panggil dari UI setelah handle success/error)
  void _onWriteStatusReset(
    WalletWriteStatusReset event,
    Emitter<WalletState> emit,
  ) {
    emit(
      state.copyWith(
        writeStatus: WalletWriteStatus.initial,
        writeSuccessMessage: () => null,
        writeErrorMessage: () => null,
        lastCreatedWallet: () => null,
      ),
    );
  }
}
