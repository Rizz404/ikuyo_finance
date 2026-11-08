part of 'security_cubit.dart';

/// [loading] = settings belum selesai dibaca; diperlakukan sebagai terkunci.
enum SecurityStatus { unlocked, locked, authenticating, loading }

enum SecurityAuthResult { idle, success, failed, error }

class SecurityState extends Equatable {
  final SecuritySettings settings;
  final SecurityStatus status;
  final SecurityAuthResult authResult;
  final bool biometricAvailable;
  final String? errorMessage;
  final int failedAttempts;

  /// True jika settings tersimpan gagal dibaca; semua penulisan diblokir
  /// agar settings asli tidak tertimpa.
  final bool loadFailed;

  /// Apakah device punya kredensial layar kunci (untuk recovery)
  final bool deviceCredentialAvailable;

  const SecurityState({
    this.settings = const SecuritySettings(),
    this.status = SecurityStatus.unlocked,
    this.authResult = SecurityAuthResult.idle,
    this.biometricAvailable = false,
    this.errorMessage,
    this.failedAttempts = 0,
    this.loadFailed = false,
    this.deviceCredentialAvailable = false,
  });

  /// Apakah konten app harus ditutup lock screen (fail-closed)
  bool get shouldLock {
    if (status == SecurityStatus.unlocked) return false;
    if (status == SecurityStatus.loading || loadFailed) return true;
    return settings.isEnabled;
  }

  /// Apakah biometric bisa dipakai
  bool get canUseBiometric => settings.biometricEnabled && biometricAvailable;

  /// Apakah PIN bisa dipakai
  bool get canUsePin => settings.pinEnabled && settings.pinHash != null;

  /// Apakah password bisa dipakai
  bool get canUsePassword =>
      settings.passwordEnabled && settings.passwordHash != null;

  /// ! Recovery via kredensial device hanya saat tidak ada metode app yang
  /// ! bisa dipakai (settings gagal dibaca / data lama tanpa PIN & password)
  bool get needsRecovery =>
      loadFailed || (!canUsePin && !canUsePassword && !canUseBiometric);

  SecurityState copyWith({
    SecuritySettings? settings,
    SecurityStatus? status,
    SecurityAuthResult? authResult,
    bool? biometricAvailable,
    String? errorMessage,
    int? failedAttempts,
    bool? loadFailed,
    bool? deviceCredentialAvailable,
  }) {
    return SecurityState(
      settings: settings ?? this.settings,
      status: status ?? this.status,
      authResult: authResult ?? this.authResult,
      biometricAvailable: biometricAvailable ?? this.biometricAvailable,
      errorMessage: errorMessage,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      loadFailed: loadFailed ?? this.loadFailed,
      deviceCredentialAvailable:
          deviceCredentialAvailable ?? this.deviceCredentialAvailable,
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
    settings.pinLength,
    status,
    authResult,
    biometricAvailable,
    errorMessage,
    failedAttempts,
    loadFailed,
    deviceCredentialAvailable,
  ];
}
