import 'package:talker_flutter/talker_flutter.dart';

// * Global Talker instance
late final Talker talker;

// * Initialize Talker for app-wide logging
void initLogger() {
  talker = TalkerFlutter.init(
    settings: TalkerSettings(useConsoleLogs: true, enabled: true),
    logger: TalkerLogger(settings: TalkerLoggerSettings(enableColors: true)),
  );
}
