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

// * Extension methods for logging from any class
extension LoggerExtension on Object {
  // ? General purpose logging
  void logInfo(String message) => talker.info('[$runtimeType] $message');
  void logDebug(String message) => talker.debug('[$runtimeType] $message');
  void logWarning(String message) => talker.warning('[$runtimeType] $message');
  void logCritical(String message) =>
      talker.critical('[$runtimeType] $message');

  // ! Error handling with stack trace
  void logError(String message, [Object? error, StackTrace? stackTrace]) {
    talker.error('[$runtimeType] $message', error, stackTrace);
  }

  void logException(
    Object exception, [
    StackTrace? stackTrace,
    String? message,
  ]) {
    final msg = message != null ? '[$runtimeType] $message' : '[$runtimeType]';
    talker.handle(exception, stackTrace, msg);
  }

  // * Domain-specific logging methods
  void logData(String action, [Map<String, dynamic>? data]) {
    final msg = data != null ? '$action: $data' : action;
    talker.info('[$runtimeType][DATA] $msg');
  }

  void logDomain(String operation, [String? details]) {
    final msg = details != null ? '$operation - $details' : operation;
    talker.debug('[$runtimeType][DOMAIN] $msg');
  }

  void logPresentation(String event, [String? details]) {
    final msg = details != null ? '$event - $details' : event;
    talker.debug('[$runtimeType][UI] $msg');
  }

  void logService(String action, [String? details]) {
    final msg = details != null ? '$action - $details' : action;
    talker.info('[$runtimeType][SERVICE] $msg');
  }
}
