// Regression: P04. Release builds must not print logs (financial data) to the
// console; debug builds keep console logging.
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';

void main() {
  test('release disables console logs, debug keeps them', () {
    expect(loggerSettings(release: true).useConsoleLogs, isFalse);
    expect(loggerSettings(release: false).useConsoleLogs, isTrue);
  });
}
