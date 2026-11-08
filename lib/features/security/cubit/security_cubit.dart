import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/extensions/logger_extension.dart';
import 'package:ikuyo_finance/features/security/models/security_settings.dart';
import 'package:ikuyo_finance/features/security/services/biometric_service.dart';
import 'package:ikuyo_finance/features/security/services/security_storage_service.dart';
import 'package:ikuyo_finance/features/security/utils/security_hasher.dart';

part 'security_state.dart';

class SecurityCubit extends Cubit<SecurityState> {
  final SecurityStorageService _storageService;
  final BiometricService _biometricService;

  /// Timestamp terakhir app di-pause (untuk auto-lock timer)
  DateTime? _lastPausedAt;

  /// * Antrian penulisan: setiap perubahan dihitung dari settings terbaru
  /// * sehingga dua penulisan beruntun tidak saling menimpa (BKSEC-1)
  Future<void> _writeQueue = Future.value();

  SecurityCubit(this._storageService, this._biometricService)
    : super(const SecurityState(status: SecurityStatus.loading)) {
    _init();
  }

  Future<void> _init() => _load();

  Future<void> _load() async {
    final bioAvailable = await _biometricService.isAvailable;
    final deviceCredential = await _deviceCredentialAvailable();

    try {
      final settings = await _storageService.load();
      if (isClosed) return;
      final loaded = state.copyWith(
        settings: settings,
        biometricAvailable: bioAvailable,
        deviceCredentialAvailable: deviceCredential,
        loadFailed: false,
        loadError: null,
        lockHint: null,
      );
      // ! Data lama (BKSEC-1) bisa berisi lock aktif tanpa metode apa pun.
      // ! Tanpa kredensial device tidak ada jalan buka, jadi jangan kunci
      // ! (settings tersimpan tidak diubah).
      final unrecoverable = loaded.needsRecovery && !deviceCredential;
      if (settings.isEnabled && unrecoverable) {
        logInfo('Lock enabled without any unlock method; not locking');
      }
      emit(
        loaded.copyWith(
          status: settings.isEnabled && !unrecoverable
              ? SecurityStatus.locked
              : SecurityStatus.unlocked,
        ),
      );

      logInfo(
        'SecurityCubit initialized: enabled=${settings.isEnabled}, '
        'bio=$bioAvailable',
      );
    } catch (e, s) {
      logError('SecurityCubit init failed', e, s);
      if (isClosed) return;
      // ! Fail-closed: kunci kecuali lock diketahui nonaktif. Lock screen
      // ! menyediakan retry + kredensial device; penulisan diblokir
      // ! (loadFailed) agar settings asli tidak tertimpa.
      // ! Hint null (upgrade / restore) BUKAN bukti tidak ada lock: tetap
      // ! terkunci; jalan keluar hanya retry atau reset ber-kredensial device.
      final hint = _storageService.lockEnabledHint;
      final knownDisabled = hint == false;
      emit(
        state.copyWith(
          settings: const SecuritySettings(),
          biometricAvailable: bioAvailable,
          deviceCredentialAvailable: deviceCredential,
          loadFailed: true,
          loadError: e is SecurityStorageReadException
              ? e.kind
              : 'unknown:${e.runtimeType}',
          lockHint: hint,
          status: knownDisabled
              ? SecurityStatus.unlocked
              : SecurityStatus.locked,
        ),
      );
    }
  }

  Future<bool> _deviceCredentialAvailable() async {
    try {
      return await _biometricService.isDeviceSupported;
    } catch (e, s) {
      logError('Device credential check failed', e, s);
      return false;
    }
  }

  /// Coba baca ulang settings setelah gagal (mis. keystore sementara error)
  Future<void> retryLoad() async {
    if (!state.loadFailed) return;
    final wasUnlocked = state.status == SecurityStatus.unlocked;
    await _load();
    // * Jangan mengunci ulang user yang sudah terautentikasi
    if (wasUnlocked && state.status != SecurityStatus.unlocked) {
      emit(state.copyWith(status: SecurityStatus.unlocked));
    }
  }

  // ─── Lifecycle ─────────────────────────────────────────

