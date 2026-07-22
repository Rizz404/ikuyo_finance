import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/asset/validators/update_asset_validator.dart';

import '../../../support/locale_test_helper.dart';

void main() {
  group('UpdateAssetValidator.ulid', () {
    testWidgets('rejects null and empty', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateAssetValidator.ulid(null), isNotNull);
      expect(UpdateAssetValidator.ulid(''), isNotNull);
    });

    testWidgets('accepts a non-empty ulid', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateAssetValidator.ulid('01ABCDEF'), isNull);
    });
  });

  group('UpdateAssetValidator.name', () {
    testWidgets('null/empty is allowed (optional on update)', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateAssetValidator.name(null), isNull);
      expect(UpdateAssetValidator.name(''), isNull);
    });

    testWidgets('rejects a name below the minimum length when provided', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateAssetValidator.name('A'), isNotNull);
    });

    testWidgets('rejects a name above the maximum length when provided', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateAssetValidator.name('A' * 51), isNotNull);
    });

    testWidgets('accepts a valid name', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateAssetValidator.name('Wallet'), isNull);
    });
  });

  group('UpdateAssetValidator.balance', () {
    testWidgets('null/empty is allowed (optional on update)', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateAssetValidator.balance(null), isNull);
      expect(UpdateAssetValidator.balance(''), isNull);
    });

    testWidgets('rejects a non-numeric value when provided', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateAssetValidator.balance('abc'), isNotNull);
    });

    testWidgets('rejects a negative value when provided', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateAssetValidator.balance('-1'), isNotNull);
    });

    testWidgets('accepts a valid positive value', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateAssetValidator.balance('250'), isNull);
    });
  });

  group('optional fields on update', () {
    testWidgets('type and icon never produce an error', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateAssetValidator.type(null), isNull);
      expect(UpdateAssetValidator.icon(null), isNull);
    });
  });
}
