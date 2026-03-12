import 'dart:convert';

enum BackupFrequency { daily, weekly, monthly }

class BackupScheduleSettings {
  final bool isEnabled;
  final int hour;
  final int minute;
  final BackupFrequency frequency;

  const BackupScheduleSettings({
    this.isEnabled = false,
    this.hour = 2,
    this.minute = 0,
    this.frequency = BackupFrequency.daily,
  });

  static const BackupScheduleSettings defaultSettings =
      BackupScheduleSettings();

  BackupScheduleSettings copyWith({
    bool? isEnabled,
    int? hour,
    int? minute,
    BackupFrequency? frequency,
  }) => BackupScheduleSettings(
    isEnabled: isEnabled ?? this.isEnabled,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    frequency: frequency ?? this.frequency,
  );

  Map<String, dynamic> toJson() => {
    'isEnabled': isEnabled,
    'hour': hour,
    'minute': minute,
    'frequency': frequency.index,
  };

  factory BackupScheduleSettings.fromJson(Map<String, dynamic> json) =>
      BackupScheduleSettings(
        isEnabled: json['isEnabled'] as bool? ?? false,
        hour: json['hour'] as int? ?? 2,
        minute: json['minute'] as int? ?? 0,
        frequency: BackupFrequency.values[json['frequency'] as int? ?? 0],
      );

  String toJsonString() => jsonEncode(toJson());

  factory BackupScheduleSettings.fromJsonString(String jsonString) =>
      BackupScheduleSettings.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>,
      );

  /// Calculates [Duration] until the next occurrence of [hour]:[minute]
  Duration get initialDelay {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    return next.difference(now);
  }

  /// Converts frequency to a [Duration] for Workmanager periodic scheduling.
  /// Monthly is approximated as 30 days.
  Duration get frequencyDuration => switch (frequency) {
    BackupFrequency.daily => const Duration(hours: 24),
    BackupFrequency.weekly => const Duration(days: 7),
    BackupFrequency.monthly => const Duration(days: 30),
  };

  String get formattedTime {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
