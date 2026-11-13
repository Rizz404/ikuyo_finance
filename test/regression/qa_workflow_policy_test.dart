// Regression: QA-CI (independent QA needs real GitHub CI on a pushed QA branch
// plus a signed APK whose certificate proves the release signer, without any
// path that tags, releases, pushes or deploys). The QA workflow must trigger
// only on `qa/herguri-*` branch pushes, stay read-only, resolve the exact
// lock, verify the ObjectBox native lib digest, keep signing fail-closed and
// fail the job when the APK certificate is not the expected release cert.
// The workflow is parsed structurally (mappings/sequences/block scalars, LF or
// CRLF); unsafe candidates are mutated from the real file and must be rejected.
// QA-REG (run 42444037238: `flutter build apk --release --no-pub` compiled the
// debug-mode GeneratedPluginRegistrant written by `pub get`, which references
// the dev_dependency plugins integration_test / flutter_native_splash that the
// release Gradle graph omits): the signed build must run with pub so the
// registrant is regenerated in release mode, against a provably unchanged lock.
// QA-CERT (signed job 128635169961: the step exited 1 without an annotation;
// ubuntu-latest ships build-tools 37.0.0, whose apksigner (apksig d177d78)
// names the only signer "V2 Signer:" / "V3.0 Signer:" instead of "Signer #1",
// so the unguarded `grep 'Signer #1 ...'` failed under pipefail): apksigner
// must exit 0, the output must hold exactly one leaf signer certificate digest
// (no other digest lines but Source Stamp, "Number of signers: 1"), 64 hex,
// equal to the expected cert; every failure is an ::error annotation.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _qaPath = '.github/workflows/qa.yml';
const _testedFlutter = '3.44.5';
const _obxVersion = '5.0.0-rc';
const _obxSha256 =
    '280195f19594227068fcf389d32d5b315c9a6daabc3115cd3aac9c3cc8ad39a8';
const _releaseCertSha256 =
    '3cb92848113a05569dc0647b1d1563d094b47ad167f0ee2ffdf382591c546feb';
const _allowedActions = {
  'actions/checkout@v6',
  'actions/setup-java@v5',
  'subosito/flutter-action@v2',
  'actions/cache@v4',
  'actions/upload-artifact@v4',
};
const _signingSecrets = {
  'KEYSTORE_BASE64',
  'KEYSTORE_PASSWORD',
  'KEY_PASSWORD',
  'KEY_ALIAS',
};
const _signedBuild = 'flutter build apk --release';
const _otherCertSha256 =
    'c48112390477dbbdae99e54068eddccdc547ca7b8e18a7f2cea4a84fd98b6ccf';
// * real `apksigner verify --verbose --print-certs` output of the public Ikuyo
// * v1.1.0 release APK (build-tools 36.0.0, apksigner 0.9)
const _realBt36Output = '''Verifies
Verified using v1 scheme (JAR signing): false
Verified using v2 scheme (APK Signature Scheme v2): true
Verified using v3 scheme (APK Signature Scheme v3): false
Verified using v3.1 scheme (APK Signature Scheme v3.1): false
Verified using v4 scheme (APK Signature Scheme v4): false
Verified for SourceStamp: false
Number of signers: 1
Signer #1 certificate DN: CN=Ikuyo Finance, OU=, O=, L=, ST=, C=ID
Signer #1 certificate SHA-256 digest: 3cb92848113a05569dc0647b1d1563d094b47ad167f0ee2ffdf382591c546feb
Signer #1 certificate SHA-1 digest: 6201070262f3d7563cc6c62f6ed8304768f61e39
Signer #1 certificate MD5 digest: 9f8ed955db7f3ae703dcd29f4ce21e6a
Signer #1 key algorithm: RSA
Signer #1 key size (bits): 2048
Signer #1 public key SHA-256 digest: ed06224e32781e7c275013f658d92fb9439418fbfaec5cc00641b60c2f40ebb1
Signer #1 public key SHA-1 digest: e4bb66a25105155cef6f7418c2b3bec11c82262d
Signer #1 public key MD5 digest: 79faa84965c42f52ace65f6a5dcf70f9
''';
// * the certificate step published at dc1b118 (failed on build-tools 37.0.0)
const _publishedCertStep = r'''      - name: Verify APK signing certificate (fail closed)
        run: |
          set -euo pipefail
          apk="build/app/outputs/flutter-apk/app-release.apk"
          test -s "$apk"
          build_tools="$(ls -d "${ANDROID_HOME:?}"/build-tools/* | sort -V | tail -n 1)"
          mkdir -p qa-out
          "$build_tools/apksigner" verify --verbose --print-certs "$apk" > qa-out/apk-cert.txt
          signers="$(grep -c 'certificate SHA-256 digest:' qa-out/apk-cert.txt || true)"
          actual="$(grep 'Signer #1 certificate SHA-256 digest:' qa-out/apk-cert.txt | awk '{print $NF}' | tr 'A-F' 'a-f')"
          if [ "$signers" != "1" ] || [ "$actual" != "$QA_EXPECTED_CERT_SHA256" ]; then
            echo "::error::APK signer mismatch (signers=$signers actual=$actual expected=$QA_EXPECTED_CERT_SHA256)"
            exit 1
          fi
          echo "APK signer certificate SHA-256 matches $QA_EXPECTED_CERT_SHA256"
''';
const _leafAccept = [
  'Signer #1 certificate SHA-256 digest: ',
  'V2 Signer: certificate SHA-256 digest: ',
  'V3.0 Signer: certificate SHA-256 digest: ',
  'V1 Signer: certificate SHA-256 digest: ',
  'Signer (minSdkVersion=24, maxSdkVersion=32) certificate SHA-256 digest: ',
];
const _leafReject = [
  'Signer #1 public key SHA-256 digest: ',
  'V2 Signer: public key SHA-256 digest: ',
  'Signer #1 certificate SHA-1 digest: ',
  'Source Stamp Signer: certificate SHA-256 digest: ',
  'Source Stamp Signer certificate SHA-256 digest: ',
  'V3.2 Hybrid PQC Signer: certificate SHA-256 digest: ',
  '  Signer #1 certificate SHA-256 digest: ',
  'Signer #1 certificate DN: CN=x certificate SHA-256 digest: ',
];
const _uploadPaths = [
  'qa-out/ikuyo-finance-qa-*-universal.apk',
  'qa-out/apk-cert.txt',
  'qa-out/qa-manifest.txt',
];

