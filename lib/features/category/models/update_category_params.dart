import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import 'package:ikuyo_finance/features/category/models/category.dart';

class UpdateCategoryParams extends Equatable {
  final String ulid;
  final String? name;
  final CategoryType? type;
  final String? icon;
  final String? color;
  final String? parentUlid;

  const UpdateCategoryParams({
    required this.ulid,
    required this.name,
    required this.type,
    this.icon,
    this.color,
    this.parentUlid,
  });

  UpdateCategoryParams copyWith({
    String? ulid,
    ValueGetter<String?>? name,
    ValueGetter<CategoryType?>? type,
    ValueGetter<String?>? icon,
    ValueGetter<String?>? color,
    ValueGetter<String?>? parentUlid,
  }) {
    return UpdateCategoryParams(
      ulid: ulid ?? this.ulid,
      name: name != null ? name() : this.name,
      type: type != null ? type() : this.type,
      icon: icon != null ? icon() : this.icon,
      color: color != null ? color() : this.color,
      parentUlid: parentUlid != null ? parentUlid() : this.parentUlid,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ulid': ulid,
      'name': name,
      'type': type?.name,
      'icon': icon,
      'color': color,
      'parentUlid': parentUlid,
    };
  }

  factory UpdateCategoryParams.fromMap(Map<String, dynamic> map) {
    return UpdateCategoryParams(
      ulid: map['ulid'] ?? '',
      name: map['name'],
      type: map['type'] != null
          ? CategoryType.values.byName(map['type'])
          : null,
      icon: map['icon'],
      color: map['color'],
      parentUlid: map['parentUlid'],
    );
  }

  String toJson() => json.encode(toMap());

  factory UpdateCategoryParams.fromJson(String source) =>
      UpdateCategoryParams.fromMap(json.decode(source));

  @override
  String toString() {
    return 'UpdateCategoryParams(ulid: $ulid, name: $name, type: $type, icon: $icon, color: $color, parentUlid: $parentUlid)';
  }

  @override
  List<Object?> get props {
    return [ulid, name, type, icon, color, parentUlid];
  }
}
