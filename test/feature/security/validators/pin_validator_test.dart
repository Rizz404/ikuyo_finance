import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/security/validators/pin_validator.dart';

import '../../../support/locale_test_helper.dart';

void main() {
  group('PinValidator.pin', () {
    testWidgets('rejects null', (tester) async {
      await loadTestLocale(tester);
      expect(PinValidator.pin(null, 6), isNotNull);
    });

    testWidgets('rejects a value shorter than the expected length', (tester) async {
      await loadTestLocale(tester);
      expect(PinValidator.pin('123', 6), isNotNull);
    });

    testWidgets('rejects a value longer than the expected length', (tester) async {
      await loadTestLocale(tester);
      expect(PinValidator.pin('1234567', 6), isNotNull);
    });

    testWidgets('accepts a value matching the expected 6-digit length', (tester) async {
      await loadTestLocale(tester);
      expect(PinValidator.pin('123456', 6), isNull);
    });

    testWidgets('accepts a value matching the expected 4-digit length', (tester) async {
      await loadTestLocale(tester);
      expect(PinValidator.pin('1234', 4), isNull);
    });

    testWidgets('rejects a 4-digit value when 6 is expected', (tester) async {
      await loadTestLocale(tester);
      expect(PinValidator.pin('1234', 6), isNotNull);
    });
  });

  group('PinValidator.confirmPin', () {
    testWidgets('rejects a mismatch', (tester) async {
      await loadTestLocale(tester);
      expect(PinValidator.confirmPin('123456', '654321'), isNotNull);
    });

    testWidgets('accepts a matching confirmation', (tester) async {
      await loadTestLocale(tester);
      expect(PinValidator.confirmPin('123456', '123456'), isNull);
    });

    testWidgets('rejects when confirmation is null but pin is not', (tester) async {
      await loadTestLocale(tester);
      expect(PinValidator.confirmPin('123456', null), isNotNull);
    });

    testWidgets('treats both null as matching (no mismatch reported)', (tester) async {
      await loadTestLocale(tester);
      expect(PinValidator.confirmPin(null, null), isNull);
    });
  });
}
