// Regression: F10 (owner decision option B). Scheduled auto backups used to
// be plaintext ikuyo_backup_<ts>.json files rotated to the newest 10. New
// auto backups are encrypted .ikuyo envelopes; rotation applies only to
// those. Existing plaintext .json backups from earlier versions are never
// converted or deleted automatically. The UI copy describes the policy.
// This file uses only APIs that already existed before F10 so it runs RED
// on the baseline.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/backup/services/auto_backup_service.dart';

import '../support/test_logger.dart';

List<String> _names(Directory dir) =>
    dir.listSync().whereType<File>().map((f) => f.uri.pathSegments.last).toList()
      ..sort();

void main() {
  setUpAll(bootstrapTestLogger);

  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('ikuyo_f10_legacy_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('F10 rotation never deletes or changes legacy plaintext .json '
      'auto backups, however many there are', () async {
    final legacy = <String, String>{};
    for (var i = 1; i <= 13; i++) {
      final d = i.toString().padLeft(2, '0');
      final name = 'ikuyo_backup_202501${d}_020000.json';
      final body = '{"legacy":$i}';
      File('${dir.path}/$name').writeAsStringSync(body);
      legacy[name] = body;
    }

    await AutoBackupService.pruneOldBackups(dir, keep: 10);

    for (final e in legacy.entries) {
      final f = File('${dir.path}/${e.key}');
      expect(f.existsSync(), isTrue, reason: '${e.key} must be preserved');
      expect(f.readAsStringSync(), e.value);
    }
  });

  test('F10 retention keeps the newest encrypted backups only and ignores '
      'legacy .json and unrelated files', () async {
    for (var i = 1; i <= 13; i++) {
      final d = i.toString().padLeft(2, '0');
      File('${dir.path}/ikuyo_backup_202602${d}_020000.ikuyo')
          .writeAsBytesSync([0x49, 0x4B, 0x59, 0x42, i]);
    }
    for (var i = 1; i <= 3; i++) {
      File('${dir.path}/ikuyo_backup_2025010${i}_020000.json')
          .writeAsStringSync('{}');
    }
    File('${dir.path}/notes.txt').writeAsStringSync('keep me');

    await AutoBackupService.pruneOldBackups(dir, keep: 10);

    final names = _names(dir);
    final encrypted = names.where((n) => n.endsWith('.ikuyo')).toList();
    expect(encrypted, hasLength(10));
    expect(encrypted.first, 'ikuyo_backup_20260204_020000.ikuyo');
    expect(encrypted.last, 'ikuyo_backup_20260213_020000.ikuyo');
    expect(names.where((n) => n.endsWith('.json')), hasLength(3));
    expect(names, contains('notes.txt'));
  });

  test('F10 auto backup copy is localized and no longer implies every '
      'backup is encrypted', () {
    for (final locale in ['en-US', 'id-ID']) {
      final json =
          jsonDecode(
                File('assets/translations/$locale.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final backup = json['backup'] as Map<String, dynamic>;
      final screen = backup['screen'] as Map<String, dynamic>;
      expect(screen['autoDescription'] as String, contains('.ikuyo'));
      final auto = backup['auto'] as Map<String, dynamic>?;
      expect(auto, isNotNull, reason: '$locale backup.auto');
      for (final key in [
        'setupTitle',
        'setupDescription',
        'setupWarning',
        'setupConfirm',
        'pausedTitle',
        'pausedMissing',
        'pausedUnreadable',
        'setupButton',
        'changeButton',
        'legacyNote',
        'keySetupFailed',
        'keyClearFailed',
      ]) {
        expect(auto![key], isA<String>(), reason: '$locale $key');
      }
    }
    final en =
        (jsonDecode(File('assets/translations/en-US.json').readAsStringSync())
                as Map<String, dynamic>)['backup']['screen']['infoDescription']
            as String;
    expect(en, isNot('Backups are encrypted with your passphrase and can be '
        'imported back anytime.'));
  });
}
