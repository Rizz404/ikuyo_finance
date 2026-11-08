import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ikuyo_finance/features/security/cubit/security_cubit.dart';
import 'package:ikuyo_finance/features/security/models/security_settings.dart';
import 'package:ikuyo_finance/features/security/screens/lock_screen.dart';
import 'package:ikuyo_finance/features/security/services/biometric_service.dart';
import 'package:ikuyo_finance/features/security/services/security_storage_service.dart';
import 'package:ikuyo_finance/features/security/utils/security_hasher.dart';

import '../test/support/test_logger.dart';

/// End-to-end test driving the real [LockScreen] + real [SecurityCubit]
/// against a real 4-digit PIN comparison ([SecurityHasher] is not mocked).
///
/// Biometric hardware isn't available in this test environment (nor is it
/// guaranteed on any given emulator/device), so [BiometricService] is
/// mocked to report "unavailable". [SecurityStorageService] is mocked
/// purely to avoid touching the real device's secure storage; the settings
/// it returns are otherwise the real production `SecuritySettings` model.
///
/// Regression test for a fixed race condition: `SecurityCubit._init()`
/// loads settings asynchronously (`await _storageService.load()`), so on
/// the very first frame the cubit is still in its default `SecurityState()`
/// (`canUseBiometric`/`canUsePin` both false). `LockScreen` now re-evaluates
/// its initial view reactively via `BlocListener` whenever `canUseBiometric`
/// / `canUsePin` / `canUsePassword` change, so once settings finish loading
/// the screen lands on the PIN view on its own — no manual "Use PIN" tap
/// required, even though biometric is unavailable here.
class MockSecurityStorageService extends Mock implements SecurityStorageService {}

class MockBiometricService extends Mock implements BiometricService {}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockSecurityStorageService storageService;
  late MockBiometricService biometricService;
  const correctPin = '1234';

  setUpAll(bootstrapTestLogger);

  setUp(() {
    storageService = MockSecurityStorageService();
    biometricService = MockBiometricService();
    when(() => biometricService.isAvailable).thenAnswer((_) async => false);
    when(() => biometricService.isDeviceSupported).thenAnswer((_) async => false);
    when(() => storageService.lockEnabledHint).thenReturn(null);
    when(() => storageService.load()).thenAnswer(
      (_) async => SecuritySettings(
        isEnabled: true,
        pinEnabled: true,
        pinHash: SecurityHasher.hash(correctPin),
        pinLength: 4,
      ),
    );
  });

  Widget boot() {
    return EasyLocalization(
      supportedLocales: const [Locale('en', 'US'), Locale('id', 'ID')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en', 'US'),
      startLocale: const Locale('en', 'US'),
      child: BlocProvider<SecurityCubit>(
        create: (_) => SecurityCubit(storageService, biometricService),
        child: const MaterialApp(home: LockScreen()),
      ),
    );
  }

  Future<void> goToPinView(WidgetTester tester) async {
    await tester.pumpWidget(boot());
    await tester.pumpAndSettle();
  }

  testWidgets(
    'lands directly on the PIN view once settings finish loading, '
    'with no manual "Use PIN" tap needed',
    (tester) async {
      await goToPinView(tester);

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.fingerprint), findsNothing);
    },
  );

  testWidgets('entering the correct PIN unlocks the cubit', (tester) async {
    await goToPinView(tester);

    await tester.enterText(find.byType(TextField), correctPin);
    await tester.pumpAndSettle();

    final cubit = tester.element(find.byType(LockScreen)).read<SecurityCubit>();
    expect(cubit.state.status, SecurityStatus.unlocked);
  });

  testWidgets('entering an incorrect PIN fails and clears the field', (tester) async {
    await goToPinView(tester);

    await tester.enterText(find.byType(TextField), '0000');
    await tester.pumpAndSettle();

    final cubit = tester.element(find.byType(LockScreen)).read<SecurityCubit>();
    expect(cubit.state.status, SecurityStatus.locked);
    expect(cubit.state.authResult, SecurityAuthResult.failed);
    expect(cubit.state.failedAttempts, 1);

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller!.text, isEmpty);
  });
}
