// Regression: F5 (apps-final-residual-closure-20261114T033928Z). Backup
// import decoded/parsed the file and ran the whole destructive replace on the
// UI isolate, so a large backup froze the app (ANR risk). Parsing now runs in
// an Isolate.run worker and the write runs through
// Store.runInTransactionAsync: still ONE write transaction (atomic rollback),
// validation stays on the caller before anything is deleted.
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/core/currency/currency.dart';
import 'package:ikuyo_finance/core/currency/models/currency_marker.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_item.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_log.dart';
import 'package:ikuyo_finance/features/backup/models/backup_data.dart';
import 'package:ikuyo_finance/features/backup/repositories/backup_repository_impl.dart';
import 'package:ikuyo_finance/features/backup/services/backup_crypto.dart';
import 'package:ikuyo_finance/features/budget/models/budget.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';

import '../support/objectbox_test_store.dart';
import '../support/test_logger.dart';

// * Static = per isolate: true only on the test (UI) isolate; a spawned
// *   worker isolate sees the initial value false
bool _onTestIsolate = false;

/// Behaves like a normal list on the test isolate (so validation passes) but
/// throws as soon as it is iterated on any other isolate.
class _FailOffTestIsolate<E> extends ListBase<E> {
  final List<E> _inner;
  _FailOffTestIsolate(this._inner);

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
    if (!_onTestIsolate) {
      throw StateError('injected fault in import worker isolate');
    }
    return _inner.iterator;
  }
}

