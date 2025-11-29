part of 'asset_bloc.dart';

sealed class AssetEvent {
  const AssetEvent();
}

// * Read Events
final class AssetFetched extends AssetEvent {
  const AssetFetched({this.type});

  final AssetType? type;
}

final class AssetFetchedMore extends AssetEvent {
  const AssetFetchedMore();
}

final class AssetRefreshed extends AssetEvent {
  const AssetRefreshed();
}

// * Write Events
final class AssetCreated extends AssetEvent {
  final CreateAssetParams params;

  const AssetCreated({required this.params});
}

final class AssetUpdated extends AssetEvent {
  final UpdateAssetParams params;

  const AssetUpdated({required this.params});
}

final class AssetDeleted extends AssetEvent {
  const AssetDeleted({required this.ulid});

  final String ulid;
}

// * Reset write status setelah UI handle
final class AssetWriteStatusReset extends AssetEvent {
  const AssetWriteStatusReset();
}