/// Minimal block-YAML reader for GitHub workflow files: mappings, sequences,
/// block scalars, quoted/plain scalars and flow sequences. Anything else
/// throws, so an unparseable workflow fails the policy instead of passing.
Object? _parseYaml(String source) {
  final reader = _YamlReader(source.replaceAll('\r\n', '\n').split('\n'));
  final value = reader.block(0, 0);
  final rest = reader.skip(reader.pos);
  if (rest < reader.lines.length) {
    throw FormatException('unexpected content at line ${rest + 1}');
  }
  return value;
}

class _YamlReader {
  _YamlReader(this.lines);

  final List<String> lines;
  int pos = 0;

  static final _key = RegExp(r'^([\w.\-]+):(?:\s+(.*))?$');

  static int indentOf(String l) => l.length - l.trimLeft().length;

  static bool isItem(String l) {
    final t = l.trim();
    return t == '-' || t.startsWith('- ');
  }

  int skip(int i) {
    while (i < lines.length) {
      final t = lines[i].trim();
      if (t.isNotEmpty && !t.startsWith('#')) break;
      i++;
    }
    return i;
  }

  void _checkTabs(int i) {
    final lead = lines[i].substring(0, indentOf(lines[i]));
    if (lead.contains('\t')) {
      throw FormatException('tab indentation at line ${i + 1}');
    }
  }

  Object? block(int start, int minIndent) {
    final i = skip(start);
    if (i >= lines.length || indentOf(lines[i]) < minIndent) {
      pos = i;
      return null;
    }
    _checkTabs(i);
    final indent = indentOf(lines[i]);
    if (isItem(lines[i])) return _seq(i, indent);
    return _map(i, indent, null);
  }

  Map<String, Object?> _map(int start, int indent, String? firstText) {
    final out = <String, Object?>{};
    var i = start;
    var first = true;
    while (true) {
      if (!first) {
        i = skip(i);
        if (i >= lines.length) break;
        _checkTabs(i);
        final ind = indentOf(lines[i]);
        if (ind < indent || (ind == indent && isItem(lines[i]))) break;
        if (ind > indent) {
          throw FormatException('unexpected indentation at line ${i + 1}');
        }
      }
      final text = first && firstText != null ? firstText : lines[i].trim();
      first = false;
      final m = _key.firstMatch(text);
      if (m == null) {
        throw FormatException('expected "key: value" at line ${i + 1}: $text');
      }
      final key = m.group(1)!;
      if (out.containsKey(key)) {
        throw FormatException('duplicate key "$key" at line ${i + 1}');
      }
      final rest = (m.group(2) ?? '').trim();
      if (rest.isEmpty) {
        final j = skip(i + 1);
        final nested =
            j < lines.length &&
            (indentOf(lines[j]) > indent ||
                (indentOf(lines[j]) == indent && isItem(lines[j])));
        if (nested) {
          out[key] = block(j, indentOf(lines[j]));
          i = pos;
        } else {
          out[key] = null;
          i++;
        }
      } else if (const {'|', '|-', '>', '>-'}.contains(rest)) {
        out[key] = _blockScalar(i + 1, indent);
        i = pos;
      } else {
        out[key] = _scalar(rest, i);
        i++;
      }
    }
    pos = i;
    return out;
  }

  List<Object?> _seq(int start, int indent) {
    final out = <Object?>[];
    var i = start;
    while (true) {
      i = skip(i);
      if (i >= lines.length) break;
      _checkTabs(i);
      final ind = indentOf(lines[i]);
      if (ind < indent || !isItem(lines[i])) break;
      if (ind > indent) {
        throw FormatException('unexpected indentation at line ${i + 1}');
      }
      final rest = lines[i].trim().substring(1).trim();
      if (rest.isEmpty) {
        out.add(block(i + 1, indent + 1));
        i = pos;
      } else if (_key.hasMatch(rest) || RegExp(r'^[\w.\-]+:$').hasMatch(rest)) {
        out.add(_map(i, lines[i].indexOf(rest, indent + 1), rest));
        i = pos;
      } else {
        out.add(_scalar(rest, i));
        i++;
      }
    }
    pos = i;
    return out;
  }

  String _blockScalar(int start, int parentIndent) {
    final body = <String>[];
    var j = start;
    while (j < lines.length &&
        (lines[j].trim().isEmpty || indentOf(lines[j]) > parentIndent)) {
      body.add(lines[j]);
      j++;
    }
    pos = j;
    final content = body.where((l) => l.trim().isNotEmpty).toList();
    if (content.isEmpty) return '';
    final ind = content.map(indentOf).reduce((a, b) => a < b ? a : b);
    return body
        .map((l) => l.trim().isEmpty ? '' : l.substring(ind))
        .join('\n')
        .trimRight();
  }

  Object? _scalar(String s, int i) {
    if (s.startsWith("'")) {
      if (s.length < 2 || !s.endsWith("'")) {
        throw FormatException('unterminated quote at line ${i + 1}');
      }
      return s.substring(1, s.length - 1).replaceAll("''", "'");
    }
    if (s.startsWith('"')) {
      if (s.length < 2 || !s.endsWith('"')) {
        throw FormatException('unterminated quote at line ${i + 1}');
      }
      return s.substring(1, s.length - 1);
    }
    if (s.startsWith('[')) {
      if (!s.endsWith(']')) {
        throw FormatException('unterminated flow sequence at line ${i + 1}');
      }
      final inner = s.substring(1, s.length - 1).trim();
      if (inner.isEmpty) return <Object?>[];
      return inner.split(',').map((e) => _scalar(e.trim(), i)).toList();
    }
    if (RegExp(r'^[{&*!%@`]').hasMatch(s)) {
      throw FormatException('unsupported YAML syntax at line ${i + 1}: $s');
    }
    final c = s.indexOf(' #');
    return (c >= 0 ? s.substring(0, c) : s).trim();
  }
}

Map<String, Object?> _asMap(Object? o) =>
    o is Map<String, Object?> ? o : const <String, Object?>{};

List<Object?> _asList(Object? o) => o is List<Object?> ? o : const <Object?>[];

