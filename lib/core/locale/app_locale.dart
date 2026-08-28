import 'dart:ui';

enum AppLocale {
  ru(
    languageCode: 'ru',
    nativeName: 'Русский',
    englishName: 'Russian',
    flag: '🇷🇺',
  ),

  en(
    languageCode: 'en',
    nativeName: 'English',
    englishName: 'English',
    flag: '🇬🇧',
  ),

  kk(
    languageCode: 'kk',
    nativeName: 'Қазақша',
    englishName: 'Kazakh',
    flag: '🇰🇿',
  ),

  ky(
    languageCode: 'ky',
    nativeName: 'Кыргызча',
    englishName: 'Kyrgyz',
    flag: '🇰🇬',
  ),

  uz(
    languageCode: 'uz',
    nativeName: "O'zbekcha",
    englishName: 'Uzbek',
    flag: '🇺🇿',
  );

  const AppLocale({
    required this.languageCode,
    required this.nativeName,
    required this.englishName,
    required this.flag,
  });

  final String languageCode;

  final String nativeName;

  final String englishName;

  final String flag;

  Locale toLocale() => Locale(languageCode);

  String get displayName => '$flag $nativeName';

  static AppLocale? fromCode(String code) {
    for (final locale in values) {
      if (locale.languageCode == code) {
        return locale;
      }
    }
    return null;
  }

  static AppLocale? fromLocale(Locale locale) {
    return fromCode(locale.languageCode);
  }

  static AppLocale fromSystemLocale(Locale systemLocale) {
    final exact = fromCode(systemLocale.languageCode);
    if (exact != null) return exact;

    return AppLocale.ru;
  }

  static AppLocale get defaultLocale => AppLocale.ru;

  static List<Locale> get supportedLocales =>
      values.map((e) => e.toLocale()).toList();
}
