import 'dart:convert';

import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';

/// Model untuk menyimpan semua data backup
class BackupData {
  final String version;
  final DateTime createdAt;
  final String appName;
  final List<CategoryBackup> categories;
  final List<AssetBackup> assets;
  final List<TransactionBackup> transactions;
  final List<BudgetBackup> budgets;

  const BackupData({
    required this.version,
    required this.createdAt,
    required this.appName,
    required this.categories,
    required this.assets,
    required this.transactions,
    required this.budgets,
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'createdAt': createdAt.toIso8601String(),
    'appName': appName,
    'categories': categories.map((c) => c.toJson()).toList(),
    'assets': assets.map((a) => a.toJson()).toList(),
    'transactions': transactions.map((t) => t.toJson()).toList(),
    'budgets': budgets.map((b) => b.toJson()).toList(),
  };

  factory BackupData.fromJson(Map<String, dynamic> json) => BackupData(
    version: json['version'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    appName: json['appName'] as String,
    categories: (json['categories'] as List)
        .map((c) => CategoryBackup.fromJson(c as Map<String, dynamic>))
        .toList(),
    assets: (json['assets'] as List)
        .map((a) => AssetBackup.fromJson(a as Map<String, dynamic>))
        .toList(),
    transactions: (json['transactions'] as List)
        .map((t) => TransactionBackup.fromJson(t as Map<String, dynamic>))
        .toList(),
    budgets: (json['budgets'] as List)
        .map((b) => BudgetBackup.fromJson(b as Map<String, dynamic>))
        .toList(),
  );

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory BackupData.fromJsonString(String jsonString) =>
      BackupData.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

  int get totalItems =>
      categories.length + assets.length + transactions.length + budgets.length;
}

/// Backup model untuk Category
class CategoryBackup {
  final String ulid;
  final String? parentUlid;
  final String name;
  final int type;
  final String? icon;
  final String? color;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CategoryBackup({
    required this.ulid,
    this.parentUlid,
    required this.name,
    required this.type,
    this.icon,
    this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'ulid': ulid,
    'parentUlid': parentUlid,
    'name': name,
    'type': type,
    'icon': icon,
    'color': color,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory CategoryBackup.fromJson(Map<String, dynamic> json) => CategoryBackup(
    ulid: json['ulid'] as String,
    parentUlid: json['parentUlid'] as String?,
    name: json['name'] as String,
    type: json['type'] as int,
    icon: json['icon'] as String?,
    color: json['color'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  factory CategoryBackup.fromEntity(Category category) => CategoryBackup(
    ulid: category.ulid,
    parentUlid: category.parent.target?.ulid,
    name: category.name,
    type: category.type,
    icon: category.icon,
    color: category.color,
    createdAt: category.createdAt,
    updatedAt: category.updatedAt,
  );
}

/// Backup model untuk Asset
class AssetBackup {
  final String ulid;
  final String name;
  final int type;
  final double balance;
  final String? icon;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AssetBackup({
    required this.ulid,
    required this.name,
    required this.type,
    required this.balance,
    this.icon,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'ulid': ulid,
    'name': name,
    'type': type,
    'balance': balance,
    'icon': icon,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory AssetBackup.fromJson(Map<String, dynamic> json) => AssetBackup(
    ulid: json['ulid'] as String,
    name: json['name'] as String,
    type: json['type'] as int,
    balance: (json['balance'] as num).toDouble(),
    icon: json['icon'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  factory AssetBackup.fromEntity(Asset asset) => AssetBackup(
    ulid: asset.ulid,
    name: asset.name,
    type: asset.type,
    balance: asset.balance,
    icon: asset.icon,
    createdAt: asset.createdAt,
    updatedAt: asset.updatedAt,
  );
}

/// Backup model untuk Transaction
class TransactionBackup {
  final String ulid;
  final String assetUlid;
  final String? categoryUlid;
  final double amount;
  final DateTime? transactionDate;
  final String? description;
  final String? imagePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TransactionBackup({
    required this.ulid,
    required this.assetUlid,
    this.categoryUlid,
    required this.amount,
    this.transactionDate,
    this.description,
    this.imagePath,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'ulid': ulid,
    'assetUlid': assetUlid,
    'categoryUlid': categoryUlid,
    'amount': amount,
    'transactionDate': transactionDate?.toIso8601String(),
    'description': description,
    'imagePath': imagePath,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory TransactionBackup.fromJson(Map<String, dynamic> json) =>
      TransactionBackup(
        ulid: json['ulid'] as String,
        assetUlid: json['assetUlid'] as String,
        categoryUlid: json['categoryUlid'] as String?,
        amount: (json['amount'] as num).toDouble(),
        transactionDate: json['transactionDate'] != null
            ? DateTime.parse(json['transactionDate'] as String)
            : null,
        description: json['description'] as String?,
        imagePath: json['imagePath'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  factory TransactionBackup.fromEntity(Transaction transaction) =>
      TransactionBackup(
        ulid: transaction.ulid,
        assetUlid: transaction.asset.target!.ulid,
        categoryUlid: transaction.category.target?.ulid,
        amount: transaction.amount,
        transactionDate: transaction.transactionDate,
        description: transaction.description,
        imagePath: transaction.imagePath,
        createdAt: transaction.createdAt,
        updatedAt: transaction.updatedAt,
      );
}

/// Backup model untuk Budget
class BudgetBackup {
  final String ulid;
  final String categoryUlid;
  final double amountLimit;
  final int period;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BudgetBackup({
    required this.ulid,
    required this.categoryUlid,
    required this.amountLimit,
    required this.period,
    this.startDate,
    this.endDate,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'ulid': ulid,
    'categoryUlid': categoryUlid,
    'amountLimit': amountLimit,
    'period': period,
    'startDate': startDate?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory BudgetBackup.fromJson(Map<String, dynamic> json) => BudgetBackup(
    ulid: json['ulid'] as String,
    categoryUlid: json['categoryUlid'] as String,
    amountLimit: (json['amountLimit'] as num).toDouble(),
    period: json['period'] as int,
    startDate: json['startDate'] != null
        ? DateTime.parse(json['startDate'] as String)
        : null,
    endDate: json['endDate'] != null
        ? DateTime.parse(json['endDate'] as String)
        : null,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  factory BudgetBackup.fromEntity(Budget budget) => BudgetBackup(
    ulid: budget.ulid,
    categoryUlid: budget.category.target!.ulid,
    amountLimit: budget.amountLimit,
    period: budget.period,
    startDate: budget.startDate,
    endDate: budget.endDate,
    createdAt: budget.createdAt,
    updatedAt: budget.updatedAt,
  );
}
