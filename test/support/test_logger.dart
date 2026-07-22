import 'package:talker_flutter/talker_flutter.dart';
import 'package:ikuyo_finance/core/utils/logger.dart' as app_logger;

bool _initialized = false;

/// Initializes the app's global `talker` logger once per test isolate,
/// with console output disabled to keep `flutter test` output readable.
/// Repository implementations call `logService`/`logInfo`/`logError`
/// unconditionally, so anything exercising them needs this booted first.
void bootstrapTestLogger() {
  if (_initialized) return;
  app_logger.talker = TalkerFlutter.init(
    settings: TalkerSettings(useConsoleLogs: false, enabled: true),
  );
  _initialized = true;
}
