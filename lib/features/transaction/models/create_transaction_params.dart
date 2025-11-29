import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

class CreateTransactionParams extends Equatable {
  final String assetUlid;
  final String? categoryUlid;
  final double amount;
  final DateTime? transactionDate;
  final String? description;
  final String? imagePath;

  const CreateTransactionParams({
    required this.assetUlid,
    this.categoryUlid,
    required this.amount,
    this.transactionDate,
    this.description,
    this.imagePath,
  });

  CreateTransactionParams copyWith({
    String? assetUlid,
    ValueGetter<String?>? categoryUlid,
    double? amount,
    ValueGetter<DateTime?>? transactionDate,
    ValueGetter<String?>? description,
    ValueGetter<String?>? imagePath,
  }) {
    return CreateTransactionParams(
      assetUlid: assetUlid ?? this.assetUlid,
      categoryUlid: categoryUlid != null ? categoryUlid() : this.categoryUlid,
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
    return 'CreateTransactionParams(assetUlid: $assetUlid, categoryUlid: $categoryUlid, amount: $amount, transactionDate: $transactionDate, description: $description, imagePath: $imagePath)';
  }

  @override
  List<Object?> get props => [
    assetUlid,
    categoryUlid,
    amount,
    transactionDate,
    description,
    imagePath,
  ];
}
