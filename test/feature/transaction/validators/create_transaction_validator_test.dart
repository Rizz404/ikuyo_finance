import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/transaction/validators/create_transaction_validator.dart';

import '../../../support/locale_test_helper.dart';

void main() {
  group('CreateTransactionValidator.amount', () {
    testWidgets('rejects null', (tester) async {
      await loadTestLocale(tester);
      expect(CreateTransactionValidator.amount(null), isNotNull);
    });

    testWidgets('rejects an empty string', (tester) async {
      await loadTestLocale(tester);
      expect(CreateTransactionValidator.amount(''), isNotNull);
    });

    testWidgets('rejects a non-numeric value', (tester) async {
      await loadTestLocale(tester);
      expect(CreateTransactionValidator.amount('abc'), isNotNull);
    });

    testWidgets('rejects zero', (tester) async {
      await loadTestLocale(tester);
      expect(CreateTransactionValidator.amount('0'), isNotNull);
    });

    testWidgets('rejects a negative amount', (tester) async {
      await loadTestLocale(tester);
      expect(CreateTransactionValidator.amount('-50'), isNotNull);
    });

    testWidgets('accepts a positive amount', (tester) async {
      await loadTestLocale(tester);
      expect(CreateTransactionValidator.amount('50000'), isNull);
    });

    testWidgets('strips "." thousands separators before parsing', (tester) async {
      await loadTestLocale(tester);
      // * "1.000.000" -> "1000000" after stripping dots -> valid positive amount
      expect(CreateTransactionValidator.amount('1.000.000'), isNull);
    });
  });

  group('CreateTransactionValidator.assetUlid', () {
    testWidgets('rejects null', (tester) async {
      await loadTestLocale(tester);
      expect(CreateTransactionValidator.assetUlid(null), isNotNull);
    });

    testWidgets('rejects an empty string', (tester) async {
      await loadTestLocale(tester);
      expect(CreateTransactionValidator.assetUlid(''), isNotNull);
    });

    testWidgets('accepts a non-empty ulid', (tester) async {
      await loadTestLocale(tester);
      expect(CreateTransactionValidator.assetUlid('01ABCDEF'), isNull);
    });
  });

  group('CreateTransactionValidator.description', () {
    testWidgets('allows null', (tester) async {
      await loadTestLocale(tester);
      expect(CreateTransactionValidator.description(null), isNull);
    });

    testWidgets('accepts exactly 500 characters', (tester) async {
      await loadTestLocale(tester);
      expect(CreateTransactionValidator.description('A' * 500), isNull);
    });

    testWidgets('rejects more than 500 characters', (tester) async {
      await loadTestLocale(tester);
      expect(CreateTransactionValidator.description('A' * 501), isNotNull);
    });
  });

  group('optional fields', () {
    testWidgets('categoryUlid, transactionDate and imagePath are always valid', (tester) async {
      await loadTestLocale(tester);
      expect(CreateTransactionValidator.categoryUlid(null), isNull);
      expect(CreateTransactionValidator.transactionDate(null), isNull);
      expect(CreateTransactionValidator.imagePath(null), isNull);
    });
  });
}
