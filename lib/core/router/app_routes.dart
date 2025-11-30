import 'package:flutter/widgets.dart';

/// * Centralized route definitions
/// Contains all route names, paths, and navigation keys
final class AppRoutes {
  AppRoutes._(); // * Private constructor - prevent instantiation

  // * Navigator Keys (only root and shell needed)
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');
  static final GlobalKey<NavigatorState> shellNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'shell');

  // * Auth Routes
  static const String signInName = 'sign-in';
  static const String signInPath = '/sign-in';

  static const String signUpName = 'sign-up';
  static const String signUpPath = '/sign-up';

  // * Transaction Routes
  static const String transactionName = 'transaction';
  static const String transactionPath = '/';

  static const String transactionAddName = 'transaction-add';
  static const String transactionAddPath = 'transaction/add';

  static const String transactionEditName = 'transaction-edit';
  static const String transactionEditPath = 'transaction/edit';

  static const String transactionSearchName = 'transaction-search';
  static const String transactionSearchPath = 'transaction/search';

  // * Statistic Routes
  static const String statisticName = 'statistic';
  static const String statisticPath = '/statistic';

  // * Asset Routes
  static const String assetName = 'asset';
  static const String assetPath = '/asset';

  static const String assetAddName = 'asset-add';
  static const String assetAddPath = 'add';

  static const String assetEditName = 'asset-edit';
  static const String assetEditPath = 'edit';

  // * Setting Routes
  static const String settingName = 'setting';
  static const String settingPath = '/setting';

  // * Category Routes
  static const String categoryName = 'category';
  static const String categoryPath = '/categories';

  static const String categoryAddName = 'category-add';
  static const String categoryAddPath = 'add';

  static const String categoryEditName = 'category-edit';
  static const String categoryEditPath = 'edit';

  // * Budget Routes
  static const String budgetName = 'budget';
  static const String budgetPath = '/budget';

  static const String budgetAddName = 'budget-add';
  static const String budgetAddPath = 'add';

  static const String budgetEditName = 'budget-edit';
  static const String budgetEditPath = 'edit';
}
