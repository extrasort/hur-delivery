import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../localization/app_localizations.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('ar', 'IQ');
  static const String _localeKey = 'app_locale';
  bool _isLoading = true;

  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';
  bool get isLoading => _isLoading;

  LocaleProvider() {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localeCode = prefs.getString(_localeKey);
      if (localeCode != null) {
        final parts = localeCode.split('_');
        if (parts.length == 2) {
          _locale = Locale(parts[0], parts[1]);
        }
      }
    } catch (e) {
      // Use default locale if loading fails
      _locale = const Locale('ar', 'IQ');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (!AppLocalizations.supportedLocales.contains(locale)) {
      return;
    }
    
    _locale = locale;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, '${locale.languageCode}_${locale.countryCode}');
    } catch (e) {
      // Ignore save errors
    }
  }

  Future<void> toggleLocale() async {
    final newLocale = _locale.languageCode == 'ar'
        ? const Locale('en', 'US')
        : const Locale('ar', 'IQ');
    await setLocale(newLocale);
  }
}

