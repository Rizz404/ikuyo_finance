import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ikuyo_finance/core/router/app_routes.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';

/// * Navigation utility extension for type-safe routing
/// * go() = replace stack (untuk switch antar tab/branch)
/// * push() = add to stack (untuk navigasi ke child route)
extension AppNavigator on BuildContext {
  // * Auth Navigation (go - replace karena flow berbeda)
  void goToSignIn() => go(AppRoutes.signInPath);
  void goToSignUp() => go(AppRoutes.signUpPath);

  // * Main Tab Navigation (go - replace untuk switch tab)
  void goToTransaction() => go(AppRoutes.transactionPath);
  void goToStatistic() => go(AppRoutes.statisticPath);
  void goToAsset() => go(AppRoutes.assetPath);
  void goToOther() => go(AppRoutes.otherPath);

  // * Other Child Routes (push - add to stack)
  void pushToSetting() => push(AppRoutes.settingPath);
  void pushToBackup() => push(AppRoutes.backupPath);
  void pushToSecurity() => push(AppRoutes.securityPath);

  // * Transaction Child Routes (push - add to stack)
  void pushToAddTransaction() => push('/${AppRoutes.transactionAddPath}');
  void pushToBulkCopyTransaction() =>
      push('/${AppRoutes.transactionBulkCopyPath}');
  void pushToEditTransaction(Transaction transaction) =>
      push('/${AppRoutes.transactionEditPath}', extra: transaction);
  void pushToSearchTransaction() => push('/${AppRoutes.transactionSearchPath}');

  // * Asset Child Routes (push - add to stack)
  void pushToAddAsset() =>
      push('${AppRoutes.assetPath}/${AppRoutes.assetAddPath}');
  void pushToEditAsset(Asset asset) =>
      push('${AppRoutes.assetPath}/${AppRoutes.assetEditPath}', extra: asset);
  void pushToSearchAsset() =>
      push('${AppRoutes.assetPath}/${AppRoutes.assetSearchPath}');

  // * Category Navigation
  void pushToCategory() => push(AppRoutes.categoryPath);
  void pushToAddCategory() =>
      push('${AppRoutes.categoryPath}/${AppRoutes.categoryAddPath}');
  void pushToEditCategory(Category category) => push(
    '${AppRoutes.categoryPath}/${AppRoutes.categoryEditPath}',
    extra: category,
  );
  void pushToSearchCategory() =>
      push('${AppRoutes.categoryPath}/${AppRoutes.categorySearchPath}');

  // * Budget Navigation
  void pushToBudget() => push(AppRoutes.budgetPath);
  void pushToAddBudget() =>
      push('${AppRoutes.budgetPath}/${AppRoutes.budgetAddPath}');
  void pushToEditBudget(Budget budget) => push(
    '${AppRoutes.budgetPath}/${AppRoutes.budgetEditPath}',
    extra: budget,
  );
  void pushToSearchBudget() =>
      push('${AppRoutes.budgetPath}/${AppRoutes.budgetSearchPath}');

  // * Named Navigation (alternative using route names)
  void goToNamed(String name, {Object? extra, Map<String, String>? params}) =>
      goNamed(name, extra: extra, pathParameters: params ?? {});

  void pushToNamed(String name, {Object? extra, Map<String, String>? params}) =>
      pushNamed(name, extra: extra, pathParameters: params ?? {});
}
