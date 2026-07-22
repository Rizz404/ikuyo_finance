import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/transaction/validators/bulk_copy_transaction_validator.dart';

import '../../../support/locale_test_helper.dart';

void main() {
  group('BulkCopyTransactionValidator.amount', () {
    testWidgets('rejects null', (tester) async {
      await loadTestLocale(tester);
      expect(BulkCopyTransactionValidator.amount(null), isNotNull);
    });

    testWidgets('rejects an empty string', (tester) async {
      await loadTestLocale(tester);
      expect(BulkCopyTransactionValidator.amount(''), isNotNull);
    });

    testWidgets('rejects a non-numeric value', (tester) async {
      await loadTestLocale(tester);
      expect(BulkCopyTransactionValidator.amount('abc'), isNotNull);
    });

    testWidgets('rejects zero or negative', (tester) async {
      await loadTestLocale(tester);
      expect(BulkCopyTransactionValidator.amount('0'), isNotNull);
      expect(BulkCopyTransactionValidator.amount('-5'), isNotNull);
    });

    testWidgets('accepts a positive amount', (tester) async {
      await loadTestLocale(tester);
      expect(BulkCopyTransactionValidator.amount('1000'), isNull);
    });

    testWidgets('strips "." thousands separators before parsing', (tester) async {
      await loadTestLocale(tester);
      expect(BulkCopyTransactionValidator.amount('2.500'), isNull);
    });
  });

  group('BulkCopyTransactionValidator.assetUlid', () {
    testWidgets('rejects null and empty', (tester) async {
      await loadTestLocale(tester);
      expect(BulkCopyTransactionValidator.assetUlid(null), isNotNull);
      expect(BulkCopyTransactionValidator.assetUlid(''), isNotNull);
    });

    testWidgets('accepts a non-empty ulid', (tester) async {
      await loadTestLocale(tester);
      expect(BulkCopyTransactionValidator.assetUlid('01ABCDEF'), isNull);
    });
  });

  group('BulkCopyTransactionValidator.description', () {
    testWidgets('allows null', (tester) async {
      await loadTestLocale(tester);
      expect(BulkCopyTransactionValidator.description(null), isNull);
    });

    testWidgets('accepts exactly 500 characters', (tester) async {
      await loadTestLocale(tester);
      expect(BulkCopyTransactionValidator.description('A' * 500), isNull);
    });

    testWidgets('rejects more than 500 characters', (tester) async {
      await loadTestLocale(tester);
      expect(BulkCopyTransactionValidator.description('A' * 501), isNotNull);
    });
  });

  group('optional fields', () {
    testWidgets('categoryUlid and transactionDate are always valid', (tester) async {
      await loadTestLocale(tester);
      expect(BulkCopyTransactionValidator.categoryUlid(null), isNull);
      expect(BulkCopyTransactionValidator.transactionDate(null), isNull);
    });
  });
}
