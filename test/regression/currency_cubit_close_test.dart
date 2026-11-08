// Regression: R04 / A15 (CurrencyCubit.refreshExchangeRates emits after
// close when the rate fetch settles late). Only the network boundary
// (ExchangeRateService.fetchRates) is stubbed; the migration service runs
// against a real ObjectBox store.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/core/currency/currency.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/objectbox_test_store.dart';
import '../support/test_logger.dart';

class _DeferredRates implements ExchangeRateService {
  final completer = Completer<Map<CurrencyCode, double>>();

  @override
  Future<Map<CurrencyCode, double>> fetchRates() => completer.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(bootstrapTestLogger);

  late ObjectBoxTestStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await ObjectBoxTestStore.open();
  });
  tearDown(() => store.close());

  Future<void> runCase(void Function(_DeferredRates rates) settle) async {
    final prefs = await SharedPreferences.getInstance();
    final errors = <Object>[];
    await runZonedGuarded(() async {
      // * Dibuat di dalam zone agar error future tidak melintasi batas zone
      final rates = _DeferredRates();
      final cubit = CurrencyCubit(
        prefs,
        CurrencyMigrationService(store.storage),
        rates,
      );
      await cubit.close();
      settle(rates);
      await pumpEventQueue();
    }, (e, _) => errors.add(e));
    expect(errors, isEmpty);
  }

  test('a rate fetch that succeeds after close does not emit', () async {
    await runCase((r) => r.completer.complete(const {}));
  });

  test('a rate fetch that fails after close does not emit', () async {
    await runCase((r) => r.completer.completeError(Exception('offline')));
  });
}
