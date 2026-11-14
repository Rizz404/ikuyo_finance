// Regression: REL-PREP (release.yml vs the CI-proven qa.yml). The release
// build job ran `flutter test` without the pinned ObjectBox native library
// that the host tests load (qa.yml installs a digest-verified
// libobjectbox.so), and it wrote the production Supabase .env plus the
// keystore before analyze/test, so host tests saw real backend config and
// signing material. Release notes still claimed API 23 although Flutter
// 3.44.5 builds with minSdkVersion 24, the release job published straight
// to --latest without any signer check, and the build number came from
// pubspec independent of the tag. The release workflow must: test against
// a synthetic loopback .env with the pinned ObjectBox lib, write production
// config and signing material only after tests and only for the build,
// verify every APK (historical signer, package, versionCode, minSdk,
// packaged production .env) fail closed, always remove signing material,
// check the downloaded artifact hashes and only ever create a DRAFT release
// whose tag matches the pubspec version.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _releasePath = '.github/workflows/release.yml';
const _qaPath = '.github/workflows/qa.yml';
const _historicalCertSha256 =
    '3cb92848113a05569dc0647b1d1563d094b47ad167f0ee2ffdf382591c546feb';
const _appId = 'rizz.learn.finance.ikuyo_finance';
const _releaseVersion = '1.1.1+3';
// * build number of the published v1.1.0 (pubspec 1.1.0+2)
const _previousBuildNumber = 2;
const _minSdk = '24';

class _Step {
  _Step(this.job, this.name, this.body);

  final String job;
  final String name;
  final String body;

  String get run {
    final lines = body.split('\n');
    final i = lines.indexWhere((l) => RegExp(r'^\s{8}run:').hasMatch(l));
    if (i < 0) return '';
    final inline = lines[i].replaceFirst(RegExp(r'^\s{8}run:\s*'), '');
    if (inline.isNotEmpty && inline != '|') return inline;
    return lines
        .skip(i + 1)
        .takeWhile((l) => l.trim().isEmpty || l.startsWith('          '))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .join('\n');
  }

  bool get usesSecrets => body.contains(r'${{ secrets.');
}

/// Steps of every job, in file order (jobs at 2, steps at 6 spaces).
List<_Step> _steps(String source) {
  final lines = source.replaceAll('\r\n', '\n').split('\n');
  final out = <_Step>[];
  String? job;
  String? name;
  final body = <String>[];
  void flush() {
    final j = job, n = name;
    if (j != null && n != null) out.add(_Step(j, n, body.join('\n')));
    name = null;
    body.clear();
  }

  var inJobs = false;
  for (final l in lines) {
    if (l == 'jobs:') {
      inJobs = true;
      continue;
    }
    if (!inJobs) continue;
    final j = RegExp(r'^  ([\w-]+):\s*$').firstMatch(l);
    if (j != null) {
      flush();
      job = j.group(1);
      continue;
    }
    final s = RegExp(r'^      - name: (.*)$').firstMatch(l);
    if (s != null) {
      flush();
      name = s.group(1)!.trim();
      continue;
    }
    if (name != null) body.add(l);
  }
  flush();
  return out;
}

String? _env(String source, String key) => RegExp(
  "^  $key: '([^']*)'\\s*\$",
  multiLine: true,
).firstMatch(source.replaceAll('\r\n', '\n'))?.group(1);

String? _leaf(String run) =>
    RegExp(r"^leaf='([^'\n]+)'$", multiLine: true).firstMatch(run)?.group(1);

/// Lines the build-job PROD_ENV_CHECK_PY validator must contain verbatim.
const _validatorLines = [
  'import ipaddress',
  'import urllib.parse',
  '    sys.exit(1)',
  r'''if not re.fullmatch(rb"(?:[\x21-\x7e]+\n)+", raw):''',
  'pairs = [line.split("=", 1) for line in text.splitlines()]',
  'if any(len(p) != 2 for p in pairs):',
  'if sorted(k for k, _ in pairs) != ["SUPABASE_ANON_KEY", "SUPABASE_URL"]:',
  'markers = ("127.0.0.1", "localhost", "synthetic", "placeholder", "changeme", "not-a-secret")',
  'if any(m in url.lower() or m in key.lower() for m in markers):',
  r'''if not re.fullmatch(r"[A-Za-z0-9_.~+/=-]{20,}", key):''',
  'parts = urllib.parse.urlsplit(url)',
  'if parts.scheme != "https" or not host or "@" in parts.netloc or parts.query or parts.fragment or parts.path not in ("", "/") or port == 0:',
  'ip = ipaddress.ip_address(host)',
  'if not ip.is_global:',
  'if labels[-1] in reserved or ".".join(labels[-2:]) in ("example.com", "example.net", "example.org"):',
];

