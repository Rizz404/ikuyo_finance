import 'package:go_router/go_router.dart';
import 'package:ikuyo_finance/core/router/app_page_transitions.dart';
import 'package:ikuyo_finance/core/router/app_routes.dart';
import 'package:ikuyo_finance/core/router/router_listenables.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/asset/screens/asset_screen.dart';
import 'package:ikuyo_finance/features/asset/screens/asset_upsert_screen.dart';
import 'package:ikuyo_finance/features/auth/screens/sign_in_screen.dart';
import 'package:ikuyo_finance/features/auth/screens/sign_up_screen.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/budget/screens/budget_screen.dart';
import 'package:ikuyo_finance/features/budget/screens/budget_upsert_screen.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/category/screens/category_screen.dart';
import 'package:ikuyo_finance/features/category/screens/category_upsert_screen.dart';
import 'package:ikuyo_finance/features/setting/screens/setting_screen.dart';
import 'package:ikuyo_finance/features/statistic/screens/statistic_screen.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/features/transaction/screens/transaction_screen.dart';
import 'package:ikuyo_finance/features/transaction/screens/transaction_search_screen.dart';
import 'package:ikuyo_finance/features/transaction/screens/transaction_upsert_screen.dart';
import 'package:ikuyo_finance/shared/widgets/user_shell.dart';

