import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/auto_transaction/validators/create_auto_item_validator.dart';

import '../../../support/locale_test_helper.dart';

void main() {
  group('CreateAutoItemValidator.transactionUlid', () {
    testWidgets('rejects null', (tester) async {
      await loadTestLocale(tester);
      expect(CreateAutoItemValidator.transactionUlid(null), isNotNull);
    });

    testWidgets('rejects an empty string', (tester) async {
      await loadTestLocale(tester);
      expect(CreateAutoItemValidator.transactionUlid(''), isNotNull);
    });

    testWidgets('rejects a whitespace-only string', (tester) async {
      await loadTestLocale(tester);
      expect(CreateAutoItemValidator.transactionUlid('   '), isNotNull);
    });

    testWidgets('accepts a non-empty ulid', (tester) async {
      await loadTestLocale(tester);
      expect(CreateAutoItemValidator.transactionUlid('01ABCDEF'), isNull);
    });
  });
}
