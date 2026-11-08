// Regression: review F3 (verify-ikuyo-delivery-20261107T123306Z). Amounts
// are stored in the currency recorded by the ObjectBox CurrencyMarker (R03),
// but portable backups did not carry it: importing an IDR backup into a USD
// install kept the USD marker, so 1,680,000 IDR became 1,680,000 USD.
// Backups now record the stored base currency (code + minor-unit digits);
// import validates it before the destructive replace and writes the marker
// in the same ObjectBox write transaction as the data, via the existing
// CurrencyMigrationService. Backups without currency metadata are not
// reinterpreted in the target currency: the repository refuses them until
// the user explicitly declares the backup's currency.
// Real ObjectBox stores (reopened from disk to simulate an app restart),
// real BackupRepositoryImpl, CurrencyMigrationService and CurrencyCubit.
import 'dart:collection';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/core/currency/currency.dart';
import 'package:ikuyo_finance/core/currency/models/currency_marker.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/core/storage/storage_keys.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/backup/models/backup_data.dart';
import 'package:ikuyo_finance/features/backup/repositories/backup_repository_impl.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
import 'package:ikuyo_finance/objectbox.g.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_logger.dart';

class _Prefs implements SharedPreferences {
  final Map<String, Object> values;
  _Prefs(this.values);

  @override
  String? getString(String key) => values[key] as String?;

