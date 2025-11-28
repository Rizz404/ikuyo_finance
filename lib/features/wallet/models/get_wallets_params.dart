import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import 'package:ikuyo_finance/features/wallet/models/wallet.dart';

class GetWalletsParams extends Equatable {
  final String? cursor;
  final int limit = 20;
  final WalletType? type;

  const GetWalletsParams({this.cursor, this.type});

  GetWalletsParams copyWith({
    ValueGetter<String?>? cursor,
    ValueGetter<WalletType?>? type,
  }) {
    return GetWalletsParams(
      cursor: cursor != null ? cursor() : this.cursor,
      type: type != null ? type() : this.type,
    );
  }

  Map<String, dynamic> toMap() {
    return {'cursor': cursor, 'type': type?.name};
  }

  factory GetWalletsParams.fromMap(Map<String, dynamic> map) {
    return GetWalletsParams(
      cursor: map['cursor'],
      type: map['type'] != null ? WalletType.values.byName(map['type']) : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory GetWalletsParams.fromJson(String source) =>
      GetWalletsParams.fromMap(json.decode(source));

  @override
  String toString() => 'GetWalletsParams(cursor: $cursor, type: $type)';

  @override
  List<Object?> get props => [cursor, type];
}
