// Regression: CI-LOCK (the release workflow pinned Flutter 3.38.8, whose SDK
// packages - characters, material_color_utilities, meta, test_api, matcher,
// test, test_core - are older than the committed pubspec.lock that was
// resolved and tested with Flutter 3.44.5; `flutter pub get
// --enforce-lockfile` on 3.38.8 exits 65 because it would downgrade them, and
// a plain `flutter pub get` silently re-resolves). CI must build with the
// tested SDK and the exact lock: every dependency resolution enforces the
// lockfile and the later flutter commands do not resolve again (--no-pub).
// Existing secrets / signing / version / permission guards stay in place.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _testedFlutter = '3.44.5';

void main() {
  // * normalize CRLF (e.g. core.autocrlf=true checkouts) so the parser sees LF
  final workflow = File(
    '.github/workflows/release.yml',
  ).readAsStringSync().replaceAll('\r\n', '\n');
  final lines = workflow.split('\n');

  /// Shell lines of every `run:` step (inline and block scalars).
  List<String> runLines() {
    final out = <String>[];
    for (var i = 0; i < lines.length; i++) {
      final m = RegExp(r'^(\s*)run:\s*(.*)$').firstMatch(lines[i]);
      if (m == null) continue;
      final rest = m.group(2)!.trim();
      if (rest.isNotEmpty && rest != '|' && rest != '>') {
        out.add(rest);
        continue;
      }
      final indent = m.group(1)!.length;
      for (var j = i + 1; j < lines.length; j++) {
        final l = lines[j];
        if (l.trim().isEmpty) continue;
        if (l.length - l.trimLeft().length <= indent) break;
        out.add(l.trim());
      }
    }
    return out;
  }

  /// Whole shell commands with `\` continuations joined.
  List<String> commands() {
    final out = <String>[];
    var cur = '';
    for (final l in runLines()) {
      if (l.endsWith('\\')) {
        cur += '${l.substring(0, l.length - 1)} ';
      } else {
        out.add((cur + l).trim());
        cur = '';
      }
    }
    return out;
  }

  List<String> flutterCommands() =>
      commands().where((c) => RegExp(r'(^|\s)flutter\s').hasMatch(c)).toList();

  test(
    'CI-LOCK the workflow pins the Flutter version the lock was tested on',
    () {
      final pin = RegExp(
        r"^\s*FLUTTER_VERSION:\s*'([^']+)'\s*$",
        multiLine: true,
      ).allMatches(workflow).map((m) => m.group(1)).toList();
      expect(pin, [_testedFlutter]);
      expect(
        workflow,
        contains(r'flutter-version: ${{ env.FLUTTER_VERSION }}'),
      );
      expect(workflow, contains('channel: stable'));
      expect(
        RegExp(r'flutter-version:').allMatches(workflow).length,
        1,
        reason: 'a single SDK pin, no per-job override',
      );
    },
  );

  test('CI-LOCK the pinned SDK satisfies the committed lock SDK bounds', () {
    final lock = File('pubspec.lock').readAsStringSync();
    final lower = RegExp(r'flutter: ">=(\d+)\.(\d+)\.(\d+)"').firstMatch(lock)!;
    final pin = _testedFlutter.split('.').map(int.parse).toList();
    final min = [1, 2, 3].map((i) => int.parse(lower.group(i)!)).toList();
    var cmp = 0;
    for (var i = 0; i < 3 && cmp == 0; i++) {
      cmp = pin[i].compareTo(min[i]);
    }
    expect(cmp, greaterThanOrEqualTo(0));
  });

  test('CI-LOCK every pub get enforces the committed lockfile', () {
    final pubGets = flutterCommands()
        .where((c) => RegExp(r'\bpub\s+(get|upgrade|downgrade)\b').hasMatch(c))
        .toList();
    expect(pubGets, isNotEmpty);
    for (final c in pubGets) {
      expect(c, matches(RegExp(r'^flutter pub get(\s|$)')), reason: c);
      expect(c, contains('--enforce-lockfile'), reason: c);
    }
    expect(workflow, isNot(contains('pub upgrade')));
    expect(workflow, isNot(contains('pub downgrade')));
  });

  test('CI-LOCK later flutter commands do not resolve dependencies again', () {
    final others = flutterCommands()
        .where((c) => !c.startsWith('flutter pub get'))
        .toList();
    expect(
      others.map((c) => c.split(RegExp(r'\s+')).take(2).join(' ')).toSet(),
      containsAll(<String>['flutter analyze', 'flutter test', 'flutter build']),
    );
    for (final c in others) {
      expect(c, contains('--no-pub'), reason: c);
    }
  });

  test('CI-LOCK lock is enforced before analyze, test and build', () {
    final cmds = flutterCommands();
    final get = cmds.indexWhere((c) => c.startsWith('flutter pub get'));
    expect(get, 0, reason: cmds.join('\n'));
  });

  test('CI-LOCK existing release guards are preserved', () {
    // * signing fails closed in Gradle when key.properties is missing
    expect(workflow, contains("IKUYO_REQUIRE_RELEASE_SIGNING: 'true'"));
    // * secrets verified, passed through env only (never inlined in shell)
    expect(workflow, contains('Verify required secrets'));
    expect(runLines().where((l) => l.contains(r'${{ secrets.')), isEmpty);
    // * version tag format guard and no release overwrite
    expect(workflow, contains(r"grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+"));
    expect(workflow, contains('refusing to delete or overwrite'));
    // * write permission only on the release job
    expect(RegExp(r'contents:\s*write').allMatches(workflow).length, 1);
    expect(
      workflow.indexOf('contents: write'),
      greaterThan(workflow.indexOf('  release:')),
    );
    // * the build job still analyzes and tests before building
    final cmds = flutterCommands();
    final analyze = cmds.indexWhere((c) => c.startsWith('flutter analyze'));
    final tests = cmds.indexWhere((c) => c.startsWith('flutter test'));
    final build = cmds.indexWhere((c) => c.startsWith('flutter build'));
    expect(analyze, greaterThanOrEqualTo(0));
    expect(tests, greaterThan(analyze));
    expect(build, greaterThan(tests));
  });
}