  @override
  Future<bool> setString(String key, String value) async {
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

class _FailOnSecondIteration<E> extends ListBase<E> {
  final List<E> _inner;
  int _iterations = 0;
  _FailOnSecondIteration(this._inner);

  @override
  int get length => _inner.length;
  @override
  set length(int v) => _inner.length = v;
  @override
  E operator [](int i) => _inner[i];
  @override
  void operator []=(int i, E v) => _inner[i] = v;
  @override
  Iterator<E> get iterator {
    _iterations++;
    if (_iterations >= 2) throw StateError('injected fault during import');
    return _inner.iterator;
  }
}

/// A store in a persistent temp dir that can be closed and reopened.
class _DiskStore {
  final Directory dir;
  late ObjectBoxStorage storage;
  _DiskStore._(this.dir);

  static Future<_DiskStore> open() async {
    final s = _DiskStore._(
      Directory.systemTemp.createTempSync('ikuyo_currency_backup_'),
    );
    await s._open();
    return s;
  }

  Future<void> _open() async {
    storage = ObjectBoxStorage.forTesting(await openStore(directory: dir.path));
  }

  Future<void> restart() async {
    storage.close();
    await _open();
  }

  void dispose() {
    storage.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}

void main() {
  setUpAll(bootstrapTestLogger);

  final stores = <_DiskStore>[];
  Future<_DiskStore> newStore() async {
    final s = await _DiskStore.open();
    stores.add(s);
    return s;
  }

  tearDown(() {
    for (final s in stores) {
      s.dispose();
    }
    stores.clear();
  });

  CurrencyMigrationService svc(_DiskStore s) =>
      CurrencyMigrationService(s.storage);

  CurrencyCubit cubitFor(_DiskStore s, _Prefs prefs) =>
      CurrencyCubit(prefs, svc(s), _OfflineRates());

  /// Seeds a linked category/asset/transaction/budget with [amounts] and
  /// marks the store as holding [currency].
  void seed(
    _DiskStore s,
    CurrencyCode currency, {
    required double balance,
    required double amount,
    required double limit,
    String prefix = 'src',
  }) {
    final c = Category(
      ulid: '$prefix-cat',
      name: '$prefix food',
      type: CategoryType.expense.index,
    );
    s.storage.box<Category>().put(c);
    final a = Asset(
      ulid: '$prefix-asset',
      name: '$prefix cash',
      type: 0,
      balance: balance,
    );
    s.storage.box<Asset>().put(a);
    final t =
        Transaction(
            ulid: '$prefix-tx',
            amount: amount,
            transactionDate: DateTime(2026, 2, 1),
          )
          ..type = CategoryType.expense.index
          ..asset.target = a
          ..category.target = c;
    s.storage.box<Transaction>().put(t);
    final b = Budget(ulid: '$prefix-budget', amountLimit: limit)
      ..category.target = c;
    s.storage.box<Budget>().put(b);
    svc(s).markStoredCurrency(currency);
  }

  ({double balance, double amount, double limit}) amounts(_DiskStore s) => (
    balance: s.storage.box<Asset>().getAll().single.balance,
    amount: s.storage.box<Transaction>().getAll().single.amount,
    limit: s.storage.box<Budget>().getAll().single.amountLimit,
  );

  Future<BackupData> exportViaJson(_DiskStore s) async {
    final data = (await BackupRepositoryImpl(
      s.storage,
    ).exportData().run()).getOrElse((f) => throw Exception(f.message)).data!;
    // * Lewat JSON seperti file sungguhan
    return BackupData.fromJsonString(data.toJsonString());
  }

  void expectIntact(_DiskStore s, CurrencyCode marker, double balance) {
    expect(svc(s).readMarker(), marker);
    expect(s.storage.box<CurrencyMarker>().count(), 1);
    expect(s.storage.box<Asset>().getAll().map((a) => a.ulid), ['dst-asset']);
    expect(amounts(s).balance, balance);
    expect(s.storage.box<Transaction>().count(), 1);
    expect(s.storage.box<Budget>().count(), 1);
  }

  test('export records the stored base currency marker and its minor-unit '
      'digits, not the display preference', () async {
    final s = await newStore();
    seed(s, CurrencyCode.idr, balance: 1680000, amount: 168000, limit: 336000);
    final data = await exportViaJson(s);
    expect(data.currency, isNotNull);
    expect(data.currency!.code, 'idr');
    expect(data.currency!.decimalDigits, 0);
    expect(data.currency!.currencyCode, CurrencyCode.idr);
    expect(data.toJson()['currency'], {'code': 'idr', 'decimalDigits': 0});

    final usd = await newStore();
    seed(usd, CurrencyCode.usd, balance: 1, amount: 1, limit: 1);
    expect((await exportViaJson(usd)).toJson()['currency'], {
      'code': 'usd',
      'decimalDigits': 2,
    });
  });

  test('importing an IDR backup over USD state keeps IDR amounts and '
      'interpretation, also after an app restart', () async {
    final src = await newStore();
    seed(
      src,
      CurrencyCode.idr,
      balance: 1680000,
      amount: 168000,
      limit: 336000,
    );
    final backup = await exportViaJson(src);

    final dst = await newStore();
    seed(
      dst,
      CurrencyCode.usd,
      balance: 100.5,
      amount: 10.25,
      limit: 20.75,
      prefix: 'dst',
    );
    final prefs = _Prefs({StorageKeys.currency: 'usd'});
    final before = cubitFor(dst, prefs);
    expect(before.state.currentCurrency, CurrencyCode.usd);

    final result = await BackupRepositoryImpl(
      dst.storage,
    ).importData(backup).run();
    expect(result.isRight(), isTrue, reason: '$result');
    expect(svc(dst).readMarker(), CurrencyCode.idr);

    // * Cache/prefs diselaraskan setelah commit
    await before.reloadFromStore();
    expect(before.state.currentCurrency, CurrencyCode.idr);
    expect(prefs.values[StorageKeys.currency], 'idr');
    await before.close();

    // * Restart penuh: store dibuka ulang, prefs basi masih "usd"
    await dst.restart();
    final stale = _Prefs({StorageKeys.currency: 'usd'});
    final restarted = cubitFor(dst, stale);
    expect(restarted.state.currentCurrency, CurrencyCode.idr);
    expect(amounts(dst), (
      balance: 1680000.0,
      amount: 168000.0,
      limit: 336000.0,
    ));
    expect(restarted.formatAmount(1680000), 'Rp 1.680.000');
    await restarted.close();
  });

  test('importing a USD backup over IDR state keeps USD amounts (with '
      'cents) and interpretation after restart', () async {
    final src = await newStore();
    seed(src, CurrencyCode.usd, balance: 100.25, amount: 10.5, limit: 20.75);
    final backup = await exportViaJson(src);

    final dst = await newStore();
    seed(
      dst,
      CurrencyCode.idr,
      balance: 1680000,
      amount: 168000,
      limit: 336000,
      prefix: 'dst',
    );
    final result = await BackupRepositoryImpl(
      dst.storage,
    ).importData(backup).run();
    expect(result.isRight(), isTrue, reason: '$result');

    await dst.restart();
    final restarted = cubitFor(dst, _Prefs({StorageKeys.currency: 'idr'}));
    expect(restarted.state.currentCurrency, CurrencyCode.usd);
    expect(svc(dst).readMarker(), CurrencyCode.usd);
    expect(amounts(dst), (balance: 100.25, amount: 10.5, limit: 20.75));
    await restarted.close();
  });

  test(
    'a failure during import rolls back BOTH the marker and the data',
    () async {
      final src = await newStore();
      seed(
        src,
        CurrencyCode.idr,
        balance: 1680000,
        amount: 168000,
        limit: 336000,
      );
      final backup = await exportViaJson(src);
      final faulty = BackupData(
        version: backup.version,
        createdAt: backup.createdAt,
        appName: backup.appName,
        currency: backup.currency,
        categories: backup.categories,
        assets: backup.assets,
        transactions: backup.transactions,
        budgets: backup.budgets,
        autoLogs: _FailOnSecondIteration(<AutoLogBackup>[]),
      );

      final dst = await newStore();
      seed(
        dst,
        CurrencyCode.usd,
        balance: 100.5,
        amount: 10.25,
        limit: 20.75,
        prefix: 'dst',
      );
      final result = await BackupRepositoryImpl(
        dst.storage,
      ).importData(faulty).run();
      expect(result.isLeft(), isTrue);
      expectIntact(dst, CurrencyCode.usd, 100.5);

      await dst.restart();
      expectIntact(dst, CurrencyCode.usd, 100.5);
    },
  );

  group('currency metadata is validated before the destructive replace', () {
    BackupData withMeta(BackupData b, BackupCurrency? c) => BackupData(
      version: b.version,
      createdAt: b.createdAt,
      appName: b.appName,
      currency: c,
      categories: b.categories,
      assets: b.assets,
      transactions: b.transactions,
      budgets: b.budgets,
    );

    final cases = <String, (BackupCurrency, String)>{
      'unknown currency code': (
        const BackupCurrency(code: 'xyz', decimalDigits: 2),
        LocaleKeys.backupScreenCurrencyUnsupported,
      ),
      'minor-unit digits disagree with the app (IDR as 2 digits)': (
        const BackupCurrency(code: 'idr', decimalDigits: 2),
        LocaleKeys.backupScreenCurrencyUnsupported,
      ),
      'negative digits': (
        const BackupCurrency(code: 'usd', decimalDigits: -1),
        LocaleKeys.backupScreenCurrencyUnsupported,
      ),
    };
    for (final entry in cases.entries) {
      test(entry.key, () async {
        final src = await newStore();
        seed(src, CurrencyCode.idr, balance: 5, amount: 1, limit: 2);
        final backup = withMeta(await exportViaJson(src), entry.value.$1);
        final dst = await newStore();
        seed(
          dst,
          CurrencyCode.usd,
          balance: 100.5,
          amount: 10.25,
          limit: 20.75,
          prefix: 'dst',
        );
        final result = await BackupRepositoryImpl(
          dst.storage,
        ).importData(backup).run();
        expect(result.isLeft(), isTrue);
        expect(
          result.getLeft().toNullable()!.message,
          contains(entry.value.$2.tr()),
        );
        expectIntact(dst, CurrencyCode.usd, 100.5);
      });
    }

    test('malformed currency metadata is not a valid backup', () {
      final json = BackupData(
        version: BackupData.currentVersion,
        createdAt: DateTime(2026, 2, 1),
        appName: 'Ikuyo Finance',
        categories: const [],
        assets: const [],
        transactions: const [],
        budgets: const [],
      ).toJson();
      for (final bad in <Object>[
        'idr',
        {'code': 1, 'decimalDigits': 0},
        {'code': 'idr'},
      ]) {
        expect(
          () => BackupData.fromJson({...json, 'currency': bad}),
          throwsA(anything),
          reason: '$bad',
        );
      }
    });
  });

  group('legacy backups without currency metadata', () {
    test('are rejected before any mutation instead of being reinterpreted '
        'in the target currency', () async {
      final src = await newStore();
      seed(
        src,
        CurrencyCode.idr,
        balance: 1680000,
        amount: 168000,
        limit: 336000,
      );
      final exported = await exportViaJson(src);
      final legacyJson = exported.toJson()
        ..remove('currency')
        ..['version'] = '1.0.0';
      final legacy = BackupData.fromJson(legacyJson);
      expect(legacy.currency, isNull);

      final dst = await newStore();
      seed(
        dst,
        CurrencyCode.usd,
        balance: 100.5,
        amount: 10.25,
        limit: 20.75,
        prefix: 'dst',
      );
      final result = await BackupRepositoryImpl(
        dst.storage,
      ).importData(legacy).run();
      expect(result.isLeft(), isTrue);
      expect(
        result.getLeft().toNullable()!.message,
        contains(LocaleKeys.backupScreenCurrencyMissing.tr()),
      );
      expectIntact(dst, CurrencyCode.usd, 100.5);
    });

    test('import when the user explicitly declares the backup currency; '
        'amounts are kept and the marker follows the declaration', () async {
      final src = await newStore();
      seed(
        src,
        CurrencyCode.idr,
        balance: 1680000,
        amount: 168000,
        limit: 336000,
      );
      final exported = await exportViaJson(src);
      final legacy = BackupData.fromJson(exported.toJson()..remove('currency'));

      final dst = await newStore();
      seed(
        dst,
        CurrencyCode.usd,
        balance: 100.5,
        amount: 10.25,
        limit: 20.75,
        prefix: 'dst',
      );
      final declared = legacy.withCurrency(BackupCurrency.of(CurrencyCode.idr));
      final result = await BackupRepositoryImpl(
        dst.storage,
      ).importData(declared).run();
      expect(result.isRight(), isTrue, reason: '$result');
      await dst.restart();
      expect(svc(dst).readMarker(), CurrencyCode.idr);
      expect(amounts(dst), (
        balance: 1680000.0,
        amount: 168000.0,
        limit: 336000.0,
      ));
    });

    test('a store without a marker exports no currency (never guessed) and '
        'that file needs an explicit declaration to import', () async {
      final src = await newStore();
      src.storage.box<Asset>().put(
        Asset(ulid: 'x', name: 'x', type: 0, balance: 7),
      );
      final data = await exportViaJson(src);
      expect(data.currency, isNull);
      expect(data.toJson().containsKey('currency'), isFalse);
      final dst = await newStore();
      seed(
        dst,
        CurrencyCode.usd,
        balance: 100.5,
        amount: 10.25,
        limit: 20.75,
        prefix: 'dst',
      );
      expect(
        (await BackupRepositoryImpl(
          dst.storage,
        ).importData(data).run()).isLeft(),
        isTrue,
      );
      expectIntact(dst, CurrencyCode.usd, 100.5);
    });
  });
}
