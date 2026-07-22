import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/asset/validators/create_asset_validator.dart';

import '../../../support/locale_test_helper.dart';

void main() {
  group('CreateAssetValidator.name', () {
    testWidgets('rejects null', (tester) async {
      await loadTestLocale(tester);
      expect(CreateAssetValidator.name(null), isNotNull);
    });

    testWidgets('rejects an empty string', (tester) async {
      await loadTestLocale(tester);
      expect(CreateAssetValidator.name(''), isNotNull);
    });

    testWidgets('rejects a single-character name (below min length)', (tester) async {
      await loadTestLocale(tester);
      expect(CreateAssetValidator.name('A'), isNotNull);
    });

    testWidgets('rejects a name longer than 50 characters', (tester) async {
      await loadTestLocale(tester);
      expect(CreateAssetValidator.name('A' * 51), isNotNull);
    });

    testWidgets('accepts a valid name', (tester) async {
      await loadTestLocale(tester);
      expect(CreateAssetValidator.name('Cash'), isNull);
    });

    testWidgets('accepts the boundary lengths (2 and 50 chars)', (tester) async {
      await loadTestLocale(tester);
      expect(CreateAssetValidator.name('AB'), isNull);
      expect(CreateAssetValidator.name('A' * 50), isNull);
    });
  });

  group('CreateAssetValidator.type', () {
    testWidgets('rejects null', (tester) async {
      await loadTestLocale(tester);
      expect(CreateAssetValidator.type(null), isNotNull);
    });

    testWidgets('accepts a non-null value', (tester) async {
      await loadTestLocale(tester);
      expect(CreateAssetValidator.type('cash'), isNull);
    });
  });

  group('CreateAssetValidator.balance', () {
    testWidgets('is optional and defaults to 0', (tester) async {
      await loadTestLocale(tester);
      expect(CreateAssetValidator.balance(null), isNull);
      expect(CreateAssetValidator.balance(''), isNull);
    });

    testWidgets('rejects a non-numeric value', (tester) async {
      await loadTestLocale(tester);
      expect(CreateAssetValidator.balance('abc'), isNotNull);
    });

    testWidgets('rejects a negative value', (tester) async {
      await loadTestLocale(tester);
      expect(CreateAssetValidator.balance('-100'), isNotNull);
    });

    testWidgets('accepts zero', (tester) async {
      await loadTestLocale(tester);
      expect(CreateAssetValidator.balance('0'), isNull);
    });

    testWidgets('accepts a positive value', (tester) async {
      await loadTestLocale(tester);
      expect(CreateAssetValidator.balance('1500000'), isNull);
    });

    testWidgets('accepts a comma as decimal separator', (tester) async {
      await loadTestLocale(tester);
      expect(CreateAssetValidator.balance('100,50'), isNull);
    });
  });

  group('optional fields', () {
    testWidgets('icon is always valid', (tester) async {
      await loadTestLocale(tester);
      expect(CreateAssetValidator.icon(null), isNull);
      expect(CreateAssetValidator.icon('/tmp/icon.png'), isNull);
    });
  });
}