/// The PROD_ENV_CHECK_PY body of the build job, if it has every guard.
String? prodEnvValidator(String source) {
  final lines = source.replaceAll('\r\n', '\n').split('\n');
  final i = lines.indexOf('      PROD_ENV_CHECK_PY: |');
  if (i < 0) return null;
  final body = lines
      .skip(i + 1)
      .takeWhile((l) => l.trim().isEmpty || l.startsWith('        '))
      .map((l) => l.length >= 8 ? l.substring(8) : '')
      .toList();
  if (!body.contains('def reject(reason):')) return null;
  for (final want in _validatorLines) {
    final hit = body.indexWhere((l) => l.trim() == want.trim());
    if (hit < 0) return null;
    // * every guarded condition must be followed by a reject()
    if (want.trim().startsWith('if ') &&
        (hit + 1 >= body.length ||
            !body[hit + 1].trimLeft().startsWith('reject('))) {
      return null;
    }
  }
  if (body.any(
    (l) => RegExp(r'\bprint\(.*\b(url|key|raw|text|config)\b').hasMatch(l),
  )) {
    return null;
  }
  return body.join('\n');
}

/// Every release-preparation rule; empty means the workflow is acceptable.
List<String> releaseViolations(String source, String qa) {
  final v = <String>[];
  final text = source.replaceAll('\r\n', '\n');
  final steps = _steps(text);
  final build = steps.where((s) => s.job == 'build').toList();
  final release = steps.where((s) => s.job == 'release').toList();
  int at(List<_Step> s, bool Function(_Step) p) => s.indexWhere(p);

  final pubGet = at(build, (s) => s.run.contains('flutter pub get'));
  final analyze = at(build, (s) => s.run.startsWith('flutter analyze'));
  final tests = at(build, (s) => s.run.startsWith('flutter test'));
  final builds = [
    for (var i = 0; i < build.length; i++)
      if (build[i].run.contains('flutter build apk')) i,
  ];
  if (pubGet < 0 || analyze < 0 || tests < 0 || builds.length != 2) {
    return ['build job must pub get, analyze, test and build twice'];
  }

  // * host tests: pinned ObjectBox lib, same as the CI-proven qa.yml
  for (final k in ['OBX_C_VERSION', 'OBX_C_SHA256']) {
    if (_env(text, k) == null || _env(text, k) != _env(qa, k)) {
      v.add('$k must equal qa.yml (${_env(qa, k)}), got ${_env(text, k)}');
    }
  }
  final obx = at(build, (s) => s.run.contains('libobjectbox.so" lib/'));
  final obxRun = obx < 0 ? '' : build[obx].run;
  if (obx < pubGet ||
      obx > tests ||
      !obxRun.contains('set -euo pipefail') ||
      !RegExp(r'echo "\$OBX_C_SHA256 .*\| sha256sum -c -').hasMatch(obxRun) ||
      obxRun.indexOf('sha256sum -c') > obxRun.indexOf('cp ')) {
    v.add('ObjectBox native lib must be digest-verified before flutter test');
  }

  // * no backend secrets or signing material before or during host tests
  final synthetic = at(
    build,
    (s) =>
        s.run.contains('> .env') &&
        s.run.contains('http://127.0.0.1') &&
        !s.usesSecrets,
  );
  if (synthetic < 0 || synthetic > pubGet) {
    v.add('a synthetic loopback .env must be created before pub get');
  }
  for (var i = 0; i <= tests; i++) {
    final s = build[i];
    if (!s.usesSecrets) continue;
    final presenceOnly =
        s.name == 'Verify required secrets' &&
        !RegExp(r'>|base64|printf').hasMatch(s.run);
    if (!presenceOnly) {
      v.add('secrets used before host tests in step "${s.name}"');
    }
  }
  final prodEnv = at(
    build,
    (s) =>
        s.usesSecrets &&
        s.body.contains(r'SUPABASE_URL: ${{ secrets.SUPABASE_URL }}') &&
        s.run.contains('> .env'),
  );
  final signing = at(
    build,
    (s) => s.run.contains('base64 --decode > android/ikuyo-release.jks'),
  );
  if (prodEnv <= tests || prodEnv > builds.first) {
    v.add('production .env must be written after tests, before the build');
  }
  if (signing <= tests || signing > builds.first) {
    v.add('release signing must be set up after tests, before the build');
  }
  if (signing >= 0 &&
      (!build[signing].run.contains('set -euo pipefail') ||
          !build[signing].run.contains('umask 077'))) {
    v.add('signing setup must be errexit with umask 077');
  }
  if (!text.contains("IKUYO_REQUIRE_RELEASE_SIGNING: 'true'")) {
    v.add('IKUYO_REQUIRE_RELEASE_SIGNING must stay true');
  }

  // * every APK verified fail closed before upload
  if (_env(text, 'RELEASE_EXPECTED_CERT_SHA256') != _historicalCertSha256 ||
      _env(qa, 'QA_EXPECTED_CERT_SHA256') != _historicalCertSha256) {
    v.add('expected certificate must be the historical release signer');
  }
  if (_env(text, 'APP_ID') != _appId) v.add('APP_ID must be $_appId');
  if (_env(text, 'MIN_SDK') != _minSdk) v.add('MIN_SDK must be $_minSdk');
  final verify = at(build, (s) => s.run.contains('apksigner" verify'));
  final upload = at(build, (s) => s.body.contains('actions/upload-artifact@'));
  final vr = verify < 0 ? '' : build[verify].run;
  final qaCert = _steps(qa).where((s) => s.run.contains('--print-certs'));
  final qaLeaf = qaCert.isEmpty ? null : _leaf(qaCert.first.run);
  bool fatal(String guard) => RegExp(
    '${RegExp.escape(guard)}\n(?:\\w+="[^\n]*\n)?echo "::error::[^\n]*\nexit 1\n',
  ).hasMatch('$vr\n');
  final certOk =
      verify > builds.last &&
      verify < upload &&
      vr.contains('set -euo pipefail') &&
      qaLeaf != null &&
      _leaf(vr) == qaLeaf &&
      vr.contains(
        'for abi in universal:0 armeabi-v7a:1 arm64-v8a:2 x86_64:4',
      ) &&
      vr.contains(r'code=$(( ${abi#*:} * 1000 + BUILD_NUMBER ))') &&
      vr.contains(r'|| status=$?') &&
      fatal(r'if [ "$status" -ne 0 ]; then') &&
      fatal(
        r'if [ "${#digests[@]}" -ne 1 ] || [ "$all" -ne $((${#digests[@]} + stamp)) ] '
        r'|| [ "$count" != "1" ]; then',
      ) &&
      fatal(r'if ! [[ "${digests[0]}" =~ ^[0-9a-fA-F]{64}$ ]]; then') &&
      fatal(r'if [ "$actual" != "$RELEASE_EXPECTED_CERT_SHA256" ]; then') &&
      !RegExp(
        r'\bhead\b|\buniq\b|sort -u',
      ).hasMatch(vr.replaceFirst(r'sort -V | tail -n 1', ''));
  if (!certOk) {
    v.add('every APK must pass the qa.yml fail-closed signer check');
  }
  if (!vr.contains(
        r'''want="package: name='$APP_ID' versionCode='$code' versionName='$BUILD_NAME'"''',
      ) ||
      !fatal(r'''if [ "${pkg:0:${#want}}" != "$want" ]; then''') ||
      !fatal(
        r'''if [ "$(grep -cx "minSdkVersion:'$MIN_SDK'" <<< "$badging" || true)" != "1" ]; then''',
      )) {
    v.add('every APK must match package, versionCode, versionName and minSdk');
  }
  final check = r'python3 -c "$PROD_ENV_CHECK_PY"';
  if (prodEnvValidator(text) == null ||
      !fatal('if ! $check .env; then') ||
      vr.indexOf('if ! $check .env; then') > vr.indexOf('for abi in') ||
      !fatal(
        r'if ! unzip -p "$apk" assets/flutter_assets/.env | cmp -s - .env; then',
      ) ||
      !fatal(
        'if ! unzip -p "\$apk" assets/flutter_assets/.env | $check -; then',
      )) {
    v.add('every APK must package the production (non-synthetic) .env');
  }
  final pr = prodEnv < 0 ? '' : build[prodEnv].run;
  final secretsCheck = RegExp(
    r'''^if ! printf 'SUPABASE_URL=%s\\nSUPABASE_ANON_KEY=%s\\n' "\$SUPABASE_URL" "\$SUPABASE_ANON_KEY" \| '''
    '${RegExp.escape(check)}'
    r''' -; then\necho "::error::[^\n]*\nexit 1\n''',
    multiLine: true,
  ).firstMatch('$pr\n');
  if (secretsCheck == null ||
      secretsCheck.start > pr.indexOf('" > .env') ||
      !pr.contains('set -euo pipefail')) {
    v.add('backend secrets must be validated before the production .env');
  }
  if (!vr.contains("universal) want_abis='arm64-v8a armeabi-v7a x86_64' ;;") ||
      !vr.contains(r'*) want_abis="${abi%%:*}" ;;') ||
      !vr.contains(
        r'''abis="$(grep '^native-code: ' <<< "$badging" | sed -e 's/^native-code: //' -e "s/'//g" | tr ' ' '\n' | sed '/^$/d' | LC_ALL=C sort | paste -sd ' ' - || true)"''',
      ) ||
      !fatal(
        r'''if [ "$native" != "1" ] || grep -q '^alt-native-code' <<< "$badging" || [ "$abis" != "$want_abis" ]; then''',
      )) {
    v.add('every APK must carry exactly its expected native ABIs');
  }
  if (RegExp(r'cat \.env|echo "\$SUPABASE|set -[a-wyz]*x').hasMatch(text)) {
    v.add('backend config or secrets must never be printed');
  }
  if (!vr.contains('sha256sum ikuyo-finance-')) {
    v.add('APK SHA-256 manifest must be produced');
  }
  final cleanup = at(
    build,
    (s) =>
        s.body.contains('if: always()') &&
        RegExp(
          r'rm -f android/ikuyo-release\.jks android/key\.properties \.env',
        ).hasMatch(s.run),
  );
  if (cleanup < 0 || cleanup < signing || cleanup > upload) {
    v.add('signing material and .env must be removed if: always()');
  }
  if (upload >= 0 &&
      (!build[upload].body.contains('SHA256SUMS.txt') ||
          !build[upload].body.contains('if-no-files-found: error') ||
          RegExp(
            r'\.jks|key\.properties|\.env',
          ).hasMatch(build[upload].body))) {
    v.add('upload must be exactly APKs plus SHA256SUMS and fail when missing');
  }

  // * version: tag == pubspec build name, build number from pubspec, monotonic
  final resolve = at(build, (s) => s.name == 'Resolve version');
  final rv = resolve < 0 ? '' : build[resolve].run;
  if (!rv.contains('set -euo pipefail') ||
      !rv.contains(r'''grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$';''') ||
      !rv.contains(r'BUILD_NAME="${PUBSPEC_VERSION%%+*}"') ||
      !rv.contains(r'BUILD_NUMBER="${PUBSPEC_VERSION#*+}"') ||
      !rv.contains(r'if [ "$VERSION" != "v$BUILD_NAME" ]; then') ||
      !rv.contains(
        r'if [ -z "$TAG_COMMIT" ] || [ "$TAG_COMMIT" != "$COMMIT" ]; then',
      ) ||
      !rv.contains(r'if ! [ "$BUILD_NUMBER" -gt "${PREV_BUILD:-0}" ]; then')) {
    v.add('version must come from pubspec and match the tag at HEAD');
  }

  // * draft only, downloaded hashes checked, no overwrite, notes not stale
  final hashes = at(
    release,
    (s) => s.run.contains('sha256sum -c SHA256SUMS.txt'),
  );
  final create = at(release, (s) => s.run.contains('gh release create'));
  final cr = create < 0 ? '' : release[create].run;
  if (create < 0 ||
      !cr.contains('--draft') ||
      !cr.contains('--verify-tag') ||
      cr.contains('--latest') ||
      !cr.contains('refusing to delete or overwrite') ||
      !cr.contains('"apks/SHA256SUMS.txt"')) {
    v.add('the release must be created as a draft only, never --latest');
  }
  if (RegExp(
    r'gh release (edit|delete|upload)|--draft=false|--clobber',
  ).hasMatch(text)) {
    v.add('the workflow must not publish, edit, delete or clobber releases');
  }
  if (hashes < 0 || hashes > create) {
    v.add('downloaded APK hashes must be verified before the draft');
  }
  if (text.contains('API 23') || !text.contains(r'(API ${MIN_SDK})')) {
    v.add('release notes must state the actual minimum API $_minSdk');
  }
  if (RegExp(r'contents:\s*write').allMatches(text).length != 1 ||
      text.indexOf('contents: write') < text.indexOf('\n  release:')) {
    v.add('contents: write only on the release job');
  }
  return v;
}

