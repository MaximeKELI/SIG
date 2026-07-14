import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_strings.dart';

class LocaleService extends ChangeNotifier {
  static const _key = 'sig_sols_lang';

  String _lang = 'fr';

  String get lang => _lang;
  bool get isFrench => _lang == 'fr';

  String t(String key, {Map<String, String> vars = const {}}) =>
      AppStrings.t(_lang, key, vars: vars);

  String get langToggleLabel => AppStrings.langToggleLabel(_lang);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored != null && AppStrings.langs.contains(stored)) {
      _lang = stored;
    }
    notifyListeners();
  }

  Future<void> toggle() async {
    _lang = AppStrings.nextLang(_lang);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _lang);
    notifyListeners();
  }

  Future<void> setLang(String lang) async {
    if (!AppStrings.langs.contains(lang)) return;
    _lang = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _lang);
    notifyListeners();
  }
}
