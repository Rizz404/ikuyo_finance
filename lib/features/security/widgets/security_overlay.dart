import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/features/security/cubit/security_cubit.dart';
import 'package:ikuyo_finance/features/security/screens/lock_screen.dart';

/// Menutup konten app dengan [LockScreen] selama terkunci / settings belum
/// terbaca (fail-closed). Konten tetap di tree agar state tidak hilang,
/// tapi tidak dilukis, tidak menerima input, dan dikeluarkan dari semantics.
class SecurityOverlay extends StatelessWidget {
  final Widget child;
  const SecurityOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SecurityCubit, SecurityState>(
      buildWhen: (prev, curr) => prev.shouldLock != curr.shouldLock,
      builder: (context, state) {
        final locked = state.shouldLock;
        return Stack(
          children: [
            Offstage(
              offstage: locked,
              child: ExcludeSemantics(
                excluding: locked,
                child: TickerMode(enabled: !locked, child: child),
              ),
            ),
            if (locked)
              Positioned.fill(
                child: Navigator(
                  onDidRemovePage: (_) {},
                  pages: const [MaterialPage(child: LockScreen())],
                ),
              ),
          ],
        );
      },
    );
  }
}
