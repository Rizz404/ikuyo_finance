import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:ikuyo_finance/core/extensions/logger_extension.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum SupabaseAvailability {
  /// Supabase terinisialisasi dan dapat dijangkau
  available,

  /// Jaringan offline atau Supabase tidak dapat dijangkau
  unavailable,

  /// Supabase SDK tidak pernah diinisialisasi (env vars kosong/tidak ada)
  notConfigured,
}

class SupabaseStatus {
  final SupabaseAvailability availability;
  final bool hasSession;

  const SupabaseStatus({required this.availability, required this.hasSession});

  /// True hanya ketika Supabase tersedia DAN user sudah login
  bool get isCloudEnabled =>
      availability == SupabaseAvailability.available && hasSession;

  /// True ketika Supabase dikonfigurasi (meski sedang offline)
  bool get isConfigured =>
      availability != SupabaseAvailability.notConfigured;

  @override
  String toString() =>
      'SupabaseStatus(availability: $availability, hasSession: $hasSession)';
}

/// Service yang memantau ketersediaan Supabase dan konektivitas jaringan.
/// Equivalent dari SupabaseStatusNotifier di kawai_notes, diadaptasi untuk
/// GetIt + ChangeNotifier pattern.
class SupabaseStatusService extends ChangeNotifier {
  SupabaseStatusService(SupabaseClient? client) : _client = client {
    if (client == null) {
      _status = const SupabaseStatus(
        availability: SupabaseAvailability.notConfigured,
        hasSession: false,
      );
      return;
    }

    _status = SupabaseStatus(
      availability: SupabaseAvailability.available,
      hasSession: client.auth.currentSession != null,
    );

    // * Listen ke auth state changes dan mirror ke status ini
    _authSub = client.auth.onAuthStateChange.listen(
      (authState) {
        final hasSession = authState.session != null;
        if (_status.availability == SupabaseAvailability.available &&
            _status.hasSession != hasSession) {
          _status = SupabaseStatus(
            availability: SupabaseAvailability.available,
            hasSession: hasSession,
          );
          notifyListeners();
        }
      },
      onError: (Object e) {
        talker.logError('Auth state stream error', e);
        _status = SupabaseStatus(
          availability: SupabaseAvailability.unavailable,
          hasSession: _status.hasSession,
        );
        notifyListeners();
      },
    );

    // * Listen ke perubahan konektivitas jaringan
    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      (results) {
        final hasNetwork = results.any((r) => r != ConnectivityResult.none);
        if (!hasNetwork) {
          _status = SupabaseStatus(
            availability: SupabaseAvailability.unavailable,
            hasSession: _status.hasSession,
          );
          notifyListeners();
        } else if (_status.availability == SupabaseAvailability.unavailable) {
          // * Jaringan pulih — probe Supabase
          _probeSupabase();
        }
      },
    );
  }

  final SupabaseClient? _client;
  late SupabaseStatus _status;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<AuthState>? _authSub;

  SupabaseStatus get status => _status;

  Future<void> _probeSupabase() async {
    final client = _client;
    if (client == null) return;
    try {
      // * Probe dengan refreshSession jika session ada, untuk mendeteksi
      // * expired token secara akurat (bukan hanya cek cache lokal)
      if (client.auth.currentSession != null) {
        await client.auth.refreshSession();
      }
      _status = SupabaseStatus(
        availability: SupabaseAvailability.available,
        hasSession: client.auth.currentSession != null,
      );
      talker.logInfo('Supabase kembali online');
      notifyListeners();
    } catch (e) {
      talker.logError('Supabase probe gagal', e);
      _status = SupabaseStatus(
        availability: SupabaseAvailability.unavailable,
        hasSession: _status.hasSession,
      );
      notifyListeners();
    }
  }

  /// Tandai Supabase sebagai tidak tersedia (panggil ketika AuthException
  /// dengan statusCode == null diterima — artinya tidak ada respons jaringan)
  void markUnavailable() {
    _status = SupabaseStatus(
      availability: SupabaseAvailability.unavailable,
      hasSession: _status.hasSession,
    );
    notifyListeners();
  }

  /// Probe ulang Supabase secara manual (misal setelah user tap tombol retry)
  Future<void> retry() async {
    if (_client == null) return;
    await _probeSupabase();
  }

  /// Jalankan operasi Supabase dengan graceful degradation.
  /// Jika gagal, tandai Supabase unavailable dan kembalikan null.
  Future<T?> guard<T>(Future<T> Function() call) async {
    if (_status.availability == SupabaseAvailability.notConfigured) return null;
    try {
      final result = await call();
      if (_status.availability == SupabaseAvailability.unavailable) {
        _status = SupabaseStatus(
          availability: SupabaseAvailability.available,
          hasSession: _status.hasSession,
        );
        notifyListeners();
      }
      return result;
    } catch (e, stack) {
      talker.logError('Supabase call gagal — degradasi ke offline', e, stack);
      _status = SupabaseStatus(
        availability: SupabaseAvailability.unavailable,
        hasSession: _status.hasSession,
      );
      notifyListeners();
      return null;
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}
