// Regression: review NEW-1 (review-ikuyo-final-slices-20261107T173810Z).
// The scheduled auto backup wrote its JSON with no size bound, so it could
// produce a file the importer refuses (BackupCrypto.maxBackupBytes, 32 MiB).
// Since F10 the auto backup is sealed as an IKYB v1 envelope, so the bound
// is checked on the sealed size (UTF-8 JSON bytes + envelope overhead, not
// the character count) before the directory or file is touched. A refused
// backup writes nothing, returns no path (runBackup reports false) and does
// not prune: every earlier backup stays as it was.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/backup/models/backup_data.dart';
import 'package:ikuyo_finance/features/backup/services/auto_backup_service.dart';
import 'package:ikuyo_finance/features/backup/services/backup_crypto.dart';

import '../support/test_logger.dart';

const _max = BackupCrypto.maxBackupBytes;
const _clearMax = _max - BackupCrypto.envelopeOverhead;
final _when = DateTime(2026, 2, 1, 2, 0, 0);

// * Kunci sintetis untuk pengujian; bukan turunan passphrase nyata
BackupKeyMaterial _key() => BackupKeyMaterial(
  salt: List.generate(16, (i) => i + 1),
  key: List.generate(32, (i) => 200 - i),
);

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

/// Twelve earlier encrypted backups (more than the rotation keeps) plus one
/// legacy plaintext backup that must never be touched.
Map<String, List<int>> _seedOldBackups(Directory dir) {
  final seeded = <String, List<int>>{};
  for (var i = 1; i <= 12; i++) {
    final d = i.toString().padLeft(2, '0');
    final name = 'ikuyo_backup_202601${d}_020000.ikuyo';
    final body = [0x49, 0x4B, 0x59, 0x42, i];
    File('${dir.path}/$name').writeAsBytesSync(body);
    seeded[name] = body;
  }
  const legacy = 'ikuyo_backup_20251201_020000.json';
  File('${dir.path}/$legacy').writeAsStringSync('{"seed":0}');
  seeded[legacy] = utf8.encode('{"seed":0}');
  return seeded;
}

Map<String, List<int>> _contents(Directory dir) => {
  for (final f in dir.listSync().whereType<File>())
    f.uri.pathSegments.last: f.readAsBytesSync(),
};

void main() {
  setUpAll(bootstrapTestLogger);

  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('ikuyo_autobk_'));
  tearDown(() => root.deleteSync(recursive: true));

  test('NEW-1 a backup whose sealed size is exactly the limit is written '
      'and rotation still runs', () async {
    final dir = Directory('${root.path}/Auto Backup')..createSync();
    _seedOldBackups(dir);
    final key = _key();

    final path = await AutoBackupService.writeBackupFile(
      dir,
      _dataOfUtf8Length(_clearMax),
      key,
      now: _when,
    );

    expect(path, isNotNull);
    expect(File(path!).lengthSync(), _max);
    expect(BackupCrypto.detect(File(path).readAsBytesSync()),
        BackupFileFormat.encrypted);
    // 10 newest encrypted + the untouched legacy .json
    expect(dir.listSync().whereType<File>(), hasLength(11));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('NEW-1 one byte over the sealed limit is refused: nothing written, '
      'no pruning, every earlier backup unchanged', () async {
    final dir = Directory('${root.path}/Auto Backup')..createSync();
    final seeded = _seedOldBackups(dir);

    final path = await AutoBackupService.writeBackupFile(
      dir,
      _dataOfUtf8Length(_clearMax + 1),
      _key(),
      now: _when,
    );

    expect(path, isNull);
    expect(_contents(dir), seeded);
  }, timeout: const Timeout(Duration(minutes: 1)));

  test('NEW-1 four-byte Unicode over the limit is refused although its '
      'character count is far below it', () async {
    final dir = Directory('${root.path}/Auto Backup')..createSync();
    final seeded = _seedOldBackups(dir);
    final data = _dataOfUtf8Length(_clearMax + 4, unit: '\u{1F600}');
    expect(data.toJsonString().length, lessThan(_max ~/ 2 + 1024));

    final path = await AutoBackupService.writeBackupFile(
      dir,
      data,
      _key(),
      now: _when,
    );

    expect(path, isNull);
    expect(_contents(dir), seeded);
  }, timeout: const Timeout(Duration(minutes: 1)));

  test('NEW-1 a refused backup does not create the target directory', () async {
    final dir = Directory('${root.path}/Auto Backup');

    final path = await AutoBackupService.writeBackupFile(
      dir,
      _dataOfUtf8Length(_clearMax + 1),
      _key(),
      now: _when,
    );

    expect(path, isNull);
    expect(dir.existsSync(), isFalse);
  }, timeout: const Timeout(Duration(minutes: 1)));

  test('NEW-1 a normal small backup is written as an encrypted .ikuyo '
      'whose UTF-8 content round-trips', () async {
    final dir = Directory('${root.path}/Auto Backup');
    final key = _key();

    final path = await AutoBackupService.writeBackupFile(
      dir,
      _data(name: 'Makan é \u{1F600}'),
      key,
      now: _when,
    );

    expect(path, endsWith('ikuyo_backup_20260201_020000.ikuyo'));
    final bytes = File(path!).readAsBytesSync();
    expect(BackupCrypto.detect(bytes), BackupFileFormat.encrypted);
    expect(
      latin1.decode(bytes).contains('Makan'),
      isFalse,
      reason: 'no plaintext in the auto backup file',
    );
  });
}
