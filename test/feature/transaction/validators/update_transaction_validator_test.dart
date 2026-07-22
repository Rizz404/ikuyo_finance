import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/transaction/validators/update_transaction_validator.dart';

import '../../../support/locale_test_helper.dart';

void main() {
  group('UpdateTransactionValidator.ulid', () {
    testWidgets('rejects null and empty', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateTransactionValidator.ulid(null), isNotNull);
      expect(UpdateTransactionValidator.ulid(''), isNotNull);
    });

    testWidgets('accepts a non-empty ulid', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateTransactionValidator.ulid('01ABCDEF'), isNull);
    });
  });

  group('UpdateTransactionValidator.amount', () {
    testWidgets('null/empty is allowed (optional on update)', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateTransactionValidator.amount(null), isNull);
      expect(UpdateTransactionValidator.amount(''), isNull);
    });

    testWidgets('rejects a non-numeric value when provided', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateTransactionValidator.amount('abc'), isNotNull);
    });

    testWidgets('rejects zero or negative when provided', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateTransactionValidator.amount('0'), isNotNull);
      expect(UpdateTransactionValidator.amount('-10'), isNotNull);
    });

    testWidgets('accepts a valid positive amount', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateTransactionValidator.amount('1000'), isNull);
    });
  });

  group('UpdateTransactionValidator.description', () {
    testWidgets('allows null', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateTransactionValidator.description(null), isNull);
    });

    testWidgets('accepts exactly 500 characters', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateTransactionValidator.description('A' * 500), isNull);
    });

    testWidgets('rejects more than 500 characters', (tester) async {
      await loadTestLocale(tester);
      expect(UpdateTransactionValidator.description('A' * 501), isNotNull);
    });
  });

  group('optional fields on update', () {
    testWidgets('assetUlid, categoryUlid, transactionDate and imagePath never produce an error', (
      tester,
    ) async {
      await loadTestLocale(tester);
      expect(UpdateTransactionValidator.assetUlid(null), isNull);
      expect(UpdateTransactionValidator.categoryUlid(null), isNull);
      expect(UpdateTransactionValidator.transactionDate(null), isNull);
      expect(UpdateTransactionValidator.imagePath(null), isNull);
    });
  });
}
