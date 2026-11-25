import 'package:flutter/foundation.dart';

import '../models/localized_text.dart';

/// Cài đặt người dùng: ngôn ngữ hiển thị.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider({this.language = AppLanguage.both});

  AppLanguage language;

  void setLanguage(AppLanguage value) {
    if (language == value) return;
    language = value;
    notifyListeners();
  }
}
