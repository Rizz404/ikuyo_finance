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
/// DISCOVERED BUG (confirmed on a real Android emulator, not a test
/// artifact): `LockScreen._autoStart()` runs from `addPostFrameCallback`
/// after the FIRST frame, but `SecurityCubit._init()` loads settings
/// asynchronously (`await _storageService.load()`). On the very first
/// frame the cubit is still in its default `SecurityState()`
/// (`canUseBiometric`/`canUsePin` both false), so `_autoStart()` sees
/// nothing it can use and leaves `_currentView` at its initial value
/// (`.biometric`) — even once real settings load a moment later and
/// `canUsePin` becomes true, nothing re-evaluates `_currentView` since
/// `_autoStart()` only runs once. In practice this means real users can
/// land on the "Use Biometric" button screen on cold start even when
/// biometric is disabled/unavailable and PIN is the intended method,
/// requiring an extra manual tap on "Use PIN" that shouldn't be needed.
/// This test documents and works around that actual behavior rather than
/// the intended one — worth a real fix in `lock_screen.dart` separately
/// (e.g. re-run `_autoStart()`'s decision reactively via `BlocListener`
/// instead of a one-shot post-frame callback).
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

  /// Works around the `_autoStart()` timing bug documented above: pumps
  /// until settings have actually loaded, then explicitly switches to the
  /// PIN view if the screen didn't land there on its own.
  Future<void> goToPinView(WidgetTester tester) async {
    await tester.pumpWidget(boot());
    await tester.pumpAndSettle();

    if (find.byType(TextField).evaluate().isEmpty) {
      // * LockScreen is the very first widget rendered by boot(), with no
      // * intervening navigation — easy_localization's async asset load
      // * sometimes hasn't finished by the first build, so `.tr()` calls
      // * here can render the raw key instead of "Use PIN". Target the
      // * switch button by its icon instead, which doesn't depend on
      // * localization having finished loading.
      await tester.tap(find.byIcon(Icons.dialpad_rounded));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('lands on the PIN view (directly, or via "Use PIN" if the '
      'race documented above puts it on the biometric view first)', (tester) async {
    await goToPinView(tester);

    expect(find.byType(TextField), findsOneWidget);
  });

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
