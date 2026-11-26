import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';

/// Tự động chọn Base URL theo loại thiết bị.
///
/// | Thiết bị                 | Base URL                                    |
/// |--------------------------|---------------------------------------------|
/// | Android Emulator         | http://10.0.2.2:3000 (alias tới localhost PC)|
/// | Web / iOS Sim / Desktop  | http://localhost:3000                       |
/// | Thiết bị thật            | --dart-define=API_BASE_URL=http://192.168.x.x:3000 |
///
/// Nếu đã truyền API_BASE_URL thì luôn ưu tiên giá trị đó (ghi đè thủ công).
class BaseUrlResolver {
  BaseUrlResolver({DeviceInfoPlugin? deviceInfo})
      : _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  final DeviceInfoPlugin _deviceInfo;

  static const String androidEmulatorHost = 'http://10.0.2.2';
  static const String localhost = 'http://localhost';

  Future<String> resolve() async {
    const port = AppConfig.serverPort;

    if (AppConfig.envBaseUrl.isNotEmpty) return AppConfig.envBaseUrl;
    if (kIsWeb) return '$localhost:$port';

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await _deviceInfo.androidInfo;
        if (!info.isPhysicalDevice) return '$androidEmulatorHost:$port';
        return _physicalDeviceFallback(port);
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await _deviceInfo.iosInfo;
        if (!info.isPhysicalDevice) return '$localhost:$port';
        return _physicalDeviceFallback(port);
      }
    } catch (e) {
      debugPrint('[BaseUrlResolver] Không đọc được thông tin thiết bị: $e');
    }
    return '$localhost:$port';
  }

  /// Thiết bị thật mà chưa cấu hình API_BASE_URL -> không thể đoán IP máy tính.
  /// Trả về localhost (sẽ lỗi kết nối) => AIRepository tự fallback sang Demo data.
  String _physicalDeviceFallback(int port) {
    debugPrint(
      '[BaseUrlResolver] Thiết bị thật nhưng chưa có API_BASE_URL. '
      'Chạy: flutter run --dart-define=API_BASE_URL=http://<IP-may-tinh>:$port',
    );
    return '$localhost:$port';
  }
}

