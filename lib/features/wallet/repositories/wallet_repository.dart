import 'package:fpdart/fpdart.dart';
import 'package:ikuyo_finance/core/wrapper/failure.dart';
import 'package:ikuyo_finance/core/wrapper/success.dart';
import 'package:ikuyo_finance/features/wallet/models/wallet.dart';
import 'package:ikuyo_finance/features/wallet/models/create_wallet_params.dart';
import 'package:ikuyo_finance/features/wallet/models/get_wallets_params.dart';
import 'package:ikuyo_finance/features/wallet/models/update_wallet_params.dart';

abstract class WalletRepository {
  TaskEither<Failure, Success<Wallet>> createWallet(CreateWalletParams params);
  TaskEither<Failure, SuccessCursor<Wallet>> getWallets(
    GetWalletsParams params,
  );
  TaskEither<Failure, Success<Wallet>> getWalletById({required String ulid});
  TaskEither<Failure, Success<Wallet>> updateWallet(UpdateWalletParams params);
  TaskEither<Failure, ActionSuccess> deleteWallet({required String ulid});
}
