import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/security/validators/password_validator.dart';

import '../../../support/locale_test_helper.dart';

void main() {
  group('PasswordValidator.password', () {
    testWidgets('rejects null', (tester) async {
      await loadTestLocale(tester);
      expect(PasswordValidator.password(null), isNotNull);
    });

    testWidgets('rejects an empty string', (tester) async {
      await loadTestLocale(tester);
      expect(PasswordValidator.password(''), isNotNull);
    });

    testWidgets('rejects a password below 6 characters', (tester) async {
      await loadTestLocale(tester);
      expect(PasswordValidator.password('abc12'), isNotNull);
    });

    testWidgets('accepts a password exactly 6 characters long (boundary)', (tester) async {
      await loadTestLocale(tester);
      expect(PasswordValidator.password('abc123'), isNull);
    });

    testWidgets('accepts a password longer than 6 characters', (tester) async {
      await loadTestLocale(tester);
      expect(PasswordValidator.password('a-much-longer-password'), isNull);
    });
  });

  group('PasswordValidator.confirmPassword', () {
    testWidgets('rejects a mismatch', (tester) async {
      await loadTestLocale(tester);
      expect(PasswordValidator.confirmPassword('abc123', 'abc124'), isNotNull);
    });

    testWidgets('accepts a matching confirmation', (tester) async {
      await loadTestLocale(tester);
      expect(PasswordValidator.confirmPassword('abc123', 'abc123'), isNull);
    });

    testWidgets('rejects when confirmation is null but password is not', (tester) async {
      await loadTestLocale(tester);
      expect(PasswordValidator.confirmPassword('abc123', null), isNotNull);
    });

    testWidgets('treats both null as matching (no mismatch reported)', (tester) async {
      await loadTestLocale(tester);
      expect(PasswordValidator.confirmPassword(null, null), isNull);
    });
  });
}