  /// Dipanggil saat app di-pause (background / screen off)
  void onAppPaused() {
    if (!state.settings.isEnabled) return;
    _lastPausedAt = DateTime.now();
    logInfo('App paused, auto-lock timer started');
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
      logInfo('Auto-locked after $elapsed min (threshold: $threshold)');
    }
    _lastPausedAt = null;
  }

  /// Dipanggil saat device screen off (trigger lockTrigger.onScreenOff / both)
  void onScreenOff() {
    if (!state.settings.isEnabled) return;
    final trigger = state.settings.lockTrigger;
    if (trigger == LockTrigger.onScreenOff || trigger == LockTrigger.both) {
      _lockApp();
      logInfo('Locked on screen off');
    }
  }

  /// Dipanggil saat app close (trigger lockTrigger.onAppClose / both)
  void onAppClose() {
    if (!state.settings.isEnabled) return;
    final trigger = state.settings.lockTrigger;
    if (trigger == LockTrigger.onAppClose || trigger == LockTrigger.both) {
      _lockApp();
      logInfo('Locked on app close');
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

    emit(
      state.copyWith(
        status: SecurityStatus.authenticating,
        authResult: SecurityAuthResult.idle,
      ),
    );

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
      logInfo('Biometric auth success');
    } else {
      // local_auth returns false when user cancels or fails max attempts.
      // We return to locked/idle state so user can retry or use PIN,
      // without showing a red error banner for cancellation.
      emit(
        state.copyWith(
          status: SecurityStatus.locked,
          authResult: SecurityAuthResult.idle,
        ),
      );
      logInfo('Biometric auth canceled or failed');
    }
  }

  /// ! Recovery: buka dengan kredensial layar kunci device, hanya saat
  /// ! tidak ada metode app yang bisa dipakai (settings rusak / tak terbaca)
  Future<void> authenticateWithDeviceCredential() async {
    if (!state.needsRecovery || !state.deviceCredentialAvailable) return;

    emit(
      state.copyWith(
        status: SecurityStatus.authenticating,
        authResult: SecurityAuthResult.idle,
      ),
    );

    final success = await _biometricService.authenticateWithDeviceCredential(
      reason: 'Verify to unlock Ikuyo Finance',
    );

    emit(
      state.copyWith(
        status: success ? SecurityStatus.unlocked : SecurityStatus.locked,
        authResult: success
            ? SecurityAuthResult.success
            : SecurityAuthResult.idle,
        failedAttempts: success ? 0 : state.failedAttempts,
      ),
    );
    logInfo('Device credential auth ${success ? 'success' : 'failed'}');
  }

  /// ! Reset app lock setelah settings gagal dibaca: wajib aksi eksplisit
  /// ! user + autentikasi kredensial device. Hanya settings keamanan yang
  /// ! dihapus; database & data lain tidak disentuh. Return true jika reset.
  Future<bool> resetLockWithDeviceCredential() async {
    if (!state.loadFailed || !state.deviceCredentialAvailable) return false;
    if (state.status == SecurityStatus.authenticating) return false;
    final previous = state.status;

    emit(
      state.copyWith(
        status: SecurityStatus.authenticating,
        authResult: SecurityAuthResult.idle,
      ),
    );
    final verified = await _biometricService.authenticateWithDeviceCredential(
      reason: 'Verify to reset Ikuyo Finance app lock',
    );
    if (isClosed) return false;
    if (!verified) {
      emit(state.copyWith(status: previous));
      logInfo('App lock reset: device credential not verified');
      return false;
    }

    try {
      await _storageService.resetLock();
    } catch (e, s) {
      logError('App lock reset failed', e, s);
      if (!isClosed) emit(state.copyWith(status: previous));
      return false;
    }
    if (isClosed) return true;
    emit(
      state.copyWith(
        settings: const SecuritySettings(),
        status: SecurityStatus.unlocked,
        authResult: SecurityAuthResult.success,
        failedAttempts: 0,
        loadFailed: false,
        loadError: null,
        lockHint: null,
      ),
    );
    logInfo('App lock reset after device credential verification');
    return true;
  }

  /// Autentikasi PIN
  void authenticateWithPin(String pin) {
    if (!state.canUsePin) return;

    emit(
      state.copyWith(
        status: SecurityStatus.authenticating,
        authResult: SecurityAuthResult.idle,
      ),
    );

    final storedHash = state.settings.pinHash!;
    final isValid = SecurityHasher.verify(pin, storedHash);

    if (isValid) {
      emit(
        state.copyWith(
          status: SecurityStatus.unlocked,
          authResult: SecurityAuthResult.success,
          failedAttempts: 0,
        ),
      );
      logInfo('PIN auth success');
      if (SecurityHasher.needsRehash(storedHash)) {
        _rehashLegacy(
          stillCurrent: (s) => s.pinHash == storedHash,
          upgrade: (s) =>
              s.copyWith(pinHash: SecurityHasher.hashSecret(pin)),
        );
      }
    } else {
      emit(
        state.copyWith(
          status: SecurityStatus.locked,
          authResult: SecurityAuthResult.failed,
          failedAttempts: state.failedAttempts + 1,
          errorMessage: 'Incorrect PIN',
        ),
      );
      logInfo('PIN auth failed');
    }
  }

  /// Autentikasi password
  void authenticateWithPassword(String password) {
    if (!state.canUsePassword) return;

    emit(
      state.copyWith(
        status: SecurityStatus.authenticating,
        authResult: SecurityAuthResult.idle,
      ),
    );

    final storedHash = state.settings.passwordHash!;
    final isValid = SecurityHasher.verify(password, storedHash);

    if (isValid) {
      emit(
        state.copyWith(
          status: SecurityStatus.unlocked,
          authResult: SecurityAuthResult.success,
          failedAttempts: 0,
        ),
      );
      logInfo('Password auth success');
      if (SecurityHasher.needsRehash(storedHash)) {
        _rehashLegacy(
          stillCurrent: (s) => s.passwordHash == storedHash,
          upgrade: (s) =>
              s.copyWith(passwordHash: SecurityHasher.hashSecret(password)),
        );
      }
    } else {
      emit(
        state.copyWith(
          status: SecurityStatus.locked,
          authResult: SecurityAuthResult.failed,
          failedAttempts: state.failedAttempts + 1,
          errorMessage: 'Incorrect password',
        ),
      );
      logInfo('Password auth failed');
    }
  }

  /// Ganti hash SHA-256 lama dengan hash bersalt setelah unlock sukses.
  /// Gagal simpan = hash lama tetap berlaku (tidak ada lockout).
  void _rehashLegacy({
    required bool Function(SecuritySettings s) stillCurrent,
    required SecuritySettings Function(SecuritySettings s) upgrade,
  }) {
    _mutate((s) => stillCurrent(s) ? upgrade(s) : s).then((saved) {
      logInfo(saved ? 'Legacy hash upgraded' : 'Legacy hash upgrade skipped');
    });
  }

  /// Reset auth result (untuk clear error message)
  void clearAuthResult() {
    emit(state.copyWith(authResult: SecurityAuthResult.idle));
  }

  // ─── Settings Management ──────────────────────────────

  /// Lock aktif wajib punya minimal satu faktor yang bisa diketik
  /// (PIN / password); biometric saja bisa hilang saat sensor di-unenroll.
  static bool hasKnowledgeFactor(SecuritySettings s) =>
      (s.pinEnabled && s.pinHash != null) ||
      (s.passwordEnabled && s.passwordHash != null);

  static bool isValidSettings(SecuritySettings s) =>
      !s.isEnabled || hasKnowledgeFactor(s);

  /// Jalankan perubahan settings secara berurutan dari settings terbaru.
  /// Return true jika tersimpan.
  Future<bool> _mutate(
    SecuritySettings Function(SecuritySettings current) change,
  ) {
    final result = _writeQueue.then((_) async {
      // ! Jangan menulis sebelum settings asli terbaca (bisa menimpa PIN)
      if (state.status == SecurityStatus.loading || state.loadFailed) {
        logInfo('Security settings write blocked: settings not loaded');
        return false;
      }
      final next = change(state.settings);
      if (!isValidSettings(next)) {
        logInfo('Security settings write rejected: no unlock method');
        return false;
      }
      return _persist(next);
    });
    _writeQueue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<bool> _persist(SecuritySettings newSettings) async {
    try {
      await _storageService.save(newSettings);
      final bioAvailable = await _biometricService.isAvailable;
      emit(
        state.copyWith(settings: newSettings, biometricAvailable: bioAvailable),
      );
      logInfo('Security settings updated');
      return true;
    } catch (e, s) {
      logError('Failed to update settings', e, s);
      return false;
    }
  }

  /// Update seluruh settings sekaligus
  Future<bool> updateSettings(SecuritySettings newSettings) =>
      _mutate((_) => newSettings);

  /// Toggle security on/off
  Future<bool> toggleSecurity(bool enabled) async {
    final saved = await _mutate((s) => s.copyWith(isEnabled: enabled));

    if (saved && !enabled) {
      emit(
        state.copyWith(
          status: SecurityStatus.unlocked,
          authResult: SecurityAuthResult.idle,
        ),
      );
    }
    return saved;
  }

  /// Set PIN baru; [enableLock] mengaktifkan app lock dalam penulisan yang sama
  Future<bool> setPin(String pin, {bool enableLock = false}) async {
    final hash = SecurityHasher.hashSecret(pin);
    final saved = await _mutate(
      (s) => s.copyWith(
        pinEnabled: true,
        pinHash: hash,
        pinLength: pin.length,
        isEnabled: enableLock ? true : null,
      ),
    );
    if (saved) logInfo('PIN set successfully');
    return saved;
  }

  /// Hapus PIN (ditolak jika PIN satu-satunya metode lock aktif)
  Future<bool> removePin() async {
    final saved = await _mutate(
      (s) => SecuritySettings(
        isEnabled: s.isEnabled,
        biometricEnabled: s.biometricEnabled,
        pinEnabled: false,
        passwordEnabled: s.passwordEnabled,
        passwordHash: s.passwordHash,
        lockTrigger: s.lockTrigger,
        autoLockMinutes: s.autoLockMinutes,
        pinLength: 6,
      ),
    );
    if (saved) logInfo('PIN removed');
    return saved;
  }

  /// Set password baru; [enableLock] mengaktifkan app lock sekaligus
  Future<bool> setPassword(String password, {bool enableLock = false}) async {
    final hash = SecurityHasher.hashSecret(password);
    final saved = await _mutate(
      (s) => s.copyWith(
        passwordEnabled: true,
        passwordHash: hash,
        isEnabled: enableLock ? true : null,
      ),
    );
    if (saved) logInfo('Password set successfully');
    return saved;
  }

  /// Hapus password (ditolak jika password satu-satunya metode lock aktif)
  Future<bool> removePassword() async {
    final saved = await _mutate(
      (s) => SecuritySettings(
        isEnabled: s.isEnabled,
        biometricEnabled: s.biometricEnabled,
        pinEnabled: s.pinEnabled,
        pinHash: s.pinHash,
        passwordEnabled: false,
        lockTrigger: s.lockTrigger,
        autoLockMinutes: s.autoLockMinutes,
        pinLength: s.pinLength,
      ),
    );
    if (saved) logInfo('Password removed');
    return saved;
  }

  /// Toggle biometric
  Future<bool> toggleBiometric(bool enabled) =>
      _mutate((s) => s.copyWith(biometricEnabled: enabled));

  /// Set lock trigger
  Future<bool> setLockTrigger(LockTrigger trigger) =>
      _mutate((s) => s.copyWith(lockTrigger: trigger));

  /// Set auto-lock duration (menit)
  Future<bool> setAutoLockMinutes(int minutes) =>
      _mutate((s) => s.copyWith(autoLockMinutes: minutes));

  /// Reset semua security settings
  Future<void> resetSecurity() async {
    await _storageService.clear();
    emit(const SecurityState());
    logInfo('Security settings reset');
  }

  /// Refresh biometric availability
  Future<void> refreshBiometricAvailability() async {
    final available = await _biometricService.isAvailable;
    emit(state.copyWith(biometricAvailable: available));
  }
}
