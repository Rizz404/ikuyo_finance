import 'package:local_auth/local_auth.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';

/// Service untuk biometric authentication via local_auth
class BiometricService {
  final LocalAuthentication _auth;

  BiometricService([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  /// Cek apakah device support biometric
  Future<bool> get isAvailable async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (e, s) {
      logError('Biometric check failed', e, s);
      return false;
    }
  }

  /// Ambil list biometric yang tersedia
  Future<List<BiometricType>> get availableBiometrics async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e, s) {
      logError('Failed to get biometrics', e, s);
      return [];
    }
  }

  /// Autentikasi biometric
  Future<bool> authenticate({String reason = 'Verify your identity'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e, s) {
      logError('Biometric auth failed', e, s);
      return false;
    }
  }
}