void main() {
  String read(String p) => File(p).readAsStringSync().replaceAll('\r\n', '\n');
  final workflow = read(_releasePath);
  final qa = read(_qaPath);

  test('REL-PREP the release workflow satisfies the release policy', () {
    expect(releaseViolations(workflow, qa), isEmpty);
  });

  test('REL-PREP the policy is independent of LF/CRLF checkouts', () {
    expect(
      releaseViolations(
        workflow.replaceAll('\n', '\r\n'),
        qa.replaceAll('\n', '\r\n'),
      ),
      isEmpty,
    );
  });

  test('REL-PREP pubspec carries the next patch release version', () {
    final version = RegExp(
      r'^version:\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(read('pubspec.yaml'))!.group(1)!;
    expect(version, _releaseVersion);
    expect(
      int.parse(version.split('+').last),
      greaterThan(_previousBuildNumber),
    );
  });

  test('REL-PREP Android minSdk follows the Flutter default stated as 24', () {
    final gradle = read('android/app/build.gradle.kts');
    expect(gradle, contains('minSdk = flutter.minSdkVersion'));
    expect(gradle, contains('versionCode = flutter.versionCode'));
    expect(gradle, contains('versionName = flutter.versionName'));
    expect(gradle, contains('applicationId = "$_appId"'));
  });

  group('REL-PREP unsafe release candidates are rejected', () {
    String sub(String s, String from, String to) {
      expect(from.allMatches(s).length, 1, reason: 'anchor not unique: $from');
      return s.replaceFirst(from, to);
    }

    String moveStep(String s, String name, String before) {
      final start = s.indexOf('      - name: $name\n');
      final end = s.indexOf('\n      - name: ', start + 1) + 1;
      expect(start, greaterThan(0), reason: name);
      final block = s.substring(start, end);
      final rest = s.replaceFirst(block, '');
      final at = rest.indexOf('      - name: $before\n');
      expect(at, greaterThan(0), reason: before);
      return '${rest.substring(0, at)}$block${rest.substring(at)}';
    }

    String dropStep(String s, String name) {
      final start = s.indexOf('      - name: $name\n');
      final end = s.indexOf('\n      - name: ', start + 1) + 1;
      expect(start, greaterThan(0), reason: name);
      return s.replaceRange(start, end, '');
    }

    final mutants = <String, (String Function(String), String)>{
      'published auto-latest release': (
        (s) => sub(s, '            --draft \\\n', '            --latest \\\n'),
        'draft only',
      ),
      'draft publish step': (
        (s) =>
            '$s\n\n      - name: Publish\n        run: gh release edit v1 --draft=false\n',
        'must not publish',
      ),
      'ObjectBox lib missing for host tests': (
        (s) => dropStep(s, 'Install ObjectBox native library (host tests)'),
        'ObjectBox native lib',
      ),
      'ObjectBox digest unchecked': (
        (s) => sub(
          s,
          r'echo "$OBX_C_SHA256  $RUNNER_TEMP/$archive" | sha256sum -c -',
          'true',
        ),
        'ObjectBox native lib',
      ),
      'production .env before tests': (
        (s) => moveStep(s, 'Create production .env (build only)', 'Analyze'),
        'secrets used before host tests',
      ),
      'keystore before tests': (
        (s) => moveStep(s, 'Setup release signing', 'Flutter pub get (locked)'),
        'secrets used before host tests',
      ),
      'no synthetic .env': (
        (s) => dropStep(s, 'Create synthetic loopback .env (analyze and test)'),
        'synthetic loopback .env',
      ),
      'APK verification removed': (
        (s) => dropStep(
          s,
          'Verify APKs (signer, package, version, minSdk, backend config)',
        ),
        'fail-closed signer check',
      ),
      'other expected certificate': (
        (s) => sub(
          s,
          "RELEASE_EXPECTED_CERT_SHA256: '$_historicalCertSha256'",
          "RELEASE_EXPECTED_CERT_SHA256: '${'0' * 64}'",
        ),
        'historical release signer',
      ),
      'signer mismatch not fatal': (
        (s) => sub(
          s,
          'expected=\$RELEASE_EXPECTED_CERT_SHA256)"\n              exit 1',
          'expected=\$RELEASE_EXPECTED_CERT_SHA256)"',
        ),
        'fail-closed signer check',
      ),
      'apksigner exit ignored': (
        (s) => sub(s, r'|| status=$?', '|| true'),
        'fail-closed signer check',
      ),
      'first signer picked': (
        (s) => sub(
          s,
          r'sed -E "s/$leaf//" || true)',
          r'sed -E "s/$leaf//" | head -n 1 || true)',
        ),
        'fail-closed signer check',
      ),
      'only universal APK checked': (
        (s) => sub(
          s,
          'for abi in universal:0 armeabi-v7a:1 arm64-v8a:2 x86_64:4',
          'for abi in universal:0',
        ),
        'fail-closed signer check',
      ),
      'versionCode not checked': (
        (s) => sub(
          s,
          '''            if [ "\${pkg:0:\${#want}}" != "\$want" ]; then''',
          '''            if false; then''',
        ),
        'package, versionCode',
      ),
      'minSdk not checked': (
        (s) => sub(s, "minSdkVersion:'\$MIN_SDK'", 'minSdkVersion'),
        'package, versionCode',
      ),
      'stale minSdk': (
        (s) => sub(s, "MIN_SDK: '24'", "MIN_SDK: '23'"),
        'MIN_SDK must be 24',
      ),
      'stale API 23 notes': (
        (s) => sub(
          s,
          r'Android 7.0 (API ${MIN_SDK}) or higher',
          'Android 6.0 (API 23) or higher',
        ),
        'actual minimum API',
      ),
      'packaged .env not compared': (
        (s) => sub(
          s,
          ' assets/flutter_assets/.env | cmp -s - .env; then',
          ' assets/flutter_assets/.env | cmp -s - .env || true; then',
        ),
        'production (non-synthetic) .env',
      ),
      'packaged .env not validated': (
        (s) => sub(
          s,
          'if ! unzip -p "\$apk" assets/flutter_assets/.env | python3 -c "\$PROD_ENV_CHECK_PY" -; then',
          'if false; then',
        ),
        'production (non-synthetic) .env',
      ),
      'workspace .env not validated': (
        (s) => sub(
          s,
          '          if ! python3 -c "\$PROD_ENV_CHECK_PY" .env; then\n'
              '            echo "::error::workspace .env is not the production build config"\n'
              '            exit 1\n',
          '          if ! python3 -c "\$PROD_ENV_CHECK_PY" .env; then\n'
              '            echo "::error::workspace .env is not the production build config"\n',
        ),
        'production (non-synthetic) .env',
      ),
      'secrets written before validation': (
        (s) => sub(
          s,
          '          # * validate the secret values',
          "          printf 'SUPABASE_URL=%s\\n' \"\$SUPABASE_URL\" > .env\n"
              '          # * validate the secret values',
        ),
        'validated before the production .env',
      ),
      'secrets not validated': (
        (s) => sub(
          s,
          '"\$SUPABASE_ANON_KEY" | python3 -c "\$PROD_ENV_CHECK_PY" -; then',
          '"\$SUPABASE_ANON_KEY" | true; then',
        ),
        'validated before the production .env',
      ),
      'validator missing': (
        (s) => sub(
          s,
          '      PROD_ENV_CHECK_PY: |\n',
          '      PROD_ENV_CHECK_OFF: |\n',
        ),
        'production (non-synthetic) .env',
      ),
      'validator accepts http': (
        (s) => sub(
          s,
          'if parts.scheme != "https" or not host',
          'if parts.scheme not in ("http", "https") or not host',
        ),
        'production (non-synthetic) .env',
      ),
      'validator accepts loopback IP': (
        (s) => sub(
          s,
          '            if not ip.is_global:\n',
          '            if ip.is_multicast:\n',
        ),
        'production (non-synthetic) .env',
      ),
      'validator accepts localhost name': (
        (s) => sub(
          s,
          '        markers = ("127.0.0.1", "localhost", ',
          '        markers = ("127.0.0.1", ',
        ),
        'production (non-synthetic) .env',
      ),
      'validator accepts duplicate keys': (
        (s) => sub(
          s,
          'if sorted(k for k, _ in pairs) != ["SUPABASE_ANON_KEY", "SUPABASE_URL"]:',
          'if not {"SUPABASE_ANON_KEY", "SUPABASE_URL"} <= {k for k, _ in pairs}:',
        ),
        'production (non-synthetic) .env',
      ),
      'validator accepts whitespace key': (
        (s) => sub(
          s,
          r'''if not re.fullmatch(rb"(?:[\x21-\x7e]+\n)+", raw):''',
          r'''if not re.fullmatch(rb"(?:[\x20-\x7e]*\n)*", raw):''',
        ),
        'production (non-synthetic) .env',
      ),
      'validator reject not fatal': (
        (s) => sub(
          s,
          '            print("::error::production .env rejected: " + reason)\n            sys.exit(1)\n',
          '            print("::error::production .env rejected: " + reason)\n',
        ),
        'production (non-synthetic) .env',
      ),
      'validator prints value': (
        (s) => sub(
          s,
          '        url, key = config["SUPABASE_URL"], config["SUPABASE_ANON_KEY"]\n',
          '        url, key = config["SUPABASE_URL"], config["SUPABASE_ANON_KEY"]\n        print(url)\n',
        ),
        'production (non-synthetic) .env',
      ),
      'native ABI not checked': (
        (s) => sub(
          s,
          r'''if [ "$native" != "1" ] || grep -q '^alt-native-code' <<< "$badging" || [ "$abis" != "$want_abis" ]; then''',
          'if false; then',
        ),
        'expected native ABIs',
      ),
      'universal ABI set incomplete': (
        (s) => sub(
          s,
          "universal) want_abis='arm64-v8a armeabi-v7a x86_64' ;;",
          "universal) want_abis='arm64-v8a' ;;",
        ),
        'expected native ABIs',
      ),
      'cleanup not always': (
        (s) => sub(
          s,
          '      - name: Remove CI signing material and backend config\n        if: always()\n',
          '      - name: Remove CI signing material and backend config\n',
        ),
        'removed if: always()',
      ),
      'keystore uploaded': (
        (s) => sub(
          s,
          '            build/app/outputs/flutter-apk/SHA256SUMS.txt\n',
          '            build/app/outputs/flutter-apk/SHA256SUMS.txt\n            android/ikuyo-release.jks\n',
        ),
        'upload must be exactly',
      ),
      'build number not from pubspec': (
        (s) => sub(
          s,
          r'BUILD_NUMBER="${PUBSPEC_VERSION#*+}"',
          r'BUILD_NUMBER="${GITHUB_RUN_NUMBER}"',
        ),
        'version must come from pubspec',
      ),
      'tag not matched to pubspec': (
        (s) => sub(
          s,
          r'if [ "$VERSION" != "v$BUILD_NAME" ]; then',
          'if false; then',
        ),
        'version must come from pubspec',
      ),
      'tag commit unchecked': (
        (s) => sub(
          s,
          r'if [ -z "$TAG_COMMIT" ] || [ "$TAG_COMMIT" != "$COMMIT" ]; then',
          'if false; then',
        ),
        'version must come from pubspec',
      ),
      'downloaded hashes unchecked': (
        (s) => dropStep(s, 'Verify downloaded artifact hashes'),
        'downloaded APK hashes',
      ),
      'release overwrite': (
        (s) => sub(
          s,
          'echo "::error::Release \${VERSION} already exists; refusing to delete or overwrite it"\n            exit 1\n',
          'gh release delete "\${VERSION}" --yes\n',
        ),
        'draft only',
      ),
      'secret printed': (
        (s) => sub(
          s,
          'set -euo pipefail\n          rm -f lib/libobjectbox.so',
          'cat .env\n          rm -f lib/libobjectbox.so',
        ),
        'never be printed',
      ),
    };

    for (final m in mutants.entries) {
      test('REL-PREP rejects ${m.key}', () {
        final mutated = m.value.$1(workflow);
        final out = releaseViolations(mutated, qa);
        expect(out.join('\n'), contains(m.value.$2), reason: out.join('\n'));
      });
    }
  });
}
