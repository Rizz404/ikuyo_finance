import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import 'package:ikuyo_finance/features/category/models/category.dart';

class GetCategoriesParams extends Equatable {
  final String? cursor;
  final int limit = 20;
  final CategoryType? type;

  const GetCategoriesParams({this.cursor, this.type});

  GetCategoriesParams copyWith({
    ValueGetter<String?>? cursor,
    ValueGetter<CategoryType?>? type,
  }) {
    return GetCategoriesParams(
      cursor: cursor != null ? cursor() : this.cursor,
      type: type != null ? type() : this.type,
    );
  }

  Map<String, dynamic> toMap() {
    return {'cursor': cursor, 'type': type?.name};
  }

  factory GetCategoriesParams.fromMap(Map<String, dynamic> map) {
    return GetCategoriesParams(
      cursor: map['cursor'],
      type: map['type'] != null
          ? CategoryType.values.byName(map['type'])
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory GetCategoriesParams.fromJson(String source) =>
      GetCategoriesParams.fromMap(json.decode(source));

  @override
  String toString() => 'GetCategoriesParams(cursor: $cursor, type: $type)';

  @override
  List<Object?> get props => [cursor, type];
}
