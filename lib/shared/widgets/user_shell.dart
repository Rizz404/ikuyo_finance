import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/utils/toast_helper.dart';

// * Shell untuk user dengan navigation bar
class UserShell extends StatefulWidget {
  const UserShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  State<UserShell> createState() => _UserShellState();
}

class _UserShellState extends State<UserShell> {
  DateTime? _lastBackPressTime;

  // * Transaction tab index = 0
  static const int _transactionTabIndex = 0;
  static const Duration _doubleTapDuration = Duration(seconds: 2);

  void _handleBackPress(bool didPop) {
    if (didPop) return;

    final currentIndex = widget.navigationShell.currentIndex;

    // * Jika bukan di transaction tab, kembali ke transaction
    if (currentIndex != _transactionTabIndex) {
      widget.navigationShell.goBranch(_transactionTabIndex);
      return;
    }

    // * Di transaction tab - double tap to exit
    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > _doubleTapDuration) {
      _lastBackPressTime = now;
      ToastHelper.instance.showInfo(
        context: context,
        title: LocaleKeys.sharedWidgetsUserShellBackToExit.tr(),
        duration: _doubleTapDuration,
        showProgressBar: true,
      );
      return;
    }

    // * Double tap detected - exit app
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _handleBackPress(didPop),
      child: Scaffold(
        body: widget.navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: (index) {
            widget.navigationShell.goBranch(
              index,
              initialLocation: index == widget.navigationShell.currentIndex,
            );
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long),
              label: LocaleKeys.sharedWidgetsUserShellTransactions.tr(),
            ),
            NavigationDestination(
              icon: const Icon(Icons.bar_chart_outlined),
              selectedIcon: const Icon(Icons.bar_chart),
              label: LocaleKeys.sharedWidgetsUserShellStatistics.tr(),
            ),
            NavigationDestination(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: const Icon(Icons.account_balance_wallet),
              label: LocaleKeys.sharedWidgetsUserShellAssets.tr(),
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: LocaleKeys.sharedWidgetsUserShellSettings.tr(),
            ),
          ],
        ),
      ),
    );
  }
}
