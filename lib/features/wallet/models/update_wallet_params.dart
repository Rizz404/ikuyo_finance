import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import 'package:ikuyo_finance/features/wallet/models/wallet.dart';

class UpdateWalletParams extends Equatable {
  final String ulid;
  final String? name;
  final WalletType? type;
  final double? balance;
  final String? icon;

  const UpdateWalletParams({
    required this.ulid,
    this.name,
    this.type,
    this.balance,
    this.icon,
  });

  UpdateWalletParams copyWith({
    String? ulid,
    ValueGetter<String?>? name,
    ValueGetter<WalletType?>? type,
    ValueGetter<double?>? balance,
    ValueGetter<String?>? icon,
  }) {
    return UpdateWalletParams(
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

  factory UpdateWalletParams.fromMap(Map<String, dynamic> map) {
    return UpdateWalletParams(
      ulid: map['ulid'] ?? '',
      name: map['name'],
      type: map['type'] != null ? WalletType.values.byName(map['type']) : null,
      balance: map['balance']?.toDouble(),
      icon: map['icon'],
    );
  }

  String toJson() => json.encode(toMap());

  factory UpdateWalletParams.fromJson(String source) =>
      UpdateWalletParams.fromMap(json.decode(source));

  @override
  String toString() {
    return 'UpdateWalletParams(ulid: $ulid, name: $name, type: $type, balance: $balance, icon: $icon)';
  }

  @override
  List<Object?> get props => [ulid, name, type, balance, icon];
}
