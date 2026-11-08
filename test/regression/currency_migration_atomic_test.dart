// Regression: CORE-5 / A09 (non-atomic currency migration; retry after a
// partial failure double-converts). The A09 round-trip rounding loss is
// expected precision loss and is not asserted here. Real ObjectBox store.
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/core/currency/currency.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';

import '../support/objectbox_test_store.dart';
import '../support/test_logger.dart';

void main() {
  setUpAll(bootstrapTestLogger);

  late ObjectBoxTestStore store;
  setUp(() async => store = await ObjectBoxTestStore.open());
  tearDown(() => store.close());

  test('a failure mid-migration leaves every record unchanged and a retry '
      'converts exactly once', () async {
    final a = Asset(name: 'A', type: 0, balance: 168000);
    store.storage.box<Asset>().put(a);
    final t = Transaction(amount: 16800)..asset.target = a;
    store.storage.box<Transaction>().put(t);
    final b = Budget(amountLimit: 33600);
    store.storage.box<Budget>().put(b);

    final svc = CurrencyMigrationService(store.storage);
    final failed = await svc.migrateAllData(
      fromCurrency: CurrencyCode.idr,
      toCurrency: CurrencyCode.usd,
      onProgress: (status, progress) {
        // * Simulasi crash/exception setelah aset dikonversi dan tersimpan
        if (status.startsWith('Migrating transaction ')) {
          throw StateError('simulated failure while migrating transactions');
        }
      },
    );
    expect(failed.success, isFalse);
    expect(store.storage.box<Asset>().get(a.id)!.balance, 168000);
    expect(store.storage.box<Transaction>().get(t.id)!.amount, 16800);
    expect(store.storage.box<Budget>().get(b.id)!.amountLimit, 33600);

    final retry = await svc.migrateAllData(
      fromCurrency: CurrencyCode.idr,
      toCurrency: CurrencyCode.usd,
    );
    expect(retry.success, isTrue);
    final idr = Currency.getByCode(CurrencyCode.idr);
    final usd = Currency.getByCode(CurrencyCode.usd);
    double conv(double v) => CurrencyConverter.convert(
      amount: v,
      from: idr,
      to: usd,
    );
    expect(
      store.storage.box<Asset>().get(a.id)!.balance,
      closeTo(conv(168000), 0.006),
    );
    expect(
      store.storage.box<Transaction>().get(t.id)!.amount,
      closeTo(conv(16800), 0.006),
    );
    expect(
      store.storage.box<Budget>().get(b.id)!.amountLimit,
      closeTo(conv(33600), 0.006),
    );
  });
}
