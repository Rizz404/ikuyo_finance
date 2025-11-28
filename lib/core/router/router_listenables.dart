import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// * Listen ke Supabase auth state changes untuk refresh router
class SupabaseAuthListenable extends ChangeNotifier {
  SupabaseAuthListenable() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      notifyListeners();
    });
  }

  bool get isAuthenticated =>
      Supabase.instance.client.auth.currentSession != null;
}
