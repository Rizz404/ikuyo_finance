import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import 'package:ikuyo_finance/features/asset/models/asset.dart';

class CreateAssetParams extends Equatable {
  final String name;
  final AssetType type;
  final double balance;
  final String? icon;

  const CreateAssetParams({
    required this.name,
    required this.type,
    this.balance = 0,
    this.icon,
  });

  CreateAssetParams copyWith({
    String? name,
    AssetType? type,
    double? balance,
    ValueGetter<String?>? icon,
  }) {
    return CreateAssetParams(
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      icon: icon != null ? icon() : this.icon,
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'type': type.name, 'balance': balance, 'icon': icon};
  }

  factory CreateAssetParams.fromMap(Map<String, dynamic> map) {
    return CreateAssetParams(
      name: map['name'] ?? '',
      type: map['type'] != null
          ? AssetType.values.byName(map['type'])
          : AssetType.cash,
      balance: (map['balance'] ?? 0).toDouble(),
      icon: map['icon'],
    );
  }

  String toJson() => json.encode(toMap());

  factory CreateAssetParams.fromJson(String source) =>
      CreateAssetParams.fromMap(json.decode(source));

  @override
  String toString() {
    return 'CreateAssetParams(name: $name, type: $type, balance: $balance, icon: $icon)';
  }

  @override
  List<Object?> get props => [name, type, balance, icon];
}
