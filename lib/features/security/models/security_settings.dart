import 'dart:convert';

/// Jenis autentikasi yang tersedia
enum AuthMethod { biometric, pin, password }

/// Kondisi kapan app terkunci
enum LockTrigger { onAppClose, onScreenOff, both }

/// Model pengaturan keamanan
class SecuritySettings {
  final bool isEnabled;
  final bool biometricEnabled;
  final bool pinEnabled;
  final bool passwordEnabled;
  final String? pinHash;
  final String? passwordHash;
  final LockTrigger lockTrigger;

  /// Durasi auto-lock dalam menit (0 = langsung)
  final int autoLockMinutes;

  /// Panjang karakter PIN (4 atau 6)
  final int pinLength;

  const SecuritySettings({
    this.isEnabled = false,
    this.biometricEnabled = false,
    this.pinEnabled = false,
    this.passwordEnabled = false,
    this.pinHash,
    this.passwordHash,
    this.lockTrigger = LockTrigger.onAppClose,
    this.autoLockMinutes = 0,
    this.pinLength = 6,
  });

  SecuritySettings copyWith({
    bool? isEnabled,
    bool? biometricEnabled,
    bool? pinEnabled,
    bool? passwordEnabled,
    String? pinHash,
    String? passwordHash,
    LockTrigger? lockTrigger,
    int? autoLockMinutes,
    int? pinLength,
  }) {
    return SecuritySettings(
      isEnabled: isEnabled ?? this.isEnabled,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      pinEnabled: pinEnabled ?? this.pinEnabled,
      passwordEnabled: passwordEnabled ?? this.passwordEnabled,
      pinHash: pinHash ?? this.pinHash,
      passwordHash: passwordHash ?? this.passwordHash,
      lockTrigger: lockTrigger ?? this.lockTrigger,
      autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
      pinLength: pinLength ?? this.pinLength,
    );
  }

  Map<String, dynamic> toJson() => {
    'isEnabled': isEnabled,
    'biometricEnabled': biometricEnabled,
    'pinEnabled': pinEnabled,
    'passwordEnabled': passwordEnabled,
    'pinHash': pinHash,
    'passwordHash': passwordHash,
    'lockTrigger': lockTrigger.name,
    'autoLockMinutes': autoLockMinutes,
    'pinLength': pinLength,
  };

  factory SecuritySettings.fromJson(Map<String, dynamic> json) {
    return SecuritySettings(
      isEnabled: json['isEnabled'] as bool? ?? false,
      biometricEnabled: json['biometricEnabled'] as bool? ?? false,
      pinEnabled: json['pinEnabled'] as bool? ?? false,
      passwordEnabled: json['passwordEnabled'] as bool? ?? false,
      pinHash: json['pinHash'] as String?,
      passwordHash: json['passwordHash'] as String?,
      lockTrigger: LockTrigger.values.firstWhere(
        (e) => e.name == json['lockTrigger'],
        orElse: () => LockTrigger.onAppClose,
      ),
      autoLockMinutes: json['autoLockMinutes'] as int? ?? 0,
      pinLength: json['pinLength'] as int? ?? 6,
    );
  }

  String encode() => jsonEncode(toJson());

  factory SecuritySettings.decode(String source) =>
      SecuritySettings.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
