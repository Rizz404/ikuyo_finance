// * Translation merger script
// * Scans lib/**/translations/*.json and deep-merges them into assets/translations/
// *
// * Usage: dart run tools/merge_translations.dart
// *
// * Source folders (auto-discovered, no manual edit needed):
// *   lib/core/translations/        → core keys (app, common, settings, currency)
// *   lib/shared/translations/      → shared widget keys
// *   lib/features/*/translations/  → feature-specific keys
// *
// * Output: assets/translations/*.json  (consumed by easy_localization)

import 'dart:convert';
import 'dart:io';

void main() async {
  final projectRoot = _findProjectRoot();
  final libDir = Directory('$projectRoot/lib');
  final outputDir = Directory('$projectRoot/assets/translations');

  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  // * Collect all translation source files grouped by locale filename
  final Map<String, List<File>> byLocale = {};

  await for (final entity in libDir.list(recursive: true)) {
    if (entity is! File) continue;
    if (!entity.path.endsWith('.json')) continue;

    // * Only files inside a folder named "translations"
    final parts = entity.path.replaceAll('\\', '/').split('/');
    final parentDir = parts[parts.length - 2];
    if (parentDir != 'translations') continue;

    final locale = parts.last; // e.g. en-US.json
    byLocale.putIfAbsent(locale, () => []).add(entity);
  }

  if (byLocale.isEmpty) {
    print('⚠ No translation source files found under lib/**/translations/');
    return;
  }

  // * Merge and write each locale
  for (final entry in byLocale.entries) {
    final locale = entry.key;
    final files = entry.value;

    final Map<String, dynamic> merged = {};
    final List<String> sourcePaths = [];

    for (final file in files) {
      try {
        final content = file.readAsStringSync();
        final Map<String, dynamic> data = jsonDecode(content);
        _deepMerge(merged, data);

        // * Show relative path for readability
        final rel = file.path
            .replaceAll('\\', '/')
            .replaceAll('$projectRoot/', '');
        sourcePaths.add(rel);
      } catch (e) {
        print('  ✗ Failed to parse ${file.path}: $e');
      }
    }

    // * Write merged output — top-level keys sorted alphabetically
    final outputFile = File('${outputDir.path}/$locale');
    const encoder = JsonEncoder.withIndent('  ');
    outputFile.writeAsStringSync('${encoder.convert(_sortMap(merged))}\n');

    print('✓ $locale  ← merged ${files.length} file(s)');
    for (final src in sourcePaths) {
      print('    $src');
    }
  }

  print('\nDone → assets/translations/');
}

// * Deep-merges [source] into [target], recursing into nested maps
void _deepMerge(Map<String, dynamic> target, Map<String, dynamic> source) {
  for (final key in source.keys) {
    final sourceVal = source[key];
    final targetVal = target[key];

    if (sourceVal is Map<String, dynamic> &&
        targetVal is Map<String, dynamic>) {
      _deepMerge(targetVal, sourceVal);
    } else {
      if (targetVal != null && targetVal != sourceVal) {
        // ! Conflict: later source wins; print a warning
        print(
          '  ⚠ Key conflict "$key": overwriting "$targetVal" → "$sourceVal"',
        );
      }
      target[key] = sourceVal;
    }
  }
}

// * Walk up from script location to find the pubspec.yaml root
String _findProjectRoot() {
  var dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Could not find project root (pubspec.yaml not found)');
    }
    dir = parent;
  }
  return dir.path.replaceAll('\\', '/');
}

// * Recursively sorts map keys alphabetically (top-level and nested)
Map<String, dynamic> _sortMap(Map<String, dynamic> map) {
  final sorted = Map.fromEntries(
    map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
  return sorted.map((key, value) {
    if (value is Map<String, dynamic>) return MapEntry(key, _sortMap(value));
    return MapEntry(key, value);
  });
}
