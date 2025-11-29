import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import 'package:ikuyo_finance/features/asset/models/asset.dart';

class GetAssetsParams extends Equatable {
  final String? cursor;
  final int limit = 20;
  final AssetType? type;

  const GetAssetsParams({this.cursor, this.type});

  GetAssetsParams copyWith({
    ValueGetter<String?>? cursor,
    ValueGetter<AssetType?>? type,
  }) {
    return GetAssetsParams(
      cursor: cursor != null ? cursor() : this.cursor,
      type: type != null ? type() : this.type,
    );
  }

  Map<String, dynamic> toMap() {
    return {'cursor': cursor, 'type': type?.name};
  }

  factory GetAssetsParams.fromMap(Map<String, dynamic> map) {
    return GetAssetsParams(
      cursor: map['cursor'],
      type: map['type'] != null ? AssetType.values.byName(map['type']) : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory GetAssetsParams.fromJson(String source) =>
      GetAssetsParams.fromMap(json.decode(source));

  @override
  String toString() => 'GetAssetsParams(cursor: $cursor, type: $type)';

  @override
  List<Object?> get props => [cursor, type];
}