/// Shell commands of a `run:` script, `\` continuations joined.
List<String> _commands(String run) {
  final out = <String>[];
  var cur = '';
  for (final raw in run.split('\n')) {
    final l = raw.trim();
    if (l.isEmpty) continue;
    if (l.endsWith('\\')) {
      cur += '${l.substring(0, l.length - 1)} ';
    } else {
      out.add((cur + l).trim());
      cur = '';
    }
  }
  return out;
}

bool _isFlutter(String c) => RegExp(r'(^|\s)flutter\s').hasMatch(c);

/// The leaf signer pattern of the certificate step (`leaf='...'`), or null.
String? _leafPattern(String run) {
  final m = RegExp(r"^leaf='([^'\n]+)'$", multiLine: true).allMatches(run);
  return m.length == 1 ? m.single.group(1) : null;
}

/// Fail-closed rules for the APK certificate step (QA-CERT); empty means safe.
List<String> _certStepViolations(String r) {
  final v = <String>[];
  bool fatal(String guard) => RegExp(
    '${RegExp.escape(guard)}\n(?:\\s*\\w+="[^\n]*\n)?\\s*echo "::error::[^\n]*\n\\s*exit 1\n',
  ).hasMatch('$r\n');
  if (!r.contains('set -euo pipefail')) {
    v.add('signed-apk: certificate step must use set -euo pipefail');
  }
  if (!r.contains(
        r'--print-certs "$apk" > qa-out/apk-cert.txt 2> qa-out/apk-cert.err '
        r'|| status=$?',
      ) ||
      !fatal(r'if [ "$status" -ne 0 ]; then')) {
    v.add('signed-apk: apksigner verify exit status must be captured and fatal');
  }
  if (!r.contains(r'''out="$(tr -d '\r' < qa-out/apk-cert.txt)"''')) {
    v.add('signed-apk: certificate output must be CR-stripped before parsing');
  }
  final leaf = _leafPattern(r);
  RegExp? re;
  try {
    re = leaf == null ? null : RegExp(leaf);
  } on FormatException {
    re = null;
  }
  final bad = re == null
      ? ['no leaf pattern']
      : [
          ..._leafAccept.where((l) => !re!.hasMatch(l)).map((l) => 'misses "$l"'),
          ..._leafReject.where((l) => re!.hasMatch(l)).map((l) => 'accepts "$l"'),
        ];
  if (bad.isNotEmpty) {
    v.add('signed-apk: leaf signer pattern is wrong: ${bad.join('; ')}');
  }
  final counted =
      r.contains(
        r'mapfile -t digests < <(grep -E "$leaf" <<< "$out" | sed -E "s/$leaf//" || true)',
      ) &&
      r.contains(
        r'''all="$(grep -c ' certificate SHA-256 digest: ' <<< "$out" || true)"''',
      ) &&
      r.contains(
        r'''stamp="$(grep -cE '^Source Stamp Signer:? certificate SHA-256 digest: ' <<< "$out" || true)"''',
      ) &&
      r.contains(
        r'''count="$(grep -cx 'Number of signers: 1' <<< "$out" || true)"''',
      ) &&
      fatal(
        r'if [ "${#digests[@]}" -ne 1 ] || [ "$all" -ne $((${#digests[@]} + stamp)) ] '
        r'|| [ "$count" != "1" ]; then',
      );
  if (!counted) {
    v.add(
      'signed-apk: certificate check must require exactly one leaf signer, '
      'no other digest lines and "Number of signers: 1"',
    );
  }
  if (!fatal(r'if ! [[ "${digests[0]}" =~ ^[0-9a-fA-F]{64}$ ]]; then')) {
    v.add('signed-apk: signer digest must be checked as 64 hex');
  }
  if (!r.contains(r'''actual="$(tr 'A-F' 'a-f' <<< "${digests[0]}")"''') ||
      !fatal(r'if [ "$actual" != "$QA_EXPECTED_CERT_SHA256" ]; then') ||
      !RegExp(r'::error::APK signer mismatch[^\n]*\n\s*exit 1').hasMatch(r)) {
    v.add('signed-apk: certificate check must fail (exit 1) on mismatch');
  }
  if (RegExp(r'\bhead\b|\buniq\b|\bsort\s+-u\b|grep[^\n]*QA_EXPECTED_CERT_SHA256')
      .hasMatch(r)) {
    v.add(
      'signed-apk: certificate check must compare only the single leaf digest '
      '(no head/uniq/sort -u/grep of the expected hash)',
    );
  }
  return v;
}

/// Dart mirror of the certificate step decision (bash in qa.yml) using the
/// leaf pattern read from the workflow; null means the step would pass.
String? _certDecision(String run, String stdout, int exit) {
  if (exit != 0) return 'apksigner verify failed';
  final leaf = RegExp(_leafPattern(run)!);
  final lines = stdout.replaceAll('\r', '').split('\n');
  final digests = [
    for (final l in lines)
      if (leaf.hasMatch(l)) l.replaceFirst(leaf, ''),
  ];
  final all = lines.where((l) => l.contains(' certificate SHA-256 digest: '));
  final stamp = lines.where(
    (l) => RegExp(r'^Source Stamp Signer:? certificate SHA-256 digest: ').hasMatch(l),
  );
  final count = lines.where((l) => l == 'Number of signers: 1');
  if (digests.length != 1 ||
      all.length != digests.length + stamp.length ||
      count.length != 1) {
    return 'expected exactly one leaf signer certificate';
  }
  if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(digests.single)) {
    return 'malformed signer certificate SHA-256 digest';
  }
  if (digests.single.toLowerCase() != _releaseCertSha256) {
    return 'APK signer mismatch';
  }
  return null;
}

