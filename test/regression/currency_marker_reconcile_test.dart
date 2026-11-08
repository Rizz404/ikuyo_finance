// Regression: R03 (currency preference is written outside the ObjectBox
// migration transaction; a prefs failure or restart after a committed
// conversion lets a retry convert the same amounts twice). Real ObjectBox
// store, real CurrencyCubit and CurrencyMigrationService. Only the platform
// preference store is faked so its write can fail like a disk/OS error.
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/core/currency/currency.dart';
import 'package:ikuyo_finance/core/storage/storage_keys.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/objectbox_test_store.dart';
import '../support/test_logger.dart';

class _Prefs implements SharedPreferences {
  final Map<String, Object> values;
  bool failWrites = false;
  _Prefs(this.values);

  @override
  String? getString(String key) => values[key] as String?;

  @override
  Future<bool> setString(String key, String value) async {
    if (failWrites) throw StateError('simulated preference write failure');
    values[key] = value;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OfflineRates implements ExchangeRateService {
  @override
  Future<Map<CurrencyCode, double>> fetchRates() async => const {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(bootstrapTestLogger);

  late ObjectBoxTestStore store;
  setUp(() async => store = await ObjectBoxTestStore.open());
  tearDown(() => store.close());

  CurrencyCubit cubitFor(SharedPreferences prefs) => CurrencyCubit(
    prefs,
    CurrencyMigrationService(store.storage),
    _OfflineRates(),
  );

  double conv(double v, CurrencyCode from, CurrencyCode to) {
    final value = CurrencyConverter.convert(
      amount: v,
      from: Currency.getByCode(from),
      to: Currency.getByCode(to),
    );
    final digits = Currency.getByCode(to).decimalDigits;
    var mod = 1.0;
    for (var i = 0; i < digits; i++) {
      mod *= 10;
    }
    return (value * mod).roundToDouble() / mod;
  }

  ({int asset, int tx, int budget}) seed() {
    final a = Asset(name: 'A', type: 0, balance: 1680000);
    store.storage.box<Asset>().put(a);
    final t = Transaction(amount: 168000)..asset.target = a;
    store.storage.box<Transaction>().put(t);
    final b = Budget(amountLimit: 336000);
    store.storage.box<Budget>().put(b);
    return (asset: a.id, tx: t.id, budget: b.id);
  }

  test('a preference write failure after a committed conversion does not '
      'let a retry or a restart convert twice', () async {
    final ids = seed();
    final prefs = _Prefs({StorageKeys.currency: 'idr'})..failWrites = true;

    final cubit = cubitFor(prefs);
    await cubit.setCurrency(CurrencyCode.usd);
    // * Retry di sesi yang sama (pengguna menekan lagi setelah error)
    await cubit.setCurrency(CurrencyCode.usd);
    await cubit.close();

    // * Restart: prefs masih "idr" karena tulisannya gagal
    final restarted = cubitFor(prefs);
    expect(restarted.state.currentCurrency, CurrencyCode.usd);
    await restarted.setCurrency(CurrencyCode.usd);
    await restarted.close();

    final usdBalance = conv(1680000, CurrencyCode.idr, CurrencyCode.usd);
    expect(store.storage.box<Asset>().get(ids.asset)!.balance, usdBalance);
    expect(
      store.storage.box<Transaction>().get(ids.tx)!.amount,
      conv(168000, CurrencyCode.idr, CurrencyCode.usd),
    );
    expect(
      store.storage.box<Budget>().get(ids.budget)!.amountLimit,
      conv(336000, CurrencyCode.idr, CurrencyCode.usd),
    );

    // * Begitu prefs pulih, startup menyelaraskannya dari penanda DB
    prefs.failWrites = false;
    final healed = cubitFor(prefs);
    await pumpEventQueue();
    expect(prefs.getString(StorageKeys.currency), 'usd');
    await healed.close();
  });

  test('legacy install without a DB marker adopts the stored preference and '
      'converts exactly once', () async {
    final ids = seed();
    final prefs = _Prefs({StorageKeys.currency: 'usd'});

    final cubit = cubitFor(prefs);
    expect(cubit.state.currentCurrency, CurrencyCode.usd);
    prefs.failWrites = true;
    final result = await cubit.setCurrency(CurrencyCode.eur);
    expect(result.success, isTrue);
    expect(cubit.state.currentCurrency, CurrencyCode.eur);
    await cubit.close();

    final restarted = cubitFor(prefs);
    expect(restarted.state.currentCurrency, CurrencyCode.eur);
    await restarted.close();
    expect(
      store.storage.box<Asset>().get(ids.asset)!.balance,
      conv(1680000, CurrencyCode.usd, CurrencyCode.eur),
    );
  });

  test('a migration whose source does not match the DB marker is refused '
      'and leaves amounts untouched', () async {
    final ids = seed();
    final prefs = _Prefs({StorageKeys.currency: 'idr'});
    final cubit = cubitFor(prefs);
    await cubit.setCurrency(CurrencyCode.usd);
    await cubit.close();
    final balance = store.storage.box<Asset>().get(ids.asset)!.balance;

    final svc = CurrencyMigrationService(store.storage);
    final stale = await svc.migrateAllData(
      fromCurrency: CurrencyCode.idr,
      toCurrency: CurrencyCode.usd,
    );
    expect(stale.success, isFalse);
    expect(store.storage.box<Asset>().get(ids.asset)!.balance, balance);
  });
}
