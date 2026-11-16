import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../models/localized_text.dart';

/// Cài đặt người dùng: Demo Mode & ngôn ngữ hiển thị.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider({bool? demoMode, AppLanguage language = AppLanguage.both})
      : _demoMode = demoMode ?? AppConfig.demoModeByDefault,
        _language = language; // ignore: prefer_initializing_formals

  bool _demoMode;
  AppLanguage _language;

  bool get demoMode => _demoMode;
  AppLanguage get language => _language;

  void setDemoMode(bool value) {
    if (_demoMode == value) return;
    _demoMode = value;
    notifyListeners();
  }

  void setLanguage(AppLanguage value) {
    if (_language == value) return;
    _language = value;
    notifyListeners();
  }
}
