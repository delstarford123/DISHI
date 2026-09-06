import 'package:flutter/material.dart';

// Since the app currently uses English as the primary language (as seen in AppStrings),
// this localization class serves as a foundation for multi-language support.
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  // --- Example of getting localized strings based on the current locale ---
  String get welcomeMessage {
    if (locale.languageCode == 'sw') {
      return 'Karibu tena'; // Swahili Example
    }
    return 'Welcome Back'; // Default English
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    // Include all supported language codes here
    return ['en', 'sw'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
