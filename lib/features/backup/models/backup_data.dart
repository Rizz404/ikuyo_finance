import 'dart:convert';

import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_group.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_item.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_log.dart';
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
  final List<AutoGroupBackup> autoGroups;
  final List<AutoItemBackup> autoItems;
  final List<AutoLogBackup> autoLogs;

  const BackupData({
    required this.version,
    required this.createdAt,
    required this.appName,
    required this.categories,
    required this.assets,
    required this.transactions,
    required this.budgets,
    this.autoGroups = const [],
    this.autoItems = const [],
    this.autoLogs = const [],
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'createdAt': createdAt.toIso8601String(),
    'appName': appName,
    'categories': categories.map((c) => c.toJson()).toList(),
    'assets': assets.map((a) => a.toJson()).toList(),
    'transactions': transactions.map((t) => t.toJson()).toList(),
    'budgets': budgets.map((b) => b.toJson()).toList(),
    'autoGroups': autoGroups.map((g) => g.toJson()).toList(),
    'autoItems': autoItems.map((i) => i.toJson()).toList(),
    'autoLogs': autoLogs.map((l) => l.toJson()).toList(),
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
    autoGroups: ((json['autoGroups'] as List?) ?? [])
        .map((g) => AutoGroupBackup.fromJson(g as Map<String, dynamic>))
        .toList(),
    autoItems: ((json['autoItems'] as List?) ?? [])
        .map((i) => AutoItemBackup.fromJson(i as Map<String, dynamic>))
        .toList(),
    autoLogs: ((json['autoLogs'] as List?) ?? [])
        .map((l) => AutoLogBackup.fromJson(l as Map<String, dynamic>))
        .toList(),
  );

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory BackupData.fromJsonString(String jsonString) =>
      BackupData.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

  int get totalItems =>
      categories.length +
      assets.length +
      transactions.length +
      budgets.length +
      autoGroups.length +
      autoItems.length +
      autoLogs.length;
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

/// Backup model untuk AutoTransactionGroup
class AutoGroupBackup {
  final String ulid;
  final String name;
  final String? description;
  final bool isActive;
  final bool isPaused;
  final DateTime? pauseStartAt;
  final DateTime? pauseEndAt;
  final int frequency;
  final int scheduleHour;
  final int scheduleMinute;
  final int? dayOfWeek;
  final int? dayOfMonth;
  final int? monthOfYear;
  final int intervalDays;
  final int activeDaysMask;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? nextExecutedAt;
  final DateTime? lastExecutedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AutoGroupBackup({
    required this.ulid,
    required this.name,
    this.description,
    required this.isActive,
    required this.isPaused,
    this.pauseStartAt,
    this.pauseEndAt,
    required this.frequency,
    required this.scheduleHour,
    required this.scheduleMinute,
    this.dayOfWeek,
    this.dayOfMonth,
    this.monthOfYear,
    required this.intervalDays,
    required this.activeDaysMask,
    required this.startDate,
    this.endDate,
    this.nextExecutedAt,
    this.lastExecutedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'ulid': ulid,
    'name': name,
    'description': description,
    'isActive': isActive,
    'isPaused': isPaused,
    'pauseStartAt': pauseStartAt?.toIso8601String(),
    'pauseEndAt': pauseEndAt?.toIso8601String(),
    'frequency': frequency,
    'scheduleHour': scheduleHour,
    'scheduleMinute': scheduleMinute,
    'dayOfWeek': dayOfWeek,
    'dayOfMonth': dayOfMonth,
    'monthOfYear': monthOfYear,
    'intervalDays': intervalDays,
    'activeDaysMask': activeDaysMask,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'nextExecutedAt': nextExecutedAt?.toIso8601String(),
    'lastExecutedAt': lastExecutedAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory AutoGroupBackup.fromJson(Map<String, dynamic> json) =>
      AutoGroupBackup(
        ulid: json['ulid'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        isActive: json['isActive'] as bool,
        isPaused: json['isPaused'] as bool,
        pauseStartAt: json['pauseStartAt'] != null
            ? DateTime.parse(json['pauseStartAt'] as String)
            : null,
        pauseEndAt: json['pauseEndAt'] != null
            ? DateTime.parse(json['pauseEndAt'] as String)
            : null,
        frequency: json['frequency'] as int,
        scheduleHour: json['scheduleHour'] as int,
        scheduleMinute: json['scheduleMinute'] as int,
        dayOfWeek: json['dayOfWeek'] as int?,
        dayOfMonth: json['dayOfMonth'] as int?,
        monthOfYear: json['monthOfYear'] as int?,
        intervalDays: json['intervalDays'] as int,
        activeDaysMask: json['activeDaysMask'] as int,
        startDate: DateTime.parse(json['startDate'] as String),
        endDate: json['endDate'] != null
            ? DateTime.parse(json['endDate'] as String)
            : null,
        nextExecutedAt: json['nextExecutedAt'] != null
            ? DateTime.parse(json['nextExecutedAt'] as String)
            : null,
        lastExecutedAt: json['lastExecutedAt'] != null
            ? DateTime.parse(json['lastExecutedAt'] as String)
            : null,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  factory AutoGroupBackup.fromEntity(AutoTransactionGroup group) =>
      AutoGroupBackup(
        ulid: group.ulid,
        name: group.name,
        description: group.description,
        isActive: group.isActive,
        isPaused: group.isPaused,
        pauseStartAt: group.pauseStartAt,
        pauseEndAt: group.pauseEndAt,
        frequency: group.frequency,
        scheduleHour: group.scheduleHour,
        scheduleMinute: group.scheduleMinute,
        dayOfWeek: group.dayOfWeek,
        dayOfMonth: group.dayOfMonth,
        monthOfYear: group.monthOfYear,
        intervalDays: group.intervalDays,
        activeDaysMask: group.activeDaysMask,
        startDate: group.startDate,
        endDate: group.endDate,
        nextExecutedAt: group.nextExecutedAt,
        lastExecutedAt: group.lastExecutedAt,
        createdAt: group.createdAt,
        updatedAt: group.updatedAt,
      );
}

/// Backup model untuk AutoTransactionItem
class AutoItemBackup {
  final String ulid;
  final String groupUlid;
  final String transactionUlid;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AutoItemBackup({
    required this.ulid,
    required this.groupUlid,
    required this.transactionUlid,
    required this.isActive,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'ulid': ulid,
    'groupUlid': groupUlid,
    'transactionUlid': transactionUlid,
    'isActive': isActive,
    'sortOrder': sortOrder,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory AutoItemBackup.fromJson(Map<String, dynamic> json) => AutoItemBackup(
    ulid: json['ulid'] as String,
    groupUlid: json['groupUlid'] as String,
    transactionUlid: json['transactionUlid'] as String,
    isActive: json['isActive'] as bool,
    sortOrder: json['sortOrder'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  factory AutoItemBackup.fromEntity(AutoTransactionItem item) => AutoItemBackup(
    ulid: item.ulid,
    groupUlid: item.group.target!.ulid,
    transactionUlid: item.transaction.target!.ulid,
    isActive: item.isActive,
    sortOrder: item.sortOrder,
    createdAt: item.createdAt,
    updatedAt: item.updatedAt,
  );
}

/// Backup model untuk AutoTransactionLog
class AutoLogBackup {
  final String ulid;
  final String groupUlid;
  final DateTime scheduledAt;
  final DateTime executedAt;
  final int status;
  final int successCount;
  final int failureCount;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AutoLogBackup({
    required this.ulid,
    required this.groupUlid,
    required this.scheduledAt,
    required this.executedAt,
    required this.status,
    required this.successCount,
    required this.failureCount,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'ulid': ulid,
    'groupUlid': groupUlid,
    'scheduledAt': scheduledAt.toIso8601String(),
    'executedAt': executedAt.toIso8601String(),
    'status': status,
    'successCount': successCount,
    'failureCount': failureCount,
    'errorMessage': errorMessage,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory AutoLogBackup.fromJson(Map<String, dynamic> json) => AutoLogBackup(
    ulid: json['ulid'] as String,
    groupUlid: json['groupUlid'] as String,
    scheduledAt: DateTime.parse(json['scheduledAt'] as String),
    executedAt: DateTime.parse(json['executedAt'] as String),
    status: json['status'] as int,
    successCount: json['successCount'] as int,
    failureCount: json['failureCount'] as int,
    errorMessage: json['errorMessage'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  factory AutoLogBackup.fromEntity(AutoTransactionLog log) => AutoLogBackup(
    ulid: log.ulid,
    groupUlid: log.group.target!.ulid,
    scheduledAt: log.scheduledAt,
    executedAt: log.executedAt,
    status: log.status,
    successCount: log.successCount,
    failureCount: log.failureCount,
    errorMessage: log.errorMessage,
    createdAt: log.createdAt,
    updatedAt: log.updatedAt,
  );
}