/// Every QA-only safety rule this repository requires; empty means safe.
List<String> _qaWorkflowViolations(String source) {
  final v = <String>[];
  final Object? doc;
  try {
    doc = _parseYaml(source);
  } on FormatException catch (e) {
    return ['unparseable workflow: ${e.message}'];
  }
  if (doc is! Map<String, Object?>) return ['workflow root is not a mapping'];
  final text = source.replaceAll('\r\n', '\n');

  // * triggers: only a push of qa/herguri-* branches
  final on = doc['on'];
  if (on is! Map<String, Object?> || on.keys.join(',') != 'push') {
    v.add(
      'trigger must be exactly on.push, got ${on is Map ? on.keys.toList() : on}',
    );
  }
  final push = _asMap(_asMap(on)['push']);
  if (push.keys.join(',') != 'branches') {
    v.add('on.push must filter only branches, got ${push.keys.toList()}');
  }
  final branches = _asList(push['branches']);
  if (branches.length != 1 || branches.single != 'qa/herguri-*') {
    v.add('on.push.branches must be exactly [qa/herguri-*], got $branches');
  }

  // * read-only token everywhere
  final perms = doc['permissions'];
  if (perms is! Map || perms.length != 1 || perms['contents'] != 'read') {
    v.add('top-level permissions must be exactly contents: read, got $perms');
  }
  if (RegExp(r'contents:\s*write|write-all').hasMatch(text)) {
    v.add('write permission present in workflow');
  }

  final env = _asMap(doc['env']);
  if (env['FLUTTER_VERSION'] != _testedFlutter) {
    v.add('FLUTTER_VERSION must be $_testedFlutter, got ${env['FLUTTER_VERSION']}');
  }

  final jobs = _asMap(doc['jobs']);
  if (jobs.length != 2 ||
      !jobs.containsKey('verify') ||
      !jobs.containsKey('signed-apk')) {
    v.add('jobs must be exactly verify and signed-apk, got ${jobs.keys.toList()}');
  }

  // * secrets only as env of signed-apk steps, and only the signing secrets
  final secretRefs = RegExp(r'\$\{\{\s*secrets\.(\w+)\s*\}\}');
  var allowedRefs = 0;
  var uploads = 0;

  for (final e in jobs.entries) {
    final name = e.key;
    final job = _asMap(e.value);
    if (job['runs-on'] != 'ubuntu-latest') {
      v.add('$name: runs-on must be ubuntu-latest, got ${job['runs-on']}');
    }
    final jp = job['permissions'];
    if (jp != null && (jp is! Map || jp.length != 1 || jp['contents'] != 'read')) {
      v.add('$name: job permissions must be contents: read only, got $jp');
    }
    if (job.containsKey('environment')) {
      v.add('$name: deployment environment not allowed');
    }
    if (_asMap(job['env']).containsKey('FLUTTER_VERSION')) {
      v.add('$name: FLUTTER_VERSION overridden per job');
    }
    for (final s in secretRefs.allMatches('${job['env'] ?? ''}')) {
      v.add('$name: job-level secret reference ${s.group(1)}');
    }
    final steps = _asList(job['steps']).map(_asMap).toList();
    if (steps.isEmpty) v.add('$name: no steps');

    final flutter = <(int, String)>[];
    for (var i = 0; i < steps.length; i++) {
      final s = steps[i];
      final uses = s['uses'];
      if (uses != null && !_allowedActions.contains(uses)) {
        v.add('$name: action not allowlisted: $uses');
      }
      if (uses == 'subosito/flutter-action@v2') {
        final w = _asMap(s['with']);
        if (w['flutter-version'] != r'${{ env.FLUTTER_VERSION }}' ||
            w['channel'] != 'stable') {
          v.add('$name: Flutter setup must use env.FLUTTER_VERSION on stable');
        }
      }
      if (uses == 'actions/upload-artifact@v4') uploads++;
      for (final w in _asMap(s['with']).values) {
        if (secretRefs.hasMatch('$w')) v.add('$name: secret passed via with:');
      }
      for (final en in _asMap(s['env']).entries) {
        final m = secretRefs.firstMatch('${en.value}');
        if (m == null) continue;
        if (name == 'signed-apk' &&
            en.key == m.group(1) &&
            _signingSecrets.contains(en.key) &&
            '${en.value}'.trim() == m.group(0)) {
          allowedRefs++;
        } else {
          v.add('$name: secret ${m.group(1)} not allowed in step env');
        }
      }
      final run = s['run'];
      if (run is! String) continue;
      if (secretRefs.hasMatch(run)) v.add('$name: secret interpolated in run');
      const forbidden = {
        r'\bgh\s': 'gh CLI',
        r'\bgit\s+push\b': 'git push',
        r'\bgit\s+tag\b': 'git tag',
        r'\bset\s+-[a-wyz]*x': 'xtrace (set -x)',
        r'release\s+create|softprops|\bdeploy': 'release/deploy step',
        r'GITHUB_TOKEN|GH_TOKEN': 'token use',
      };
      for (final f in forbidden.entries) {
        if (RegExp(f.key).hasMatch(run)) v.add('$name: forbidden ${f.value}');
      }
      for (final c in _commands(run).where(_isFlutter)) {
        flutter.add((i, c));
      }
    }

    // * exact lock first, nothing resolves again afterwards
    if (flutter.isEmpty || !flutter.first.$2.startsWith('flutter pub get')) {
      v.add('$name: first flutter command must be pub get --enforce-lockfile');
    }
    for (final (_, c) in flutter) {
      if (RegExp(r'\bpub\s+(get|upgrade|downgrade)\b').hasMatch(c)) {
        if (!c.startsWith('flutter pub get') ||
            !c.contains('--enforce-lockfile')) {
          v.add('$name: pub get must use --enforce-lockfile: $c');
        }
      } else if (!c.contains('--no-pub') &&
          !(name == 'signed-apk' && c == _signedBuild)) {
        v.add('$name: flutter command must use --no-pub: $c');
      }
    }
    int stepOf(String Function(String) pick) {
      for (final (i, c) in flutter) {
        if (pick(c).isNotEmpty) return i;
      }
      return -1;
    }

    int runStep(bool Function(String) pick) =>
        steps.indexWhere((s) => s['run'] is String && pick(s['run'] as String));

    final pubGet = stepOf((c) => c.startsWith('flutter pub get') ? c : '');

    if (name == 'verify') {
      if (job.containsKey('needs')) v.add('verify: must not depend on jobs');
      if (secretRefs.hasMatch('$job')) v.add('verify: job must be secrets-free');
      final analyze = stepOf((c) => c.startsWith('flutter analyze') ? c : '');
      final tests = stepOf((c) => c.startsWith('flutter test') ? c : '');
      if (analyze < 0 || tests < 0 || analyze < pubGet || tests < analyze) {
        v.add('verify: must run pub get, then analyze, then test');
      }
      if (flutter.any((r) => r.$2.contains('--no-fatal'))) {
        v.add('verify: analyzer findings must stay fatal');
      }
      if (flutter.any((r) => r.$2.startsWith('flutter build'))) {
        v.add('verify: must not build');
      }
      final dotEnv = runStep(
        (r) => r.contains('> .env') && r.contains('http://127.0.0.1'),
      );
      if (dotEnv < 0 || dotEnv > pubGet) {
        v.add('verify: synthetic loopback .env must be created before pub get');
      }
      if (env['OBX_C_VERSION'] != _obxVersion) {
        v.add('OBX_C_VERSION must be $_obxVersion (objectbox_flutter_libs 5.0.2)');
      }
      if (env['OBX_C_SHA256'] != _obxSha256) {
        v.add('OBX_C_SHA256 must be the official objectbox-linux-x64 digest');
      }
      final obx = runStep((r) => r.contains('libobjectbox.so'));
      final obxRun = obx < 0 ? '' : steps[obx]['run'] as String;
      final checked =
          obxRun.contains('set -euo pipefail') &&
          obxRun.contains(r'test "$OBX_C_VERSION" = "' '$_obxVersion"') &&
          obxRun.contains(
            'releases/download/v$_obxVersion/objectbox-linux-x64.tar.gz',
          ) &&
          RegExp(r'echo "\$OBX_C_SHA256 .*\| sha256sum -c -').hasMatch(obxRun) &&
          obxRun.indexOf('sha256sum -c') < obxRun.indexOf('cp ');
      if (!checked || obx < pubGet || obx > tests) {
        v.add('verify: ObjectBox native lib must be digest-verified before tests');
      }
    }

    if (name == 'signed-apk') {
      final needs = job['needs'];
      if (needs != 'verify' && !_asList(needs).contains('verify')) {
        v.add('signed-apk: needs verify');
      }
      if (_asMap(job['env'])['IKUYO_REQUIRE_RELEASE_SIGNING'] != 'true') {
        v.add("signed-apk: IKUYO_REQUIRE_RELEASE_SIGNING must be 'true'");
      }
      final builds = flutter
          .where((r) => r.$2.startsWith('flutter build'))
          .toList();
      if (builds.length != 1 || builds.single.$2 != _signedBuild) {
        v.add(
          'signed-apk: must build exactly one universal APK with '
          '$_signedBuild (pubspec version)',
        );
      }
      final build = builds.isEmpty ? -1 : builds.first.$1;
      final buildRun = build < 0 ? '' : steps[build]['run'] as String;
      final bc = _commands(buildRun);
      final b = bc.indexOf(_signedBuild);
      if (!buildRun.contains('set -euo pipefail') ||
          b < 1 ||
          bc[b - 1] != 'touch pubspec.lock' ||
          b + 1 >= bc.length ||
          bc[b + 1] != 'git diff --exit-code -- pubspec.lock') {
        v.add(
          'signed-apk: build must regenerate the release registrant against '
          'the unchanged lock (touch pubspec.lock; $_signedBuild; '
          'git diff --exit-code -- pubspec.lock)',
        );
      }
      final check = runStep(
        (r) =>
            r.contains('Missing required signing secrets') &&
            _signingSecrets.every(r.contains) &&
            RegExp(r'Missing required signing secrets[^\n]*\n\s*exit 1').hasMatch(r),
      );
      final setup = runStep(
        (r) =>
            r.contains('base64 --decode > android/ikuyo-release.jks') &&
            RegExp(r"printf 'storePassword=%s\\n'").hasMatch(r) &&
            r.contains('} > android/key.properties'),
      );
      if (check < 0 || setup < 0 || check > setup) {
        v.add('signed-apk: fail-closed signing secrets check must precede setup');
      }
      if (setup < 0 || build < 0 || setup > build) {
        v.add('signed-apk: CI signing setup must precede the build');
      }
      if (env['QA_EXPECTED_CERT_SHA256'] != _releaseCertSha256) {
        v.add('QA_EXPECTED_CERT_SHA256 must be the expected certificate digest');
      }
      final cert = runStep(
        (r) => RegExp(r'apksigner"?\s+verify\b[^\n]*--print-certs').hasMatch(r),
      );
      if (cert < 0 || cert < build) {
        v.add('signed-apk: no apksigner verify --print-certs check after build');
      } else {
        v.addAll(_certStepViolations(steps[cert]['run'] as String));
      }
      final manifest = runStep(
        (r) =>
            r.contains('qa_only=true') &&
            r.contains(r'$GITHUB_SHA') &&
            r.contains(r'$GITHUB_RUN_ID'),
      );
      if (manifest < 0) v.add('signed-apk: commit/run manifest missing');
      final cleanup = steps.indexWhere(
        (s) =>
            s['if'] == 'always()' &&
            RegExp(
              r'rm -f .*android/ikuyo-release\.jks.*android/key\.properties',
            ).hasMatch('${s['run']}'),
      );
      if (cleanup < 0 || cleanup < setup) {
        v.add('signed-apk: cleanup of CI signing material must run if: always()');
      }
      final up = steps.indexWhere(
        (s) => s['uses'] == 'actions/upload-artifact@v4',
      );
      final w = up < 0 ? const <String, Object?>{} : _asMap(steps[up]['with']);
      final art = '${w['name']}';
      if (!art.startsWith('qa-only-') ||
          !art.contains(r'${{ github.sha }}') ||
          !art.contains(r'${{ github.run_id }}')) {
        v.add('signed-apk: artifact name must be qa-only with sha and run id');
      }
      final days = int.tryParse('${w['retention-days']}') ?? 999;
      if (days > 7) v.add('signed-apk: artifact retention must be <= 7 days');
      if (w['if-no-files-found'] != 'error') {
        v.add('signed-apk: upload must fail when files are missing');
      }
      final paths = '${w['path']}'
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (paths.join('|') != _uploadPaths.join('|')) {
        v.add('signed-apk: upload path must be exactly APK/cert/manifest, got $paths');
      }
      if (up < cert || up < manifest) {
        v.add('signed-apk: upload must follow certificate check and manifest');
      }
    }
  }
  if (uploads != 1) v.add('exactly one artifact upload expected, got $uploads');
  final allRefs = secretRefs.allMatches(text).length;
  if (allRefs != allowedRefs) {
    v.add('secret reference outside signed-apk step env ($allRefs vs $allowedRefs)');
  }
  return v;
}

