import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/budget/validators/create_budget_validator.dart';

import '../../../support/locale_test_helper.dart';

void main() {
  group('CreateBudgetValidator.categoryUlid', () {
    testWidgets('rejects null', (tester) async {
      await loadTestLocale(tester);
      expect(CreateBudgetValidator.categoryUlid(null), isNotNull);
    });

    testWidgets('rejects an empty string', (tester) async {
      await loadTestLocale(tester);
      expect(CreateBudgetValidator.categoryUlid(''), isNotNull);
    });

    testWidgets('accepts a non-empty ulid', (tester) async {
      await loadTestLocale(tester);
      expect(CreateBudgetValidator.categoryUlid('01ABCDEF'), isNull);
    });
  });

  group('CreateBudgetValidator.amountLimit', () {
    testWidgets('rejects null', (tester) async {
      await loadTestLocale(tester);
      expect(CreateBudgetValidator.amountLimit(null), isNotNull);
    });

    testWidgets('rejects an empty string', (tester) async {
      await loadTestLocale(tester);
      expect(CreateBudgetValidator.amountLimit(''), isNotNull);
    });

    testWidgets('rejects a non-numeric value', (tester) async {
      await loadTestLocale(tester);
      expect(CreateBudgetValidator.amountLimit('abc'), isNotNull);
    });

    testWidgets('rejects zero', (tester) async {
      await loadTestLocale(tester);
      expect(CreateBudgetValidator.amountLimit('0'), isNotNull);
    });

    testWidgets('rejects a negative value', (tester) async {
      await loadTestLocale(tester);
      expect(CreateBudgetValidator.amountLimit('-100'), isNotNull);
    });

    testWidgets('accepts a positive value', (tester) async {
      await loadTestLocale(tester);
      expect(CreateBudgetValidator.amountLimit('1000000'), isNull);
    });

    testWidgets('accepts a comma as decimal separator', (tester) async {
      await loadTestLocale(tester);
      expect(CreateBudgetValidator.amountLimit('100,50'), isNull);
    });
  });

  group('CreateBudgetValidator.period', () {
    testWidgets('rejects null', (tester) async {
      await loadTestLocale(tester);
      expect(CreateBudgetValidator.period(null), isNotNull);
    });

    testWidgets('accepts a non-null value', (tester) async {
      await loadTestLocale(tester);
      expect(CreateBudgetValidator.period('monthly'), isNull);
    });
  });

  group('optional fields', () {
    testWidgets('startDate and endDate are always valid', (tester) async {
      await loadTestLocale(tester);
      expect(CreateBudgetValidator.startDate(null), isNull);
      expect(CreateBudgetValidator.endDate(null), isNull);
    });
  });
}
