class StorageKeys {
  StorageKeys._();

  // Preference Storage Keys
  static const String databaseSeeded = 'database_seeded';
  static const String onboardingCompleted = 'onboarding_completed';
  static const String themeMode = 'theme_mode';
  static const String currency = 'currency';
  static const String locale = 'locale';

  // Secure Storage Keys (Supabase Auth)
  static const String supabaseAuthToken = 'supabase.auth.token';

  // ObjectBox Storage Keys (digunakan untuk konfigurasi)
  static const String dbVersion = 'db_version';
}
