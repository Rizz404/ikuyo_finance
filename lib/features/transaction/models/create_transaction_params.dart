import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';

class CreateTransactionParams extends Equatable {
  final String assetUlid;
  final String? categoryUlid;
  final CategoryType? type;
  final double amount;
  final DateTime? transactionDate;
  final String? description;
  final String? imagePath;

  const CreateTransactionParams({
    required this.assetUlid,
    this.categoryUlid,
    this.type,
    required this.amount,
    this.transactionDate,
    this.description,
    this.imagePath,
  });

  CreateTransactionParams copyWith({
    String? assetUlid,
    ValueGetter<String?>? categoryUlid,
    ValueGetter<CategoryType?>? type,
    double? amount,
    ValueGetter<DateTime?>? transactionDate,
    ValueGetter<String?>? description,
    ValueGetter<String?>? imagePath,
  }) {
    return CreateTransactionParams(
      assetUlid: assetUlid ?? this.assetUlid,
      categoryUlid: categoryUlid != null ? categoryUlid() : this.categoryUlid,
      type: type != null ? type() : this.type,
      amount: amount ?? this.amount,
      transactionDate: transactionDate != null
          ? transactionDate()
          : this.transactionDate,
      description: description != null ? description() : this.description,
      imagePath: imagePath != null ? imagePath() : this.imagePath,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'assetUlid': assetUlid,
      'categoryUlid': categoryUlid,
      'type': type?.index,
      'amount': amount,
      'transactionDate': transactionDate?.toIso8601String(),
      'description': description,
      'imagePath': imagePath,
    };
  }

  factory CreateTransactionParams.fromMap(Map<String, dynamic> map) {
    return CreateTransactionParams(
      assetUlid: map['assetUlid'] ?? '',
      categoryUlid: map['categoryUlid'],
      type: map['type'] != null
          ? CategoryType.values[map['type'] as int]
          : null,
      amount: (map['amount'] ?? 0).toDouble(),
      transactionDate: map['transactionDate'] != null
          ? DateTime.parse(map['transactionDate'])
          : null,
      description: map['description'],
      imagePath: map['imagePath'],
    );
  }

  String toJson() => json.encode(toMap());

  factory CreateTransactionParams.fromJson(String source) =>
      CreateTransactionParams.fromMap(json.decode(source));

  @override
  String toString() {
    return 'CreateTransactionParams(assetUlid: $assetUlid, categoryUlid: $categoryUlid, type: $type, amount: $amount, transactionDate: $transactionDate, description: $description, imagePath: $imagePath)';
  }

  @override
  List<Object?> get props => [
    assetUlid,
    categoryUlid,
    type,
    amount,
    transactionDate,
    description,
    imagePath,
  ];
}
