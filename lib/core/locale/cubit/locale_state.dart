part of 'locale_cubit.dart';

/// Supported locales in the app
enum SupportedLocale {
  english(Locale('en', 'US'), 'English'),
  indonesian(Locale('id', 'ID'), 'Bahasa Indonesia');

  final Locale locale;
  final String displayName;

  const SupportedLocale(this.locale, this.displayName);

  static SupportedLocale fromLocale(Locale locale) {
    return SupportedLocale.values.firstWhere(
      (l) => l.locale.languageCode == locale.languageCode,
      orElse: () => SupportedLocale.english,
    );
  }

  static SupportedLocale fromCode(String code) {
    return SupportedLocale.values.firstWhere(
      (l) => l.name == code,
      orElse: () => SupportedLocale.english,
    );
  }
}

class LocaleState extends Equatable {
  final SupportedLocale currentLocale;

  const LocaleState({this.currentLocale = SupportedLocale.english});

  Locale get locale => currentLocale.locale;

  LocaleState copyWith({SupportedLocale? currentLocale}) {
    return LocaleState(currentLocale: currentLocale ?? this.currentLocale);
  }

  @override
  List<Object?> get props => [currentLocale];
}
