// Regression: review NEW-1 (review-ikuyo-final-slices-20261107T173810Z).
// The scheduled auto backup wrote its JSON with no size bound, so it could
// produce a file the importer refuses (BackupCrypto.maxBackupBytes, 32 MiB).
// The JSON is now encoded once as UTF-8 and its byte length (not its
// character count) is checked before the directory or file is touched. A
// refused backup writes nothing, returns no path (runBackup reports false)
// and does not prune: every earlier good backup stays as it was.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/backup/models/backup_data.dart';
import 'package:ikuyo_finance/features/backup/services/auto_backup_service.dart';
import 'package:ikuyo_finance/features/backup/services/backup_crypto.dart';

import '../support/test_logger.dart';

const _max = BackupCrypto.maxBackupBytes;
final _when = DateTime(2026, 2, 1, 2, 0, 0);

BackupData _data({String name = 'Food'}) {
  final now = DateTime(2026, 2, 1);
  return BackupData(
    version: BackupData.currentVersion,
    createdAt: now,
    appName: 'Ikuyo Finance',
    categories: [
      CategoryBackup(
        ulid: 'c1',
        name: name,
        type: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    assets: const [],
    transactions: const [],
    budgets: const [],
  );
}

/// Backup whose UTF-8 JSON is exactly [bytes] long; [unit] is a multi-byte
/// character so the character count stays well below the byte count.
BackupData _dataOfUtf8Length(int bytes, {String unit = 'é'}) {
  final base = utf8.encode(_data(name: '').toJsonString()).length;
  final unitBytes = utf8.encode(unit).length;
  final extra = bytes - base;
  final name = unit * (extra ~/ unitBytes) + 'a' * (extra % unitBytes);
  final data = _data(name: name);
  expect(utf8.encode(data.toJsonString()).length, bytes);
  expect(data.toJsonString().length, lessThan(bytes));
  return data;
}

/// Twelve earlier good backups (more than the rotation keeps).
Map<String, String> _seedOldBackups(Directory dir) {
  final seeded = <String, String>{};
  for (var i = 1; i <= 12; i++) {
    final d = i.toString().padLeft(2, '0');
    final name = 'ikuyo_backup_202601${d}_020000.json';
    final body = '{"seed":$i}';
    File('${dir.path}/$name').writeAsStringSync(body);
    seeded[name] = body;
  }
  return seeded;
}

Map<String, String> _contents(Directory dir) => {
  for (final f in dir.listSync().whereType<File>())
    f.uri.pathSegments.last: f.readAsStringSync(),
};

void main() {
  setUpAll(bootstrapTestLogger);

  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('ikuyo_autobk_'));
  tearDown(() => root.deleteSync(recursive: true));

  test('NEW-1 a backup of exactly the limit (UTF-8 bytes) is written and '
      'rotation still runs', () async {
    final dir = Directory('${root.path}/Auto Backup')..createSync();
    _seedOldBackups(dir);

    final path = await AutoBackupService.writeBackupFile(
      dir,
      _dataOfUtf8Length(_max),
      now: _when,
    );

    expect(path, isNotNull);
    expect(File(path!).lengthSync(), _max);
    expect(
      BackupData.fromJsonString(
        File(path).readAsStringSync(),
      ).categories.single.name,
      startsWith('é'),
    );
    expect(dir.listSync().whereType<File>(), hasLength(10));
  });

  test('NEW-1 one byte over the limit is refused: nothing written, no '
      'pruning, every earlier backup unchanged', () async {
    final dir = Directory('${root.path}/Auto Backup')..createSync();
    final seeded = _seedOldBackups(dir);

    final path = await AutoBackupService.writeBackupFile(
      dir,
      _dataOfUtf8Length(_max + 1),
      now: _when,
    );

    expect(path, isNull);
    expect(_contents(dir), seeded);
  });

  test('NEW-1 four-byte Unicode over the limit is refused although its '
      'character count is far below it', () async {
    final dir = Directory('${root.path}/Auto Backup')..createSync();
    final seeded = _seedOldBackups(dir);
    final data = _dataOfUtf8Length(_max + 4, unit: '\u{1F600}');
    expect(data.toJsonString().length, lessThan(_max ~/ 2 + 1024));

    final path = await AutoBackupService.writeBackupFile(dir, data, now: _when);

    expect(path, isNull);
    expect(_contents(dir), seeded);
  });

  test('NEW-1 a refused backup does not create the target directory', () async {
    final dir = Directory('${root.path}/Auto Backup');

    final path = await AutoBackupService.writeBackupFile(
      dir,
      _dataOfUtf8Length(_max + 1),
      now: _when,
    );

    expect(path, isNull);
    expect(dir.existsSync(), isFalse);
  });

  test('NEW-1 a normal small backup is still written as UTF-8 JSON', () async {
    final dir = Directory('${root.path}/Auto Backup');

    final path = await AutoBackupService.writeBackupFile(
      dir,
      _data(name: 'Makan é \u{1F600}'),
      now: _when,
    );

    expect(path, endsWith('ikuyo_backup_20260201_020000.json'));
    expect(
      BackupData.fromJsonString(
        utf8.decode(File(path!).readAsBytesSync()),
      ).categories.single.name,
      'Makan é \u{1F600}',
    );
  });
}
