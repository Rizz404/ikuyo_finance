import 'package:fpdart/fpdart.dart';
import 'package:ikuyo_finance/core/wrapper/failure.dart';
import 'package:ikuyo_finance/core/wrapper/success.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/asset/models/create_asset_params.dart';
import 'package:ikuyo_finance/features/asset/models/get_assets_params.dart';
import 'package:ikuyo_finance/features/asset/models/update_asset_params.dart';

abstract class AssetRepository {
  TaskEither<Failure, Success<Asset>> createAsset(CreateAssetParams params);
  TaskEither<Failure, SuccessCursor<Asset>> getAssets(GetAssetsParams params);
  TaskEither<Failure, Success<Asset>> getAssetById({required String ulid});
  TaskEither<Failure, Success<Asset>> updateAsset(UpdateAssetParams params);
  TaskEither<Failure, ActionSuccess> deleteAsset({required String ulid});
}
