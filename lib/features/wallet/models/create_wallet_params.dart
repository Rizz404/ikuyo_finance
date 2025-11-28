import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import 'package:ikuyo_finance/features/wallet/models/wallet.dart';

class CreateWalletParams extends Equatable {
  final String name;
  final WalletType type;
  final double balance;
  final String? icon;

  const CreateWalletParams({
    required this.name,
    required this.type,
    this.balance = 0,
    this.icon,
  });

  CreateWalletParams copyWith({
    String? name,
    WalletType? type,
    double? balance,
    ValueGetter<String?>? icon,
  }) {
    return CreateWalletParams(
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      icon: icon != null ? icon() : this.icon,
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'type': type.name, 'balance': balance, 'icon': icon};
  }

  factory CreateWalletParams.fromMap(Map<String, dynamic> map) {
    return CreateWalletParams(
      name: map['name'] ?? '',
      type: map['type'] != null
          ? WalletType.values.byName(map['type'])
          : WalletType.cash,
      balance: (map['balance'] ?? 0).toDouble(),
      icon: map['icon'],
    );
  }

  String toJson() => json.encode(toMap());

  factory CreateWalletParams.fromJson(String source) =>
      CreateWalletParams.fromMap(json.decode(source));

  @override
  String toString() {
    return 'CreateWalletParams(name: $name, type: $type, balance: $balance, icon: $icon)';
  }

  @override
  List<Object?> get props => [name, type, balance, icon];
}
