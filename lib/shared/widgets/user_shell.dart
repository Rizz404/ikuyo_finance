import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
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
        title: 'Tekan sekali lagi untuk keluar',
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
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Transaksi',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Statistik',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Aset',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Pengaturan',
            ),
          ],
        ),
      ),
    );
  }
}
