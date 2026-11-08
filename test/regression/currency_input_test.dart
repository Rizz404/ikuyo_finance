// Regression: SHARED-1..4, AAOB-1/2, TX-1..3, A08, A16 (currency input).
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/core/currency/models/currency.dart';
import 'package:ikuyo_finance/core/currency/utils/currency_input.dart';
import 'package:ikuyo_finance/features/asset/validators/create_asset_validator.dart';
import 'package:ikuyo_finance/features/asset/validators/update_asset_validator.dart';
import 'package:ikuyo_finance/features/budget/validators/create_budget_validator.dart';
import 'package:ikuyo_finance/features/budget/validators/update_budget_validator.dart';
import 'package:ikuyo_finance/features/transaction/validators/bulk_copy_transaction_validator.dart';
import 'package:ikuyo_finance/features/transaction/validators/create_transaction_validator.dart';
import 'package:ikuyo_finance/features/transaction/validators/update_transaction_validator.dart';

final usd = Currency.currencies[CurrencyCode.usd]!;
final eur = Currency.currencies[CurrencyCode.eur]!;
final idr = Currency.currencies[CurrencyCode.idr]!;
final myr = Currency.currencies[CurrencyCode.myr]!;

void main() {
  group('CurrencyInput.parse uses the currency separators', () {
    test('USD', () {
      expect(CurrencyInput.parse('9.99', usd), 9.99);
      expect(CurrencyInput.parse('12.50', usd), 12.5);
      expect(CurrencyInput.parse('1,234.56', usd), 1234.56);
      expect(CurrencyInput.parse('1,234', usd), 1234);
    });

    test('EUR', () {
      expect(CurrencyInput.parse('12,50', eur), 12.5);
      expect(CurrencyInput.parse('1.234,50', eur), 1234.5);
    });

    test('IDR', () {
      expect(CurrencyInput.parse('1.000.000', idr), 1000000);
      expect(CurrencyInput.parse('75000', idr), 75000);
    });

    test('MYR uses its own (comma-thousand) format', () {
      expect(CurrencyInput.parse('1,234.50', myr), 1234.5);
    });

    test('rejects garbage', () {
      expect(CurrencyInput.parse('abc', usd), isNull);
      expect(CurrencyInput.parse('', usd), isNull);
      expect(CurrencyInput.parse(null, usd), isNull);
    });
  });

  group('CurrencyInput.formatAmount keeps the decimal part', () {
    test('round-trips through parse', () {
      for (final c in [usd, eur, idr, myr]) {
        for (final v in [9.99, 12.5, 1234.56, 1000000.0]) {
          final expected = double.parse(v.toStringAsFixed(c.decimalDigits));
          expect(
            CurrencyInput.parse(CurrencyInput.formatAmount(v, c), c),
            expected,
            reason: '${c.name} $v',
          );
        }
      }
    });

    test('display strings', () {
      expect(CurrencyInput.formatAmount(9.99, usd), '9.99');
      expect(CurrencyInput.formatAmount(1234.5, usd), '1,234.50');
      expect(CurrencyInput.formatAmount(12.5, eur), '12,50');
      expect(CurrencyInput.formatAmount(1000000, idr), '1.000.000');
    });
  });

  group('validators accept formatted amounts of the active currency', () {
    test('transaction amount', () {
      expect(CreateTransactionValidator.amount('1,234', usd), isNull);
      expect(CreateTransactionValidator.amount('12.50', usd), isNull);
      expect(CreateTransactionValidator.amount('12,50', eur), isNull);
      expect(CreateTransactionValidator.amount('1.000.000', idr), isNull);
      expect(UpdateTransactionValidator.amount('1,234.56', usd), isNull);
      expect(UpdateTransactionValidator.amount('12,50', eur), isNull);
      expect(BulkCopyTransactionValidator.amount('1,234.56', usd), isNull);
      expect(BulkCopyTransactionValidator.amount('12,50', eur), isNull);
    });

    test('asset balance (AAOB-2)', () {
      expect(CreateAssetValidator.balance('1.000.000', idr), isNull);
      expect(UpdateAssetValidator.balance('1.000.000', idr), isNull);
      expect(CreateAssetValidator.balance('1,234.56', usd), isNull);
      expect(UpdateAssetValidator.balance('1.234,56', eur), isNull);
    });

    test('budget limit', () {
      expect(CreateBudgetValidator.amountLimit('1.000.000', idr), isNull);
      expect(UpdateBudgetValidator.amountLimit('12.50', usd), isNull);
      expect(UpdateBudgetValidator.amountLimit('1,234.50', usd), isNull);
    });
  });
}