void main() {
  setUpAll(() {
    bootstrapTestLogger();
    _onTestIsolate = true;
  });

  final now = DateTime(2026, 2, 1);

  group('importData runs its write transaction off the UI isolate', () {
    late ObjectBoxTestStore store;
    late BackupRepositoryImpl repo;

    setUp(() async {
      store = await ObjectBoxTestStore.open();
      repo = BackupRepositoryImpl(store.storage);
      final c = Category(ulid: 'live-c', name: 'Live', type: 1);
      store.storage.box<Category>().put(c);
      final a = Asset(ulid: 'live-a', name: 'Cash', type: 0, balance: 480);
      store.storage.box<Asset>().put(a);
      store.storage.box<Transaction>().put(
        Transaction(ulid: 'live-t', amount: 20, transactionDate: now)
          ..type = 1
          ..asset.target = a
          ..category.target = c,
      );
      CurrencyMigrationService(store.storage).markStoredCurrency(
        CurrencyCode.usd,
      );
    });
    tearDown(() => store.close());

    void expectLiveIntact() {
      expect(store.storage.box<Category>().getAll().map((c) => c.ulid), [
        'live-c',
      ]);
      expect(store.storage.box<Asset>().getAll().single.balance, 480);
      expect(store.storage.box<Transaction>().getAll().single.ulid, 'live-t');
      expect(store.storage.box<Budget>().count(), 0);
      expect(store.storage.box<AutoTransactionLog>().count(), 0);
      expect(
        CurrencyMigrationService(store.storage).readMarker(),
        CurrencyCode.usd,
      );
      expect(store.storage.box<CurrencyMarker>().count(), 1);
    }

    AutoGroupBackup group() => AutoGroupBackup(
      ulid: 'g1',
      name: 'G',
      isActive: true,
      isPaused: false,
      frequency: 0,
      scheduleHour: 8,
      scheduleMinute: 0,
      intervalDays: 1,
      activeDaysMask: 127,
      startDate: now,
      createdAt: now,
      updatedAt: now,
    );

    BackupData snapshot({List<AutoLogBackup>? autoLogs}) => BackupData(
      version: BackupData.currentVersion,
      createdAt: now,
      appName: 'Ikuyo Finance',
      currency: BackupCurrency.of(CurrencyCode.idr),
      categories: [
        CategoryBackup(
          ulid: 'p1',
          name: 'Parent',
          type: 1,
          createdAt: now,
          updatedAt: now,
        ),
        CategoryBackup(
          ulid: 'c1',
          parentUlid: 'p1',
          name: 'Child',
          type: 1,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      assets: [
        AssetBackup(
          ulid: 'a1',
          name: 'Bank',
          type: 1,
          balance: 1680000,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      transactions: [
        TransactionBackup(
          ulid: 't1',
          assetUlid: 'a1',
          categoryUlid: 'c1',
          type: 1,
          amount: 168000,
          transactionDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      budgets: [
        BudgetBackup(
          ulid: 'b1',
          categoryUlid: 'c1',
          amountLimit: 336000,
          period: 0,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      autoGroups: [group()],
      autoItems: [
        AutoItemBackup(
          ulid: 'i1',
          groupUlid: 'g1',
          transactionUlid: 't1',
          isActive: true,
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      autoLogs:
          autoLogs ??
          [
            AutoLogBackup(
              ulid: 'l1',
              groupUlid: 'g1',
              scheduledAt: now,
              executedAt: now,
              status: 0,
              successCount: 1,
              failureCount: 0,
              createdAt: now,
              updatedAt: now,
            ),
          ],
    );

    test('a fault raised on the worker isolate (after the deletes and earlier '
        'puts) rolls back every row and the currency marker', () async {
      final result = await repo
          .importData(
            snapshot(
              autoLogs: _FailOffTestIsolate([
                AutoLogBackup(
                  ulid: 'l1',
                  groupUlid: 'g1',
                  scheduledAt: now,
                  executedAt: now,
                  status: 0,
                  successCount: 1,
                  failureCount: 0,
                  createdAt: now,
                  updatedAt: now,
                ),
              ]),
            ),
          )
          .run();
      expect(result.isLeft(), isTrue, reason: '$result');
      expect(
        result.getLeft().toNullable()!.message,
        contains('injected fault in import worker isolate'),
      );
      expectLiveIntact();
    });

    test('the replace is not performed synchronously on the calling isolate; '
        'it commits after the worker completes', () async {
      final pending = repo.importData(snapshot()).run();
      // * Nothing written yet: the caller only validated and scheduled
      expectLiveIntact();
      final result = await pending;
      expect(result.isRight(), isTrue, reason: '$result');
      expect(store.storage.box<Asset>().getAll().single.ulid, 'a1');
      expect(
        CurrencyMigrationService(store.storage).readMarker(),
        CurrencyCode.idr,
      );
    });

    test('a worker import restores every relation and leaves the shared '
        'store open and usable for a second import', () async {
      for (var round = 0; round < 2; round++) {
        final result = await repo.importData(snapshot()).run();
        expect(result.isRight(), isTrue, reason: '$result');
        final t = store.storage.box<Transaction>().getAll().single;
        expect(t.ulid, 't1');
        expect(t.amount, 168000);
        expect(t.asset.target!.ulid, 'a1');
        expect(t.category.target!.ulid, 'c1');
        final c = store.storage.box<Category>().getAll().firstWhere(
          (c) => c.ulid == 'c1',
        );
        expect(c.parent.target!.ulid, 'p1');
        expect(
          store.storage.box<Budget>().getAll().single.category.target!.ulid,
          'c1',
        );
        final item = store.storage.box<AutoTransactionItem>().getAll().single;
        expect(item.group.target!.ulid, 'g1');
        expect(item.transaction.target!.ulid, 't1');
        expect(
          store.storage
              .box<AutoTransactionLog>()
              .getAll()
              .single
              .group
              .target!
              .ulid,
          'g1',
        );
        expect(store.storage.box<CurrencyMarker>().count(), 1);
        expect(
          CurrencyMigrationService(store.storage).readMarker(),
          CurrencyCode.idr,
        );
      }
      // * Store utama tetap terbuka setelah worker menutup store miliknya
      store.storage.box<Category>().put(
        Category(ulid: 'after', name: 'After', type: 0),
      );
      expect(store.storage.box<Category>().count(), 3);
    });

    test('duplicate ulids and unsupported currency are still rejected on the '
        'caller before any write', () async {
      final dup = snapshot();
      final duplicated = BackupData(
        version: dup.version,
        createdAt: dup.createdAt,
        appName: dup.appName,
        currency: dup.currency,
        categories: dup.categories,
        assets: [...dup.assets, ...dup.assets],
        transactions: dup.transactions,
        budgets: dup.budgets,
      );
      expect((await repo.importData(duplicated).run()).isLeft(), isTrue);
      expectLiveIntact();

      final unsupported = snapshot().withCurrency(
        const BackupCurrency(code: 'idr', decimalDigits: 2),
      );
      final r = await repo.importData(unsupported).run();
      expect(r.isLeft(), isTrue);
      expectLiveIntact();
    });
  });

  group('decodeBackup parses off the UI isolate', () {
    BackupData big() => BackupData(
      version: BackupData.currentVersion,
      createdAt: now,
      appName: 'Ikuyo Finance',
      currency: BackupCurrency.of(CurrencyCode.idr),
      categories: [
        for (var i = 0; i < 80000; i++)
          CategoryBackup(
            ulid: 'c$i',
            name: 'Category number $i with some padding text',
            type: i % 2,
            icon: 'icon_$i',
            color: '#FF00${i % 10}0FF',
            createdAt: now,
            updatedAt: now,
          ),
      ],
      assets: const [],
      transactions: const [],
      budgets: const [],
    );

    test('a ~20 MiB legacy backup: the synchronous part of decodeBackup is '
        'tiny and the calling isolate keeps ticking while it parses', () async {
      final bytes = Uint8List.fromList(utf8.encode(big().toJsonString()));
      expect(bytes.length, greaterThan(16 * 1024 * 1024));
      expect(bytes.length, lessThan(BackupCrypto.maxBackupBytes));

      // * Baseline: the same decode + parse done on this isolate
      final inline = Stopwatch()..start();
      BackupData.fromJsonString(utf8.decode(bytes));
      inline.stop();

      var ticks = 0;
      final timer = Timer.periodic(
        const Duration(milliseconds: 1),
        (_) => ticks++,
      );
      final sync = Stopwatch()..start();
      final pending = BackupCrypto.decodeBackup(bytes);
      sync.stop();
      final decoded = await pending;
      timer.cancel();

      expect(decoded.wasEncrypted, isFalse);
      expect(decoded.data.categories.length, 80000);
      expect(decoded.data.categories.last.ulid, 'c79999');
      expect(
        sync.elapsedMicroseconds,
        lessThan(inline.elapsedMicroseconds ~/ 4),
        reason: 'sync ${sync.elapsed} vs inline parse ${inline.elapsed}',
      );
      expect(ticks, greaterThan(0));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('worker errors keep the public error contract (notABackup)', () async {
      Future<BackupCryptoError?> errorOf(List<int> b) async {
        try {
          await BackupCrypto.decodeBackup(b);
          return null;
        } on BackupCryptoException catch (e) {
          return e.error;
        }
      }

      // * JSON valid tetapi bukan BackupData, JSON terpotong, UTF-8 rusak
      expect(await errorOf(utf8.encode('{"x":1}')), BackupCryptoError.notABackup);
      expect(
        await errorOf(utf8.encode('{"version":"2.0.0",')),
        BackupCryptoError.notABackup,
      );
      expect(
        await errorOf([0x7B, 0xFF, 0xFE, 0x7D]),
        BackupCryptoError.notABackup,
      );
      // * BOM masih diterima
      final ok = [0xEF, 0xBB, 0xBF, ...utf8.encode(big().toJsonString())];
      expect((await BackupCrypto.decodeBackup(ok)).data.categories.length, 80000);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
