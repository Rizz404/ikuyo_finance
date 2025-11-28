import 'package:go_router/go_router.dart';
import 'package:ikuyo_finance/core/router/router_listenables.dart';
import 'package:ikuyo_finance/features/asset/screens/asset_screen.dart';
import 'package:ikuyo_finance/features/auth/screens/sign_in_screen.dart';
import 'package:ikuyo_finance/features/auth/screens/sign_up_screen.dart';
import 'package:ikuyo_finance/features/setting/screens/setting_screen.dart';
import 'package:ikuyo_finance/features/statistic/screens/statistic_screen.dart';
import 'package:ikuyo_finance/features/transaction/screens/transaction_screen.dart';
import 'package:ikuyo_finance/shared/widgets/user_shell.dart';

// * Router instance
GoRouter createAppRouter(SupabaseAuthListenable authListenable) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: authListenable,
    redirect: (context, state) {
      final isAuthenticated = authListenable.isAuthenticated;
      final isGoingToAuth =
          state.matchedLocation == '/sign-in' ||
          state.matchedLocation == '/sign-up';

      // * Redirect ke home jika sudah autentikasi tapi ke auth screen
      if (isAuthenticated && isGoingToAuth) {
        return '/';
      }

      return null;
    },
    routes: [
      // * Auth routes
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/sign-up',
        builder: (context, state) => const SignUpScreen(),
      ),
      // * Main shell dengan navigation bar
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            UserShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const TransactionScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/statistic',
                builder: (context, state) => const StatisticScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/asset',
                builder: (context, state) => const AssetScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/setting',
                builder: (context, state) => const SettingScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
