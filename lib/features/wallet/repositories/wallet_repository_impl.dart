import 'package:fpdart/fpdart.dart' hide Order;
import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';
import 'package:ikuyo_finance/core/wrapper/failure.dart';
import 'package:ikuyo_finance/core/wrapper/success.dart';
import 'package:ikuyo_finance/features/wallet/models/wallet.dart';
import 'package:ikuyo_finance/features/wallet/models/create_wallet_params.dart';
import 'package:ikuyo_finance/features/wallet/models/get_wallets_params.dart';
import 'package:ikuyo_finance/features/wallet/models/update_wallet_params.dart';
import 'package:ikuyo_finance/features/wallet/repositories/wallet_repository.dart';
import 'package:ikuyo_finance/objectbox.g.dart';

class WalletRepositoryImpl implements WalletRepository {
  final ObjectBoxStorage _storage;

  const WalletRepositoryImpl(this._storage);

  Box<Wallet> get _box => _storage.box<Wallet>();

  @override
  TaskEither<Failure, Success<Wallet>> createWallet(CreateWalletParams params) {
    return TaskEither.tryCatch(
      () async {
        logService('Create wallet', params.name);

        final wallet = Wallet(
          name: params.name,
          type: params.type.index,
          balance: params.balance,
          icon: params.icon,
        );

        _box.put(wallet);
        logInfo('Wallet created successfully');

        return Success(message: 'Wallet created', data: wallet);
      },
      (error, stackTrace) {
        logError('Create wallet failed', error, stackTrace);
        return Failure(message: 'Failed to create wallet. Please try again.');
      },
    );
  }

  @override
  TaskEither<Failure, SuccessCursor<Wallet>> getWallets(
    GetWalletsParams params,
  ) {
    return TaskEither.tryCatch(
      () async {
        logService(
          'Get wallets',
          'cursor: ${params.cursor}, limit: ${params.limit}',
        );

        var query = _box.query();

        // * Filter by type jika ada
        if (params.type != null) {
          query = _box.query(Wallet_.type.equals(params.type!.index));
        }

        // * Pagination dengan cursor (offset-based)
        final offset = params.cursor != null
            ? int.tryParse(params.cursor!) ?? 0
            : 0;
        query = query..order(Wallet_.createdAt, flags: Order.descending);

        final builtQuery = query.build();
        final allResults = builtQuery.find();
        builtQuery.close();

        // * Manual offset & limit
        final startIndex = offset < allResults.length
            ? offset
            : allResults.length;
        final endIndex = (startIndex + params.limit + 1) < allResults.length
            ? startIndex + params.limit + 1
            : allResults.length;
        final results = allResults.sublist(startIndex, endIndex);

        final hasMore = results.length > params.limit;
        final wallets = hasMore ? results.sublist(0, params.limit) : results;

        final cursorInfo = CursorInfo(
          nextCursor: hasMore ? (offset + params.limit).toString() : '',
          hasNextPage: hasMore,
          perPage: params.limit,
        );

        logInfo('Wallets retrieved: ${wallets.length}');

        return SuccessCursor(
          message: 'Wallets retrieved',
          data: wallets,
          cursor: cursorInfo,
        );
      },
      (error, stackTrace) {
        logError('Get wallets failed', error, stackTrace);
        return Failure(
          message: 'Failed to retrieve wallets. Please try again.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, Success<Wallet>> getWalletById({required String ulid}) {
    return TaskEither.tryCatch(
      () async {
        logService('Get wallet by id', ulid);

        final wallet = _box
            .query(Wallet_.ulid.equals(ulid))
            .build()
            .findFirst();

        if (wallet == null) {
          throw Exception('Wallet not found');
        }

        logInfo('Wallet retrieved');
        return Success(message: 'Wallet retrieved', data: wallet);
      },
      (error, stackTrace) {
        logError('Get wallet by id failed', error, stackTrace);
        return Failure(
          message: error.toString().contains('not found')
              ? 'Wallet not found'
              : 'Failed to retrieve wallet. Please try again.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, Success<Wallet>> updateWallet(UpdateWalletParams params) {
    return TaskEither.tryCatch(
      () async {
        logService('Update wallet', params.ulid);

        final wallet = _box
            .query(Wallet_.ulid.equals(params.ulid))
            .build()
            .findFirst();

        if (wallet == null) {
          throw Exception('Wallet not found');
        }

        // * Update fields jika ada
        if (params.name != null) wallet.name = params.name!;
        if (params.type != null) wallet.type = params.type!.index;
        if (params.balance != null) wallet.balance = params.balance!;
        if (params.icon != null) wallet.icon = params.icon;

        wallet.updatedAt = DateTime.now();
        _box.put(wallet);

        logInfo('Wallet updated successfully');
        return Success(message: 'Wallet updated', data: wallet);
      },
      (error, stackTrace) {
        logError('Update wallet failed', error, stackTrace);
        return Failure(
          message: error.toString().contains('not found')
              ? 'Wallet not found'
              : 'Failed to update wallet. Please try again.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, ActionSuccess> deleteWallet({required String ulid}) {
    return TaskEither.tryCatch(
      () async {
        logService('Delete wallet', ulid);

        final wallet = _box
            .query(Wallet_.ulid.equals(ulid))
            .build()
            .findFirst();

        if (wallet == null) {
          throw Exception('Wallet not found');
        }

        _box.remove(wallet.id);
        logInfo('Wallet deleted successfully');

        return const ActionSuccess(message: 'Wallet deleted');
      },
      (error, stackTrace) {
        logError('Delete wallet failed', error, stackTrace);
        return Failure(
          message: error.toString().contains('not found')
              ? 'Wallet not found'
              : 'Failed to delete wallet. Please try again.',
        );
      },
    );
  }
}
