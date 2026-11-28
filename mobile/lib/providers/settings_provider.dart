import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../models/localized_text.dart';

/// Cài đặt người dùng: Demo Mode, ngôn ngữ hiển thị & thông tin đăng nhập học viên.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider({
    bool? demoMode,
    AppLanguage language = AppLanguage.both,
    bool isLoggedIn = false,
    String studentName = '',
    String studentId = '',
  })  : _demoMode = demoMode ?? AppConfig.demoModeByDefault,
        _language = language, // ignore: prefer_initializing_formals
        _isLoggedIn = isLoggedIn, // ignore: prefer_initializing_formals
        _studentName = studentName, // ignore: prefer_initializing_formals
        _studentId = studentId; // ignore: prefer_initializing_formals

  bool _demoMode;
  AppLanguage _language;
  bool _isLoggedIn;
  String _studentName;
  String _studentId;

  bool get demoMode => _demoMode;
  AppLanguage get language => _language;
  bool get isLoggedIn => _isLoggedIn;
  String get studentName => _studentName;
  String get studentId => _studentId;

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

  void login({required String name, required String studentId}) {
    _studentName = name.trim();
    _studentId = studentId.trim().toUpperCase();
    _isLoggedIn = true;
    notifyListeners();
  }

  void logout() {
    _isLoggedIn = false;
    notifyListeners();
  }
}
