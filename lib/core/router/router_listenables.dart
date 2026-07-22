import 'package:flutter/material.dart';
import 'package:ikuyo_finance/features/auth/services/supabase_status_service.dart';

/// Bridge antara SupabaseStatusService dan GoRouter refreshListenable.
/// Setiap perubahan status (auth, konektivitas) menyebabkan router
/// mengevaluasi ulang redirect callbacks.
class SupabaseAuthListenable extends ChangeNotifier {
  SupabaseAuthListenable(this._statusService) {
    _statusService.addListener(_onStatusChanged);
  }

  final SupabaseStatusService _statusService;

  void _onStatusChanged() => notifyListeners();

  bool get isAuthenticated => _statusService.status.hasSession;

  SupabaseStatus get supabaseStatus => _statusService.status;

  @override
  void dispose() {
    _statusService.removeListener(_onStatusChanged);
    super.dispose();
  }
}
