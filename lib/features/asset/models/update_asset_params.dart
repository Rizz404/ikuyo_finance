import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import 'package:ikuyo_finance/features/asset/models/asset.dart';

class UpdateAssetParams extends Equatable {
  final String ulid;
  final String? name;
  final AssetType? type;
  final double? balance;
  final String? icon;

  const UpdateAssetParams({
    required this.ulid,
    this.name,
    this.type,
    this.balance,
    this.icon,
  });

  UpdateAssetParams copyWith({
    String? ulid,
    ValueGetter<String?>? name,
    ValueGetter<AssetType?>? type,
    ValueGetter<double?>? balance,
    ValueGetter<String?>? icon,
  }) {
    return UpdateAssetParams(
      ulid: ulid ?? this.ulid,
      name: name != null ? name() : this.name,
      type: type != null ? type() : this.type,
      balance: balance != null ? balance() : this.balance,
      icon: icon != null ? icon() : this.icon,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ulid': ulid,
      'name': name,
      'type': type?.name,
      'balance': balance,
      'icon': icon,
    };
  }

  factory UpdateAssetParams.fromMap(Map<String, dynamic> map) {
    return UpdateAssetParams(
      ulid: map['ulid'] ?? '',
      name: map['name'],
      type: map['type'] != null ? AssetType.values.byName(map['type']) : null,
      balance: map['balance']?.toDouble(),
      icon: map['icon'],
    );
  }

  String toJson() => json.encode(toMap());

  factory UpdateAssetParams.fromJson(String source) =>
      UpdateAssetParams.fromMap(json.decode(source));

  @override
  String toString() {
    return 'UpdateAssetParams(ulid: $ulid, name: $name, type: $type, balance: $balance, icon: $icon)';
  }

  @override
  List<Object?> get props => [ulid, name, type, balance, icon];
}
