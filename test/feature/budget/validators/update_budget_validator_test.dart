import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/budget/validators/update_budget_validator.dart';

import '../../../support/locale_test_helper.dart';

void main() {
  group('UpdateBudgetValidator.ulid', () {
    testWidgets('rejects null and empty', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateBudgetValidator.ulid(null), isNotNull);
      expect(UpdateBudgetValidator.ulid(''), isNotNull);
    });

    testWidgets('accepts a non-empty ulid', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateBudgetValidator.ulid('01ABCDEF'), isNull);
    });
  });

  group('UpdateBudgetValidator.amountLimit', () {
    testWidgets('null/empty is allowed (optional on update)', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateBudgetValidator.amountLimit(null), isNull);
      expect(UpdateBudgetValidator.amountLimit(''), isNull);
    });

    testWidgets('rejects a non-numeric value when provided', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateBudgetValidator.amountLimit('abc'), isNotNull);
    });

    testWidgets('rejects zero when provided', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateBudgetValidator.amountLimit('0'), isNotNull);
    });

    testWidgets('rejects a negative value when provided', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateBudgetValidator.amountLimit('-1'), isNotNull);
    });

    testWidgets('accepts a valid positive value', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateBudgetValidator.amountLimit('750'), isNull);
    });
  });

  group('optional fields on update', () {
    testWidgets('categoryUlid, period, startDate and endDate never produce an error', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateBudgetValidator.categoryUlid(null), isNull);
      expect(UpdateBudgetValidator.period(null), isNull);
      expect(UpdateBudgetValidator.startDate(null), isNull);
      expect(UpdateBudgetValidator.endDate(null), isNull);
    });
  });
}
