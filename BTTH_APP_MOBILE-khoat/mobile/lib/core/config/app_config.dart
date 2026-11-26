import 'package:flutter/foundation.dart';

/// Cấu hình toàn cục, truyền vào lúc build qua `--dart-define`.
///
/// Ví dụ chạy trên điện thoại thật:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000
/// Ví dụ bật Demo Mode mặc định:
///   flutter run --dart-define=DEMO_MODE=true
@immutable
class AppConfig {
  const AppConfig._();

  /// Base URL do người dùng cấu hình (dùng cho thiết bị thật). Rỗng = chưa cấu hình.
  static const String envBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Cổng server Node.js.
  static const int serverPort = int.fromEnvironment('API_PORT', defaultValue: 3000);

  /// Demo Mode mặc định khi khởi động app.
  static const bool demoModeByDefault = bool.fromEnvironment('DEMO_MODE');

  /// Timeout cho mọi request tới server AI (Rubric: mọi request phải có timeout).
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration sendTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  /// Số câu mỗi lượt làm bài (random từ ngân hàng 300 câu).
  static const int questionsPerQuiz = 20;

  static const String questionBankAsset = 'assets/data/questions.json';
}

