import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

class GetTransactionsParams extends Equatable {
  final String? cursor;
  final int limit = 20;
  final String? assetUlid;
  final String? categoryUlid;
  final DateTime? startDate;
  final DateTime? endDate;

  const GetTransactionsParams({
    this.cursor,
    this.assetUlid,
    this.categoryUlid,
    this.startDate,
    this.endDate,
  });

  GetTransactionsParams copyWith({
    ValueGetter<String?>? cursor,
    ValueGetter<String?>? assetUlid,
    ValueGetter<String?>? categoryUlid,
    ValueGetter<DateTime?>? startDate,
    ValueGetter<DateTime?>? endDate,
  }) {
    return GetTransactionsParams(
      cursor: cursor != null ? cursor() : this.cursor,
      assetUlid: assetUlid != null ? assetUlid() : this.assetUlid,
      categoryUlid: categoryUlid != null ? categoryUlid() : this.categoryUlid,
      startDate: startDate != null ? startDate() : this.startDate,
      endDate: endDate != null ? endDate() : this.endDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cursor': cursor,
      'assetUlid': assetUlid,
      'categoryUlid': categoryUlid,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
    };
  }

  factory GetTransactionsParams.fromMap(Map<String, dynamic> map) {
    return GetTransactionsParams(
      cursor: map['cursor'],
      assetUlid: map['assetUlid'],
      categoryUlid: map['categoryUlid'],
      startDate: map['startDate'] != null
          ? DateTime.parse(map['startDate'])
          : null,
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory GetTransactionsParams.fromJson(String source) =>
      GetTransactionsParams.fromMap(json.decode(source));

  @override
  String toString() =>
      'GetTransactionsParams(cursor: $cursor, assetUlid: $assetUlid, categoryUlid: $categoryUlid, startDate: $startDate, endDate: $endDate)';

  @override
  List<Object?> get props => [
    cursor,
    assetUlid,
    categoryUlid,
    startDate,
    endDate,
  ];
}
