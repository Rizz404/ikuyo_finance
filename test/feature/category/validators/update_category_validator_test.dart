import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/category/validators/update_category_validator.dart';

import '../../../support/locale_test_helper.dart';

void main() {
  group('UpdateCategoryValidator.ulid', () {
    testWidgets('rejects null and empty', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateCategoryValidator.ulid(null), isNotNull);
      expect(UpdateCategoryValidator.ulid(''), isNotNull);
    });

    testWidgets('accepts a non-empty ulid', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateCategoryValidator.ulid('01ABCDEF'), isNull);
    });
  });

  group('UpdateCategoryValidator.name', () {
    testWidgets('null/empty is allowed (optional on update)', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateCategoryValidator.name(null), isNull);
      expect(UpdateCategoryValidator.name(''), isNull);
    });

    testWidgets('rejects a name below the minimum length when provided', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateCategoryValidator.name('A'), isNotNull);
    });

    testWidgets('rejects a name above the maximum length when provided', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateCategoryValidator.name('A' * 51), isNotNull);
    });

    testWidgets('accepts a valid name', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateCategoryValidator.name('Groceries'), isNull);
    });
  });

  group('optional fields on update', () {
    testWidgets('type, icon, color and parentUlid never produce an error', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateCategoryValidator.type(null), isNull);
      expect(UpdateCategoryValidator.icon(null), isNull);
      expect(UpdateCategoryValidator.color(null), isNull);
      expect(UpdateCategoryValidator.parentUlid(null), isNull);
    });
  });
}
