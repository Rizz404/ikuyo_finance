import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

class GetTransactionsParams extends Equatable {
  final String? cursor;
  final int limit = 20;
  final String? walletUlid;
  final String? categoryUlid;
  final DateTime? startDate;
  final DateTime? endDate;

  const GetTransactionsParams({
    this.cursor,
    this.walletUlid,
    this.categoryUlid,
    this.startDate,
    this.endDate,
  });

  GetTransactionsParams copyWith({
    ValueGetter<String?>? cursor,
    ValueGetter<String?>? walletUlid,
    ValueGetter<String?>? categoryUlid,
    ValueGetter<DateTime?>? startDate,
    ValueGetter<DateTime?>? endDate,
  }) {
    return GetTransactionsParams(
      cursor: cursor != null ? cursor() : this.cursor,
      walletUlid: walletUlid != null ? walletUlid() : this.walletUlid,
      categoryUlid: categoryUlid != null ? categoryUlid() : this.categoryUlid,
      startDate: startDate != null ? startDate() : this.startDate,
      endDate: endDate != null ? endDate() : this.endDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cursor': cursor,
      'walletUlid': walletUlid,
      'categoryUlid': categoryUlid,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
    };
  }

  factory GetTransactionsParams.fromMap(Map<String, dynamic> map) {
    return GetTransactionsParams(
      cursor: map['cursor'],
      walletUlid: map['walletUlid'],
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
      'GetTransactionsParams(cursor: $cursor, walletUlid: $walletUlid, categoryUlid: $categoryUlid, startDate: $startDate, endDate: $endDate)';

  @override
  List<Object?> get props => [
    cursor,
    walletUlid,
    categoryUlid,
    startDate,
    endDate,
  ];
}
