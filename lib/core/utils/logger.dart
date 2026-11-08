import 'package:flutter/foundation.dart';
import 'package:talker_flutter/talker_flutter.dart';

// * Global Talker instance
late final Talker talker;

// * Release build tidak mencetak log ke console (data keuangan, P04)
TalkerSettings loggerSettings({bool release = kReleaseMode}) =>
    TalkerSettings(useConsoleLogs: !release, enabled: true);

// * Initialize Talker for app-wide logging
void initLogger() {
  talker = TalkerFlutter.init(
    settings: loggerSettings(),
    logger: TalkerLogger(settings: TalkerLoggerSettings(enableColors: true)),
  );
}
