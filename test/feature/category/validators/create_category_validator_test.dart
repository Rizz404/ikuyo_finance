import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/category/validators/create_category_validator.dart';

import '../../../support/locale_test_helper.dart';

void main() {
  group('CreateCategoryValidator.name', () {
    testWidgets('rejects null', (tester) async {
      await loadTestLocale(tester);
      expect(CreateCategoryValidator.name(null), isNotNull);
    });

    testWidgets('rejects an empty string', (tester) async {
      await loadTestLocale(tester);
      expect(CreateCategoryValidator.name(''), isNotNull);
    });

    testWidgets('rejects a single-character name (below min length)', (tester) async {
      await loadTestLocale(tester);
      expect(CreateCategoryValidator.name('A'), isNotNull);
    });

    testWidgets('rejects a name longer than 50 characters', (tester) async {
      await loadTestLocale(tester);
      expect(CreateCategoryValidator.name('A' * 51), isNotNull);
    });

    testWidgets('accepts a valid name', (tester) async {
      await loadTestLocale(tester);
      expect(CreateCategoryValidator.name('Food'), isNull);
    });

    testWidgets('accepts the boundary lengths (2 and 50 chars)', (tester) async {
      await loadTestLocale(tester);
      expect(CreateCategoryValidator.name('AB'), isNull);
      expect(CreateCategoryValidator.name('A' * 50), isNull);
    });
  });

  group('CreateCategoryValidator.type', () {
    testWidgets('rejects null', (tester) async {
      await loadTestLocale(tester);
      expect(CreateCategoryValidator.type(null), isNotNull);
    });

    testWidgets('accepts a non-null value', (tester) async {
      await loadTestLocale(tester);
      expect(CreateCategoryValidator.type('income'), isNull);
    });
  });

  group('optional fields', () {
    testWidgets('icon, color and parentUlid are always valid', (tester) async {
      await loadTestLocale(tester);
      expect(CreateCategoryValidator.icon(null), isNull);
      expect(CreateCategoryValidator.color(null), isNull);
      expect(CreateCategoryValidator.parentUlid(null), isNull);
    });
  });
}