// * Router instance
GoRouter createAppRouter(SupabaseAuthListenable authListenable) {
  return GoRouter(
    navigatorKey: AppRoutes.rootNavigatorKey,
    initialLocation: AppRoutes.transactionPath,
    refreshListenable: authListenable,
    redirect: (context, state) {
      final isAuthenticated = authListenable.isAuthenticated;
      final isGoingToAuth =
          state.matchedLocation == AppRoutes.signInPath ||
          state.matchedLocation == AppRoutes.signUpPath;

      // * Redirect ke home jika sudah autentikasi tapi ke auth screen
      if (isAuthenticated && isGoingToAuth) {
        return AppRoutes.transactionPath;
      }

      return null;
    },
    routes: [
      // * Auth routes - fade transition (elegant untuk auth flow)
      GoRoute(
        name: AppRoutes.signInName,
        path: AppRoutes.signInPath,
        pageBuilder: (context, state) => AppPageTransitions.fade(
          key: state.pageKey,
          child: const SignInScreen(),
        ),
      ),
      GoRoute(
        name: AppRoutes.signUpName,
        path: AppRoutes.signUpPath,
        pageBuilder: (context, state) => AppPageTransitions.slideRight(
          key: state.pageKey,
          child: const SignUpScreen(),
        ),
      ),
      // * Main shell dengan navigation bar
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            UserShell(navigationShell: navigationShell),
        branches: [
          // * Transaction Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRoutes.transactionName,
                path: AppRoutes.transactionPath,
                pageBuilder: (context, state) => AppPageTransitions.fadeThrough(
                  key: state.pageKey,
                  child: const TransactionScreen(),
                ),
                routes: [
                  // * Add transaction - slide from bottom (modal-like)
                  GoRoute(
                    name: AppRoutes.transactionAddName,
                    path: AppRoutes.transactionAddPath,
                    pageBuilder: (context, state) =>
                        AppPageTransitions.slideBottom(
                          key: state.pageKey,
                          child: const TransactionUpsertScreen(),
                        ),
                  ),
                  // * Edit transaction - slide from right (detail screen)
                  GoRoute(
                    name: AppRoutes.transactionEditName,
                    path: AppRoutes.transactionEditPath,
                    pageBuilder: (context, state) {
                      final transaction = state.extra as Transaction?;
                      return AppPageTransitions.slideRight(
                        key: state.pageKey,
                        child: TransactionUpsertScreen(
                          transaction: transaction,
                        ),
                      );
                    },
                  ),
                  // * Search transaction - slide from right
                  GoRoute(
                    name: AppRoutes.transactionSearchName,
                    path: AppRoutes.transactionSearchPath,
                    pageBuilder: (context, state) =>
                        AppPageTransitions.slideRight(
                          key: state.pageKey,
                          child: const TransactionSearchScreen(),
                        ),
                  ),
                ],
              ),
            ],
          ),
          // * Statistic Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRoutes.statisticName,
                path: AppRoutes.statisticPath,
                pageBuilder: (context, state) => AppPageTransitions.fadeThrough(
                  key: state.pageKey,
                  child: const StatisticScreen(),
                ),
              ),
            ],
          ),
          // * Asset Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRoutes.assetName,
                path: AppRoutes.assetPath,
                pageBuilder: (context, state) => AppPageTransitions.fadeThrough(
                  key: state.pageKey,
                  child: const AssetScreen(),
                ),
                routes: [
                  // * Add asset - slide from bottom
                  GoRoute(
                    name: AppRoutes.assetAddName,
                    path: AppRoutes.assetAddPath,
                    pageBuilder: (context, state) =>
                        AppPageTransitions.slideBottom(
                          key: state.pageKey,
                          child: const AssetUpsertScreen(),
                        ),
                  ),
                  // * Edit asset - slide from right
                  GoRoute(
                    name: AppRoutes.assetEditName,
                    path: AppRoutes.assetEditPath,
                    pageBuilder: (context, state) {
                      final asset = state.extra as Asset?;
                      return AppPageTransitions.slideRight(
                        key: state.pageKey,
                        child: AssetUpsertScreen(asset: asset),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          // * Setting Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRoutes.settingName,
                path: AppRoutes.settingPath,
                pageBuilder: (context, state) => AppPageTransitions.fadeThrough(
                  key: state.pageKey,
                  child: const SettingScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
      // * Category routes - outside shell (fullscreen)
      GoRoute(
        name: AppRoutes.categoryName,
        path: AppRoutes.categoryPath,
        pageBuilder: (context, state) => AppPageTransitions.slideRight(
          key: state.pageKey,
          child: const CategoryScreen(),
        ),
        routes: [
          // * Add category - slide from bottom
          GoRoute(
            name: AppRoutes.categoryAddName,
            path: AppRoutes.categoryAddPath,
            pageBuilder: (context, state) => AppPageTransitions.slideBottom(
              key: state.pageKey,
              child: const CategoryUpsertScreen(),
            ),
          ),
          // * Edit category - slide from right
          GoRoute(
            name: AppRoutes.categoryEditName,
            path: AppRoutes.categoryEditPath,
            pageBuilder: (context, state) {
              final category = state.extra as Category?;
              return AppPageTransitions.slideRight(
                key: state.pageKey,
                child: CategoryUpsertScreen(category: category),
              );
            },
          ),
        ],
      ),
      // * Budget routes - outside shell (fullscreen)
      GoRoute(
        name: AppRoutes.budgetName,
        path: AppRoutes.budgetPath,
        pageBuilder: (context, state) => AppPageTransitions.slideRight(
          key: state.pageKey,
          child: const BudgetScreen(),
        ),
        routes: [
          // * Add budget - slide from bottom
          GoRoute(
            name: AppRoutes.budgetAddName,
            path: AppRoutes.budgetAddPath,
            pageBuilder: (context, state) => AppPageTransitions.slideBottom(
              key: state.pageKey,
              child: const BudgetUpsertScreen(),
            ),
          ),
          // * Edit budget - slide from right
          GoRoute(
            name: AppRoutes.budgetEditName,
            path: AppRoutes.budgetEditPath,
            pageBuilder: (context, state) {
              final budget = state.extra as Budget?;
              return AppPageTransitions.slideRight(
                key: state.pageKey,
                child: BudgetUpsertScreen(budget: budget),
              );
            },
          ),
        ],
      ),
    ],
  );
}
