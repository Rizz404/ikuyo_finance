import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import 'package:ikuyo_finance/features/category/models/category.dart';

class CreateCategoryParams extends Equatable {
  final String name;
  final CategoryType type;
  final String? icon;
  final String? color;
  final String? parentUlid;

  const CreateCategoryParams({
    required this.name,
    required this.type,
    this.icon,
    this.color,
    this.parentUlid,
  });

  CreateCategoryParams copyWith({
    String? name,
    CategoryType? type,
    ValueGetter<String?>? icon,
    ValueGetter<String?>? color,
    ValueGetter<String?>? parentUlid,
  }) {
    return CreateCategoryParams(
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon != null ? icon() : this.icon,
      color: color != null ? color() : this.color,
      parentUlid: parentUlid != null ? parentUlid() : this.parentUlid,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type.name,
      'icon': icon,
      'color': color,
      'parentUlid': parentUlid,
    };
  }

  factory CreateCategoryParams.fromMap(Map<String, dynamic> map) {
    return CreateCategoryParams(
      name: map['name'] ?? '',
      type: map['type'] != null
          ? CategoryType.values.byName(map['type'])
          : CategoryType.income,
      icon: map['icon'],
      color: map['color'],
      parentUlid: map['parentUlid'],
    );
  }

  String toJson() => json.encode(toMap());

  factory CreateCategoryParams.fromJson(String source) =>
      CreateCategoryParams.fromMap(json.decode(source));

  @override
  String toString() {
    return 'CreateCategoryParams(name: $name, type: $type, icon: $icon, color: $color, parentUlid: $parentUlid)';
  }

  @override
  List<Object?> get props {
    return [name, type, icon, color, parentUlid];
  }
}
