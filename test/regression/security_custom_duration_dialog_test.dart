// Regression: BKSEC-8. The custom auto-lock dialog called `controller.dispose;`
// (a tear-off, never invoked), so its TextEditingController leaked. Disposing
// it right after showDialog would be wrong too, because the dialog still uses
// it. The controller must be disposed exactly when the dialog goes away.
// Real SecuritySettingsScreen + SecurityCubit; only platform storage is mocked.
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/features/security/cubit/security_cubit.dart';
import 'package:ikuyo_finance/features/security/models/security_settings.dart';
import 'package:ikuyo_finance/features/security/screens/security_settings_screen.dart';
import 'package:ikuyo_finance/features/security/services/biometric_service.dart';
import 'package:ikuyo_finance/features/security/services/security_storage_service.dart';
import 'package:ikuyo_finance/features/security/utils/security_hasher.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_logger.dart';

class _NoBiometrics extends Fake implements LocalAuthentication {
  @override
  Future<bool> get canCheckBiometrics async => false;
  @override
  Future<bool> isDeviceSupported() async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(bootstrapTestLogger);

  testWidgets('custom auto-lock dialog saves and disposes its controller',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({
      'app_security_settings': SecuritySettings(
        isEnabled: true,
        pinEnabled: true,
        pinHash: SecurityHasher.hash('123456'),
      ).encode(),
    });
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final cubit = SecurityCubit(
      SecurityStorageService(const FlutterSecureStorage(), prefs),
      BiometricService(_NoBiometrics()),
    );

    await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('en', 'US'), Locale('id', 'ID')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en', 'US'),
      startLocale: const Locale('en', 'US'),
      child: Builder(
        builder: (context) => BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: const SecuritySettingsScreen(),
          ),
        ),
      ),
    ));
    for (var i = 0;
        i < 40 && find.byIcon(Icons.timer_outlined).evaluate().isEmpty;
        i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }

    final live = <Object>{};
    void track(ObjectEvent e) {
      if (e is ObjectCreated && e.object is TextEditingController) {
        live.add(e.object);
      } else if (e is ObjectDisposed) {
        live.remove(e.object);
      }
    }

    FlutterMemoryAllocations.instance.addListener(track);
    addTearDown(() => FlutterMemoryAllocations.instance.removeListener(track));

    await tester.ensureVisible(find.byIcon(Icons.timer_outlined));
    await tester.tap(find.byIcon(Icons.timer_outlined));
    await tester.pumpAndSettle();
    final custom = find.text(LocaleKeys.securityAutoLockCustom.tr());
    await tester.ensureVisible(custom);
    await tester.pumpAndSettle();
    await tester.tap(custom);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(live, isNotEmpty);

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '7',
    );
    await tester.tap(find.text(LocaleKeys.securitySave.tr()));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(cubit.state.settings.autoLockMinutes, 7);
    expect(live, isEmpty, reason: 'dialog TextEditingController leaked');
    await cubit.close();
  });
}