void main() {
  final file = File(_qaPath);
  String valid() => file.readAsStringSync().replaceAll('\r\n', '\n');

  test('QA-CI the QA-only workflow exists and satisfies the safety policy', () {
    expect(file.existsSync(), isTrue, reason: '$_qaPath is missing');
    expect(_qaWorkflowViolations(file.readAsStringSync()), isEmpty);
  });

  test('QA-CI the policy is independent of LF/CRLF checkouts', () {
    final lf = valid();
    expect(_qaWorkflowViolations(lf), isEmpty);
    expect(_qaWorkflowViolations(lf.replaceAll('\n', '\r\n')), isEmpty);
  });

  test('QA-CI the parser reads real job structure, not just strings', () {
    final doc = _asMap(_parseYaml(valid()));
    final jobs = _asMap(doc['jobs']);
    expect(jobs.keys, ['verify', 'signed-apk']);
    expect(_asMap(jobs['signed-apk'])['needs'], 'verify');
    expect(_asList(_asMap(jobs['verify'])['steps']), hasLength(8));
    final release = _asMap(
      _parseYaml(File('.github/workflows/release.yml').readAsStringSync()),
    );
    expect(_asList(_asMap(_asMap(release['on'])['push'])['tags']), [
      'v*.*.*',
    ]);
    expect(_asMap(release['jobs']).keys, ['build', 'release']);
  });

  test('QA-CI the release workflow is not an acceptable QA workflow', () {
    final out = _qaWorkflowViolations(
      File('.github/workflows/release.yml').readAsStringSync(),
    );
    expect(out.join('\n'), contains('on.push must filter only branches'));
    expect(out.join('\n'), contains('write permission'));
  });

  group('QA-CERT the certificate step decides fail-closed', () {
    String run() {
      final jobs = _asMap(_asMap(_parseYaml(valid()))['jobs']);
      final steps = _asList(_asMap(jobs['signed-apk'])['steps']).map(_asMap);
      return steps
          .map((s) => s['run'])
          .whereType<String>()
          .singleWhere((r) => r.contains('--print-certs'));
    }

    const digest = 'certificate SHA-256 digest: $_releaseCertSha256';
    const lf = _realBt36Output;
    final bt37 = lf
        .replaceFirst(
          'v3.1): false\n',
          'v3.1): false\n'
              'Verified using v3.2 scheme (APK Signature Scheme v3.2): false\n',
        )
        .replaceAll('Signer #1 ', 'V2 Signer: ');
    String drop(String s, String prefix) =>
        s.split('\n').where((l) => !l.startsWith(prefix)).join('\n');
    String noLeaf(String s) => drop(s, 'Signer #1 certificate SHA-256');
    final two = lf.replaceFirst('Number of signers: 1', 'Number of signers: 2');

    // * name: (stdout, apksigner exit, null = passes / expected failure reason)
    final cases = <String, (String, int, String?)>{
      'real build-tools 36 output, expected cert': (lf, 0, null),
      'real output with CRLF line endings': (lf.replaceAll('\n', '\r\n'), 0, null),
      'BOM before the first line': ('\uFEFF$lf', 0, null),
      'uppercase hex digest': (
        lf.replaceFirst(_releaseCertSha256, _releaseCertSha256.toUpperCase()),
        0,
        null,
      ),
      'build-tools 37 "V2 Signer:" output': (bt37, 0, null),
      'build-tools 37 "V3.0 Signer:" output': (
        bt37.replaceAll('V2 Signer: ', 'V3.0 Signer: '),
        0,
        null,
      ),
      'Source Stamp digest besides the leaf': (
        '${bt37}Source Stamp Signer: certificate SHA-256 digest: ${'cd' * 32}\n',
        0,
        null,
      ),
      'wrong certificate': (
        lf.replaceFirst(_releaseCertSha256, _otherCertSha256),
        0,
        'APK signer mismatch',
      ),
      'wrong certificate, build-tools 37 output': (
        bt37.replaceFirst(_releaseCertSha256, _otherCertSha256),
        0,
        'APK signer mismatch',
      ),
      'zero signer lines': (noLeaf(lf), 0, 'exactly one leaf'),
      'empty output': ('', 0, 'exactly one leaf'),
      'two signers, same certificate twice': (
        two.replaceFirst('Signer #1 $digest\n', 'Signer #1 $digest\nSigner #2 $digest\n'),
        0,
        'exactly one leaf',
      ),
      'two build-tools 37 signers, expected first': (
        bt37
            .replaceFirst('Number of signers: 1', 'Number of signers: 2')
            .replaceFirst(
              'V2 Signer: $digest\n',
              'V2 Signer #1: $digest\n'
                  'V2 Signer #2: certificate SHA-256 digest: ${'ab' * 32}\n',
            ),
        0,
        'exactly one leaf',
      ),
      'v3.1 rotation, same certificate twice': (
        bt37.replaceFirst(
          'V2 Signer: $digest\n',
          'V3.1 Signer: (minSdkVersion=33, maxSdkVersion=2147483647) $digest\n'
              'V3.0 Signer: (minSdkVersion=24, maxSdkVersion=32) $digest\n',
        ),
        0,
        'exactly one leaf',
      ),
      'unknown hybrid signer digest line': (
        '${bt37}V3.2 Hybrid PQC Signer: (minSdkVersion=37, '
            'maxSdkVersion=2147483647) $digest\n',
        0,
        'exactly one leaf',
      ),
      '"Number of signers: 1" missing': (
        lf.replaceFirst('Number of signers: 1\n', ''),
        0,
        'exactly one leaf',
      ),
      'public key digest only (equal to the expected cert)': (
        noLeaf(lf).replaceFirst(
          RegExp(r'Signer #1 public key SHA-256 digest: \w+'),
          'Signer #1 public key SHA-256 digest: $_releaseCertSha256',
        ),
        0,
        'exactly one leaf',
      ),
      'expected hash only in the DN text': (
        noLeaf(lf).replaceFirst(
          RegExp(r'Signer #1 certificate DN: [^\n]*'),
          'Signer #1 certificate DN: CN=$_releaseCertSha256',
        ),
        0,
        'exactly one leaf',
      ),
      'Source Stamp is the expected cert, no leaf': (
        '${noLeaf(lf)}\nSource Stamp Signer: $digest\n',
        0,
        'exactly one leaf',
      ),
      'BOM on the digest line': (
        '\uFEFFSigner #1 $digest\nNumber of signers: 1\n',
        0,
        'exactly one leaf',
      ),
      'leading whitespace': (
        lf.replaceFirst('Signer #1 $digest', '  Signer #1 $digest'),
        0,
        'exactly one leaf',
      ),
      'digest of 63 hex': (
        lf.replaceFirst(_releaseCertSha256, _releaseCertSha256.substring(1)),
        0,
        'malformed',
      ),
      'digest of 65 hex': (
        lf.replaceFirst(_releaseCertSha256, '${_releaseCertSha256}0'),
        0,
        'malformed',
      ),
      'non-hex digest': (
        lf.replaceFirst(_releaseCertSha256, '${_releaseCertSha256.substring(1)}g'),
        0,
        'malformed',
      ),
      'colon separated digest': (
        lf.replaceFirst(
          _releaseCertSha256,
          RegExp('..')
              .allMatches(_releaseCertSha256)
              .map((m) => m.group(0))
              .join(':'),
        ),
        0,
        'malformed',
      ),
      'trailing whitespace': (
        lf.replaceFirst(_releaseCertSha256, '$_releaseCertSha256 '),
        0,
        'malformed',
      ),
      'apksigner exits nonzero (stdout still expected)': (
        lf,
        1,
        'apksigner verify failed',
      ),
    };

    test('QA-CERT the step enforces every fail-closed rule', () {
      expect(_certStepViolations(run()), isEmpty);
    });

    for (final c in cases.entries) {
      test('QA-CERT ${c.key}', () {
        final (out, code, reason) = c.value;
        final got = _certDecision(run(), out, code);
        if (reason == null) {
          expect(got, isNull);
        } else {
          expect(got, contains(reason));
        }
      });
    }
  });

  group('QA-CI unsafe candidates are rejected', () {
    String sub(String s, String from, String to) {
      expect(from.allMatches(s).length, 1, reason: 'anchor not unique: $from');
      return s.replaceFirst(from, to);
    }

    final mutants = <String, (String Function(String), String)>{
      'release job with contents write': (
        (s) =>
            '$s  release:\n    runs-on: ubuntu-latest\n    needs: signed-apk\n'
            '    permissions:\n      contents: write\n    steps:\n'
            '      - run: gh release create v1.1.0 qa-out/app.apk\n',
        'jobs must be exactly',
      ),
      'top-level contents write': (
        (s) => sub(
          s,
          'permissions:\n  contents: read\n\nconcurrency',
          'permissions:\n  contents: write\n\nconcurrency',
        ),
        'top-level permissions',
      ),
      'job contents write': (
        (s) => sub(
          s,
          'needs: verify\n    permissions:\n      contents: read',
          'needs: verify\n    permissions:\n      contents: write',
        ),
        'job permissions',
      ),
      'broad push branches': (
        (s) => sub(s, "      - 'qa/herguri-*'", "      - '**'"),
        'on.push.branches',
      ),
      'push tags': (
        (s) => sub(
          s,
          "      - 'qa/herguri-*'\n",
          "      - 'qa/herguri-*'\n    tags:\n      - 'v*'\n",
        ),
        'on.push must filter only branches',
      ),
      'pull_request_target trigger': (
        (s) => sub(s, 'on:\n  push:', 'on:\n  pull_request_target:\n  push:'),
        'trigger must be exactly',
      ),
      'workflow_run indirection': (
        (s) => sub(
          s,
          'on:\n  push:',
          'on:\n  workflow_run:\n    workflows: [Release]\n  push:',
        ),
        'trigger must be exactly',
      ),
      'plain pub get in verify': (
        (s) => sub(
          s,
          'run: flutter pub get --enforce-lockfile\n\n      - name: Install',
          'run: flutter pub get\n\n      - name: Install',
        ),
        '--enforce-lockfile',
      ),
      'plain pub get in signed-apk': (
        (s) => sub(
          s,
          'run: flutter pub get --enforce-lockfile\n\n      - name: Build',
          'run: flutter pub get\n\n      - name: Build',
        ),
        '--enforce-lockfile',
      ),
      'analyze resolves again': (
        (s) => sub(s, 'run: flutter analyze --no-pub', 'run: flutter analyze'),
        '--no-pub',
      ),
      'wrong expected certificate': (
        (s) => sub(
          s,
          "QA_EXPECTED_CERT_SHA256: '$_releaseCertSha256'",
          "QA_EXPECTED_CERT_SHA256: '${_releaseCertSha256.replaceFirst('3cb9', '0000')}'",
        ),
        'expected certificate',
      ),
      'certificate mismatch not fatal': (
        (s) => sub(
          s,
          'expected=\$QA_EXPECTED_CERT_SHA256)"\n            exit 1',
          'expected=\$QA_EXPECTED_CERT_SHA256)"',
        ),
        'certificate check must fail',
      ),
      'no apksigner check': (
        (s) => sub(
          s,
          r'"$build_tools/apksigner" verify --verbose --print-certs',
          'true',
        ),
        'apksigner',
      ),
      'published Signer #1-only certificate step': (
        (s) {
          final a = s.indexOf('      - name: Verify APK signing');
          final b = s.indexOf('      - name: Write QA provenance manifest');
          expect(a, greaterThan(0));
          expect(b, greaterThan(a));
          return '${s.substring(0, a)}$_publishedCertStep\n${s.substring(b)}';
        },
        'apksigner verify exit status',
      ),
      'apksigner exit status ignored': (
        (s) => sub(s, r'|| status=$?', '|| true'),
        'apksigner verify exit status',
      ),
      'apksigner failure not fatal': (
        (s) => sub(
          s,
          'verify failed (exit \$status)"\n            exit 1',
          'verify failed (exit \$status)"',
        ),
        'apksigner verify exit status',
      ),
      'CRLF output not stripped': (
        (s) => sub(
          s,
          r"tr -d '\r' < qa-out/apk-cert.txt",
          'cat qa-out/apk-cert.txt',
        ),
        'CR-stripped',
      ),
      'leaf count unchecked': (
        (s) => sub(s, r'[ "${#digests[@]}" -ne 1 ] || ', ''),
        'exactly one leaf signer',
      ),
      'extra digest lines tolerated': (
        (s) => sub(s, r' || [ "$all" -ne $((${#digests[@]} + stamp)) ]', ''),
        'exactly one leaf signer',
      ),
      'Number of signers unchecked': (
        (s) => sub(s, r' || [ "$count" != "1" ]', ''),
        'exactly one leaf signer',
      ),
      'first signer picked': (
        (s) => sub(
          s,
          r'sed -E "s/$leaf//" || true)',
          r'sed -E "s/$leaf//" | head -n 1 || true)',
        ),
        'single leaf digest',
      ),
      'duplicate signer certificates deduplicated': (
        (s) => sub(
          s,
          r'sed -E "s/$leaf//" || true)',
          r'sed -E "s/$leaf//" | sort -u || true)',
        ),
        'single leaf digest',
      ),
      'expected hash matched anywhere in the output': (
        (s) => sub(
          s,
          r'if [ "$actual" != "$QA_EXPECTED_CERT_SHA256" ]; then',
          r'if ! grep -q "$QA_EXPECTED_CERT_SHA256" qa-out/apk-cert.txt; then',
        ),
        'single leaf digest',
      ),
      'digest format unchecked': (
        (s) => sub(
          s,
          r'          if ! [[ "${digests[0]}" =~ ^[0-9a-fA-F]{64}$ ]]; then'
              '\n'
              r'            echo "::error::malformed signer certificate SHA-256 digest: ${digests[0]}"'
              '\n            exit 1\n          fi\n',
          '',
        ),
        '64 hex',
      ),
      'leaf pattern unanchored': (
        (s) => sub(s, r"leaf='^(V", r"leaf='(V"),
        'leaf signer pattern',
      ),
      'public key digest counted as leaf': (
        (s) => sub(
          s,
          r"maxSdkVersion=[0-9]+\))? certificate SHA-256 digest: '",
          r"maxSdkVersion=[0-9]+\))? (certificate|public key) SHA-256 digest: '",
        ),
        'leaf signer pattern',
      ),
      'only the build-tools 36 label accepted': (
        (s) => sub(
          s,
          r"leaf='^(V[0-9]+(\.[0-9]+)? )?Signer( #[0-9]+)?:?",
          r"leaf='^Signer( #[0-9]+)?:?",
        ),
        'leaf signer pattern',
      ),
      'missing secrets not fail-closed': (
        (s) => sub(
          s,
          'signing secrets:\$MISSING"\n            exit 1',
          'signing secrets:\$MISSING"',
        ),
        'fail-closed signing secrets check',
      ),
      'release signing not required': (
        (s) => sub(
          s,
          "IKUYO_REQUIRE_RELEASE_SIGNING: 'true'",
          "IKUYO_REQUIRE_RELEASE_SIGNING: 'false'",
        ),
        'IKUYO_REQUIRE_RELEASE_SIGNING',
      ),
      'cleanup not always': (
        (s) => sub(s, '        if: always()\n', ''),
        'cleanup',
      ),
      'secret inline in run': (
        (s) => sub(
          s,
          r'''printf 'keyAlias=%s\n' "$KEY_ALIAS"''',
          r'''printf 'keyAlias=%s\n' '${{ secrets.KEY_ALIAS }}' ''',
        ),
        'secret interpolated in run',
      ),
      'xtrace in signing setup': (
        (s) => sub(s, 'umask 077', 'set -x\n          umask 077'),
        'xtrace',
      ),
      'keystore uploaded': (
        (s) => sub(
          s,
          '            qa-out/qa-manifest.txt\n',
          '            qa-out/qa-manifest.txt\n            android/ikuyo-release.jks\n',
        ),
        'upload path',
      ),
      'ObjectBox digest unchecked': (
        (s) => sub(
          s,
          r'echo "$OBX_C_SHA256  $RUNNER_TEMP/$archive" | sha256sum -c -',
          'true',
        ),
        'ObjectBox native lib',
      ),
      'ObjectBox wrong digest': (
        (s) => sub(s, _obxSha256, _obxSha256.replaceFirst('2801', '0000')),
        'OBX_C_SHA256',
      ),
      'split-per-abi build': (
        (s) => sub(
          s,
          '$_signedBuild\n',
          '$_signedBuild --split-per-abi\n',
        ),
        'universal APK',
      ),
      'published --no-pub build (debug-mode registrant)': (
        (s) {
          const name =
              '      - name: Build universal release APK (QA, pubspec version)\n';
          final a = s.indexOf(name);
          final b = s.indexOf('\n      - name: Verify APK signing');
          expect(a, greaterThan(0));
          expect(b, greaterThan(a));
          return '${s.substring(0, a)}$name'
              '        run: flutter build apk --release --no-pub\n'
              '${s.substring(b)}';
        },
        'release registrant',
      ),
      'build without lock touch': (
        (s) => sub(s, '          touch pubspec.lock\n', ''),
        'release registrant',
      ),
      'lock change not checked': (
        (s) => sub(s, '          git diff --exit-code -- pubspec.lock\n', ''),
        'release registrant',
      ),
      'build step not errexit': (
        (s) => sub(
          s,
          '          set -euo pipefail\n          touch pubspec.lock\n',
          '          touch pubspec.lock\n',
        ),
        'release registrant',
      ),
      'verify job reads secrets': (
        (s) => sub(
          s,
          '    name: QA verify (analyze and test)\n',
          '    name: QA verify (analyze and test)\n    env:\n'
              r'      SUPABASE_URL: ${{ secrets.SUPABASE_URL }}'
              '\n',
        ),
        'secret',
      ),
      'unpinned action': (
        (s) => sub(
          s,
          'uses: actions/upload-artifact@v4',
          'uses: actions/upload-artifact@main',
        ),
        'not allowlisted',
      ),
      'signed build without verify': (
        (s) => sub(s, '    needs: verify\n', ''),
        'needs verify',
      ),
      'Flutter version drift': (
        (s) => sub(
          s,
          "FLUTTER_VERSION: '$_testedFlutter'",
          "FLUTTER_VERSION: '3.38.8'",
        ),
        'FLUTTER_VERSION',
      ),
      'git push step': (
        (s) => sub(
          s,
          'cat qa-out/qa-manifest.txt',
          'cat qa-out/qa-manifest.txt\n          git push origin HEAD:main',
        ),
        'git push',
      ),
      'unparseable structure': (
        (s) => sub(s, 'jobs:\n  verify:', 'jobs:\n\tverify:'),
        'unparseable',
      ),
    };

    for (final m in mutants.entries) {
      test('QA-CI rejects ${m.key}', () {
        final mutated = m.value.$1(valid());
        final out = _qaWorkflowViolations(mutated);
        expect(out.join('\n'), contains(m.value.$2), reason: out.join('\n'));
        expect(
          _qaWorkflowViolations(mutated.replaceAll('\n', '\r\n')),
          isNotEmpty,
        );
      });
    }
  });
}
