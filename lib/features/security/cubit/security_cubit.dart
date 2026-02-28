import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';
import 'package:ikuyo_finance/features/security/models/security_settings.dart';
import 'package:ikuyo_finance/features/security/service/biometric_service.dart';
import 'package:ikuyo_finance/features/security/service/security_storage_service.dart';
import 'package:ikuyo_finance/features/security/utils/security_hasher.dart';

part 'security_state.dart';

class SecurityCubit extends Cubit<SecurityState> {
  final SecurityStorageService _storageService;
  final BiometricService _biometricService;

  /// Timestamp terakhir app di-pause (untuk auto-lock timer)
  DateTime? _lastPausedAt;

  SecurityCubit(this._storageService, this._biometricService)
    : super(const SecurityState()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final settings = await _storageService.load();
      final bioAvailable = await _biometricService.isAvailable;

      emit(
        state.copyWith(
          settings: settings,
          biometricAvailable: bioAvailable,
          status: settings.isEnabled
              ? SecurityStatus.locked
              : SecurityStatus.unlocked,
        ),
      );

      this.logInfo(
        'SecurityCubit initialized: enabled=${settings.isEnabled}, '
        'bio=$bioAvailable',
      );
    } catch (e, s) {
      this.logError('SecurityCubit init failed', e, s);
    }
  }

  // ─── Lifecycle ─────────────────────────────────────────

  /// Dipanggil saat app di-pause (background / screen off)
  void onAppPaused() {
    if (!state.settings.isEnabled) return;
    _lastPausedAt = DateTime.now();
    this.logInfo('App paused, auto-lock timer started');
  }

  /// Dipanggil saat app di-resume
  void onAppResumed() {
    if (!state.settings.isEnabled) return;
    if (state.status == SecurityStatus.locked) return;

    final pausedAt = _lastPausedAt;
    if (pausedAt == null) return;

    final elapsed = DateTime.now().difference(pausedAt).inMinutes;
    final threshold = state.settings.autoLockMinutes;

    // * Lock jika sudah melebihi threshold
    if (elapsed >= threshold) {
      _lockApp();
      this.logInfo('Auto-locked after $elapsed min (threshold: $threshold)');
    }
    _lastPausedAt = null;
  }

  /// Dipanggil saat device screen off (trigger lockTrigger.onScreenOff / both)
  void onScreenOff() {
    if (!state.settings.isEnabled) return;
    final trigger = state.settings.lockTrigger;
    if (trigger == LockTrigger.onScreenOff || trigger == LockTrigger.both) {
      _lockApp();
      this.logInfo('Locked on screen off');
    }
  }

  /// Dipanggil saat app close (trigger lockTrigger.onAppClose / both)
  void onAppClose() {
    if (!state.settings.isEnabled) return;
    final trigger = state.settings.lockTrigger;
    if (trigger == LockTrigger.onAppClose || trigger == LockTrigger.both) {
      _lockApp();
      this.logInfo('Locked on app close');
    }
  }

  void _lockApp() {
    emit(
      state.copyWith(
        status: SecurityStatus.locked,
        authResult: SecurityAuthResult.idle,
        failedAttempts: 0,
      ),
    );
  }

  // ─── Authentication ────────────────────────────────────

  /// Autentikasi biometric
  Future<void> authenticateWithBiometric() async {
    if (!state.canUseBiometric) return;

    emit(state.copyWith(status: SecurityStatus.authenticating));

    final success = await _biometricService.authenticate(
      reason: 'Verify to unlock Ikuyo Finance',
    );

    if (success) {
      emit(
        state.copyWith(
          status: SecurityStatus.unlocked,
          authResult: SecurityAuthResult.success,
          failedAttempts: 0,
        ),
      );
      this.logInfo('Biometric auth success');
    } else {
      emit(
        state.copyWith(
          status: SecurityStatus.locked,
          authResult: SecurityAuthResult.failed,
          failedAttempts: state.failedAttempts + 1,
        ),
      );
      this.logInfo('Biometric auth failed');
    }
  }

  /// Autentikasi PIN
  void authenticateWithPin(String pin) {
    if (!state.canUsePin) return;

    emit(state.copyWith(status: SecurityStatus.authenticating));

    final isValid = SecurityHasher.verify(pin, state.settings.pinHash!);

    if (isValid) {
      emit(
        state.copyWith(
          status: SecurityStatus.unlocked,
          authResult: SecurityAuthResult.success,
          failedAttempts: 0,
        ),
      );
      this.logInfo('PIN auth success');
    } else {
      emit(
        state.copyWith(
          status: SecurityStatus.locked,
          authResult: SecurityAuthResult.failed,
          failedAttempts: state.failedAttempts + 1,
          errorMessage: 'Incorrect PIN',
        ),
      );
      this.logInfo('PIN auth failed');
    }
  }

  /// Autentikasi password
  void authenticateWithPassword(String password) {
    if (!state.canUsePassword) return;

    emit(state.copyWith(status: SecurityStatus.authenticating));

    final isValid = SecurityHasher.verify(
      password,
      state.settings.passwordHash!,
    );

    if (isValid) {
      emit(
        state.copyWith(
          status: SecurityStatus.unlocked,
          authResult: SecurityAuthResult.success,
          failedAttempts: 0,
        ),
      );
      this.logInfo('Password auth success');
    } else {
      emit(
        state.copyWith(
          status: SecurityStatus.locked,
          authResult: SecurityAuthResult.failed,
          failedAttempts: state.failedAttempts + 1,
          errorMessage: 'Incorrect password',
        ),
      );
      this.logInfo('Password auth failed');
    }
  }

  /// Reset auth result (untuk clear error message)
  void clearAuthResult() {
    emit(state.copyWith(authResult: SecurityAuthResult.idle));
  }

  // ─── Settings Management ──────────────────────────────

  /// Update seluruh settings sekaligus
  Future<void> updateSettings(SecuritySettings newSettings) async {
    try {
      await _storageService.save(newSettings);
      final bioAvailable = await _biometricService.isAvailable;
      emit(
        state.copyWith(settings: newSettings, biometricAvailable: bioAvailable),
      );
      this.logInfo('Security settings updated');
    } catch (e, s) {
      this.logError('Failed to update settings', e, s);
    }
  }

  /// Toggle security on/off
  Future<void> toggleSecurity(bool enabled) async {
    final newSettings = state.settings.copyWith(isEnabled: enabled);
    await updateSettings(newSettings);

    if (!enabled) {
      emit(
        state.copyWith(
          status: SecurityStatus.unlocked,
          authResult: SecurityAuthResult.idle,
        ),
      );
    }
  }

  /// Set PIN baru
  Future<void> setPin(String pin) async {
    final hash = SecurityHasher.hash(pin);
    final newSettings = state.settings.copyWith(
      pinEnabled: true,
      pinHash: hash,
    );
    await updateSettings(newSettings);
    this.logInfo('PIN set successfully');
  }

  /// Hapus PIN
  Future<void> removePin() async {
    final newSettings = SecuritySettings(
      isEnabled: state.settings.isEnabled,
      biometricEnabled: state.settings.biometricEnabled,
      pinEnabled: false,
      passwordEnabled: state.settings.passwordEnabled,
      passwordHash: state.settings.passwordHash,
      lockTrigger: state.settings.lockTrigger,
      autoLockMinutes: state.settings.autoLockMinutes,
    );
    await updateSettings(newSettings);
    this.logInfo('PIN removed');
  }

  /// Set password baru
  Future<void> setPassword(String password) async {
    final hash = SecurityHasher.hash(password);
    final newSettings = state.settings.copyWith(
      passwordEnabled: true,
      passwordHash: hash,
    );
    await updateSettings(newSettings);
    this.logInfo('Password set successfully');
  }

  /// Hapus password
  Future<void> removePassword() async {
    final newSettings = SecuritySettings(
      isEnabled: state.settings.isEnabled,
      biometricEnabled: state.settings.biometricEnabled,
      pinEnabled: state.settings.pinEnabled,
      pinHash: state.settings.pinHash,
      passwordEnabled: false,
      lockTrigger: state.settings.lockTrigger,
      autoLockMinutes: state.settings.autoLockMinutes,
    );
    await updateSettings(newSettings);
    this.logInfo('Password removed');
  }

  /// Toggle biometric
  Future<void> toggleBiometric(bool enabled) async {
    final newSettings = state.settings.copyWith(biometricEnabled: enabled);
    await updateSettings(newSettings);
  }

  /// Set lock trigger
  Future<void> setLockTrigger(LockTrigger trigger) async {
    final newSettings = state.settings.copyWith(lockTrigger: trigger);
    await updateSettings(newSettings);
  }

  /// Set auto-lock duration (menit)
  Future<void> setAutoLockMinutes(int minutes) async {
    final newSettings = state.settings.copyWith(autoLockMinutes: minutes);
    await updateSettings(newSettings);
  }

  /// Reset semua security settings
  Future<void> resetSecurity() async {
    await _storageService.clear();
    emit(const SecurityState());
    this.logInfo('Security settings reset');
  }

  /// Refresh biometric availability
  Future<void> refreshBiometricAvailability() async {
    final available = await _biometricService.isAvailable;
    emit(state.copyWith(biometricAvailable: available));
  }
}
