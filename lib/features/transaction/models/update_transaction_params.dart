import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

class UpdateTransactionParams extends Equatable {
  final String ulid;
  final String? walletUlid;
  final String? categoryUlid;
  final double? amount;
  final DateTime? transactionDate;
  final String? description;
  final String? imagePath;

  const UpdateTransactionParams({
    required this.ulid,
    this.walletUlid,
    this.categoryUlid,
    this.amount,
    this.transactionDate,
    this.description,
    this.imagePath,
  });

  UpdateTransactionParams copyWith({
    String? ulid,
    ValueGetter<String?>? walletUlid,
    ValueGetter<String?>? categoryUlid,
    ValueGetter<double?>? amount,
    ValueGetter<DateTime?>? transactionDate,
    ValueGetter<String?>? description,
    ValueGetter<String?>? imagePath,
  }) {
    return UpdateTransactionParams(
      ulid: ulid ?? this.ulid,
      walletUlid: walletUlid != null ? walletUlid() : this.walletUlid,
      categoryUlid: categoryUlid != null ? categoryUlid() : this.categoryUlid,
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
      'walletUlid': walletUlid,
      'categoryUlid': categoryUlid,
      'amount': amount,
      'transactionDate': transactionDate?.toIso8601String(),
      'description': description,
      'imagePath': imagePath,
    };
  }

  factory UpdateTransactionParams.fromMap(Map<String, dynamic> map) {
    return UpdateTransactionParams(
      ulid: map['ulid'] ?? '',
      walletUlid: map['walletUlid'],
      categoryUlid: map['categoryUlid'],
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
    return 'UpdateTransactionParams(ulid: $ulid, walletUlid: $walletUlid, categoryUlid: $categoryUlid, amount: $amount, transactionDate: $transactionDate, description: $description, imagePath: $imagePath)';
  }

  @override
  List<Object?> get props => [
    ulid,
    walletUlid,
    categoryUlid,
    amount,
    transactionDate,
    description,
    imagePath,
  ];
}
