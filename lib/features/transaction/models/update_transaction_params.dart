import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';

class UpdateTransactionParams extends Equatable {
  final String ulid;
  final String? assetUlid;
  final String? categoryUlid;
  final CategoryType? type;
  final double? amount;
  final DateTime? transactionDate;
  final String? description;
  final String? imagePath;

  const UpdateTransactionParams({
    required this.ulid,
    this.assetUlid,
    this.categoryUlid,
    this.type,
    this.amount,
    this.transactionDate,
    this.description,
    this.imagePath,
  });

  UpdateTransactionParams copyWith({
    String? ulid,
    ValueGetter<String?>? assetUlid,
    ValueGetter<String?>? categoryUlid,
    ValueGetter<CategoryType?>? type,
    ValueGetter<double?>? amount,
    ValueGetter<DateTime?>? transactionDate,
    ValueGetter<String?>? description,
    ValueGetter<String?>? imagePath,
  }) {
    return UpdateTransactionParams(
      ulid: ulid ?? this.ulid,
      assetUlid: assetUlid != null ? assetUlid() : this.assetUlid,
      categoryUlid: categoryUlid != null ? categoryUlid() : this.categoryUlid,
      type: type != null ? type() : this.type,
      amount: amount != null ? amount() : this.amount,
      transactionDate: transactionDate != null
          ? transactionDate()
          : this.transactionDate,
      description: description != null ? description() : this.description,
      imagePath: imagePath != null ? imagePath() : this.imagePath,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ulid': ulid,
      'assetUlid': assetUlid,
      'categoryUlid': categoryUlid,
      'type': type?.index,
      'amount': amount,
      'transactionDate': transactionDate?.toIso8601String(),
      'description': description,
      'imagePath': imagePath,
    };
  }

  factory UpdateTransactionParams.fromMap(Map<String, dynamic> map) {
    return UpdateTransactionParams(
      ulid: map['ulid'] ?? '',
      assetUlid: map['assetUlid'],
      categoryUlid: map['categoryUlid'],
      type: map['type'] != null
          ? CategoryType.values[map['type'] as int]
          : null,
      amount: map['amount']?.toDouble(),
      transactionDate: map['transactionDate'] != null
          ? DateTime.parse(map['transactionDate'])
          : null,
      description: map['description'],
      imagePath: map['imagePath'],
    );
  }

  String toJson() => json.encode(toMap());

  factory UpdateTransactionParams.fromJson(String source) =>
      UpdateTransactionParams.fromMap(json.decode(source));

  @override
  String toString() {
    return 'UpdateTransactionParams(ulid: $ulid, assetUlid: $assetUlid, categoryUlid: $categoryUlid, type: $type, amount: $amount, transactionDate: $transactionDate, description: $description, imagePath: $imagePath)';
  }

  @override
  List<Object?> get props => [
    ulid,
    assetUlid,
    categoryUlid,
    type,
    amount,
    transactionDate,
    description,
    imagePath,
  ];
}
