// Regression: AUTO-8 (no background execution for auto transactions).
// Real ObjectBox store on disk + real repositories; WorkManager is mocked at
// the platform-channel boundary and notifications are faked (OS boundary).
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/core/service/workmanager_dispatcher.dart';
import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/features/asset/models/asset.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_schedule_frequency.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_group.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_item.dart';
import 'package:ikuyo_finance/features/auto_transaction/services/auto_transaction_background_task.dart';
import 'package:ikuyo_finance/features/auto_transaction/services/auto_transaction_notification_service.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/transaction/models/transaction.dart';
// ignore: depend_on_referenced_packages
import 'package:workmanager_android/workmanager_android.dart';

import '../support/test_logger.dart';

class _FakeNotif extends Fake implements AutoTransactionNotificationService {
  int shown = 0;

  @override
  Future<void> initializeForBackground() async {}

  @override
  Future<void> showExecutionResult(
    AutoTransactionGroup g,
    int s,
    int f,
    int k,
  ) async => shown++;
}

const _wmPrefix =
    'dev.flutter.pigeon.workmanager_platform_interface.WorkmanagerHostApi.';

// * Top-level agar closure isolate tidak membawa Store milik UI
Future<(bool, int)> _runInWorker(String path) async {
  bootstrapTestLogger();
  final notif = _FakeNotif();
  final ok = await handleBackgroundTask(
    autoTransactionTaskName,
    storageDirectory: path,
    autoTxNotifService: notif,
  );
  return (ok, notif.shown);
}

Future<(bool, int)> _runIsolated(String path) =>
    Isolate.run(() => _runInWorker(path));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(bootstrapTestLogger);

  late Directory dir;
  late ObjectBoxStorage ui;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('ikuyo_auto_bg_');
    ui = ObjectBoxStorage();
    await ui.init(directory: dir.path);
  });
  tearDown(() {
    ui.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  void seedPendingGroup() {
    final asset = Asset(name: 'Cash', type: 0, balance: 1000);
    ui.box<Asset>().put(asset);
    final cat = Category(name: 'Food', type: CategoryType.expense.index);
    ui.box<Category>().put(cat);
    final template = Transaction(amount: 10, transactionDate: DateTime(2026))
      ..asset.target = asset
      ..category.target = cat;
    ui.box<Transaction>().put(template);
    final now = DateTime.now();
    final g = AutoTransactionGroup(
      name: 'G',
      frequency: AutoScheduleFrequency.daily.index,
      startDate: DateTime(2020),
      nextExecutedAt: DateTime(now.year, now.month, now.day),
    );
    ui.box<AutoTransactionGroup>().put(g);
    ui.box<AutoTransactionItem>().put(
      AutoTransactionItem()
        ..group.target = g
        ..transaction.target = template,
    );
  }

  test('the background task books pending ticks while the UI store is open',
      () async {
    seedPendingGroup();
    final path = dir.path;
    // * Callback WorkManager berjalan di isolate terpisah dari UI
    final (ok, shown) = await _runIsolated(path);
    expect(ok, isTrue);
    // * UI store melihat transaksi hasil isolate/background run
    expect(ui.box<Transaction>().count(), 2);
    expect(ui.box<Asset>().getAll().single.balance, 990);
    expect(shown, 1);
  });

  test('registering the periodic task uses WorkManager on Android', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    WorkmanagerAndroid.registerWith();
    messenger.setMockMessageHandler('${_wmPrefix}registerPeriodicTask', (
      msg,
    ) async {
      calls.add('wm.registerPeriodicTask');
      return const StandardMessageCodec().encodeMessage(<Object?>[]);
    });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMessageHandler('${_wmPrefix}registerPeriodicTask', null);
    });

    await AutoTransactionBackgroundTask.register();
    expect(calls, ['wm.registerPeriodicTask']);
  });
}
