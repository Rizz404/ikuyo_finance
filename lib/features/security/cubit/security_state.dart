part of 'security_cubit.dart';

enum SecurityStatus { unlocked, locked, authenticating }

enum SecurityAuthResult { idle, success, failed, error }

class SecurityState extends Equatable {
  final SecuritySettings settings;
  final SecurityStatus status;
  final SecurityAuthResult authResult;
  final bool biometricAvailable;
  final String? errorMessage;
  final int failedAttempts;

  const SecurityState({
    this.settings = const SecuritySettings(),
    this.status = SecurityStatus.unlocked,
    this.authResult = SecurityAuthResult.idle,
    this.biometricAvailable = false,
    this.errorMessage,
    this.failedAttempts = 0,
  });

  /// Apakah security aktif & app harus dikunci
  bool get shouldLock => settings.isEnabled && status == SecurityStatus.locked;

  /// Apakah biometric bisa dipakai
  bool get canUseBiometric => settings.biometricEnabled && biometricAvailable;

  /// Apakah PIN bisa dipakai
  bool get canUsePin => settings.pinEnabled && settings.pinHash != null;

  /// Apakah password bisa dipakai
  bool get canUsePassword =>
      settings.passwordEnabled && settings.passwordHash != null;

  SecurityState copyWith({
    SecuritySettings? settings,
    SecurityStatus? status,
    SecurityAuthResult? authResult,
    bool? biometricAvailable,
    String? errorMessage,
    int? failedAttempts,
  }) {
    return SecurityState(
      settings: settings ?? this.settings,
      status: status ?? this.status,
      authResult: authResult ?? this.authResult,
      biometricAvailable: biometricAvailable ?? this.biometricAvailable,
      errorMessage: errorMessage,
      failedAttempts: failedAttempts ?? this.failedAttempts,
    );
  }

  @override
  List<Object?> get props => [
    settings.isEnabled,
    settings.biometricEnabled,
    settings.pinEnabled,
    settings.passwordEnabled,
    settings.pinHash,
    settings.passwordHash,
    settings.lockTrigger,
    settings.autoLockMinutes,
    status,
    authResult,
    biometricAvailable,
    errorMessage,
    failedAttempts,
  ];
}
