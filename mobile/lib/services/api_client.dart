import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../core/errors/app_exception.dart';

/// Network client duy nhất của app (bọc Dio).
///
/// - Timeout 15s cho connect / send / receive.
/// - Mọi lỗi được chuyển thành [AppException] với thông báo thân thiện,
///   tầng trên KHÔNG bao giờ phải biết tới DioException.
/// - Inject được [Dio] giả để viết test.
class ApiClient {
  ApiClient({required String baseUrl, Dio? dio})
      : _enableAutoFailover = dio == null,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: AppConfig.connectTimeout,
                sendTimeout: AppConfig.sendTimeout,
                receiveTimeout: AppConfig.receiveTimeout,
                contentType: Headers.jsonContentType,
                responseType: ResponseType.json,
              ),
            ) {
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true, logPrint: _log),
      );
    }
  }

  final Dio _dio;
  final bool _enableAutoFailover;

  /// Các địa chỉ Server ứng viên (USB adb reverse + các mạng Wi-Fi LAN của máy chủ).
  static const List<String> _fallbackBaseUrls = [
    'http://localhost:3000',
    'http://172.20.10.5:3000',
    'http://172.16.9.13:3000',
    'http://10.0.2.2:3000',
  ];

  String get baseUrl => _dio.options.baseUrl;

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) {
    return _send(() => _dio.get<dynamic>(path, queryParameters: query));
  }

  Future<Map<String, dynamic>> post(String path, {Object? body}) {
    return _send(() => _dio.post<dynamic>(path, data: body));
  }

  Future<bool> _trySwitchToReachableHost() async {
    final current = _dio.options.baseUrl;
    final probeDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(milliseconds: 1800),
        receiveTimeout: const Duration(milliseconds: 1800),
        responseType: ResponseType.json,
      ),
    );

    for (final candidate in _fallbackBaseUrls) {
      if (candidate == current) continue;
      try {
        final res = await probeDio.get<dynamic>('$candidate/api/health');
        if (res.statusCode == 200) {
          _log('Auto-switched API base URL: $current -> $candidate');
          _dio.options.baseUrl = candidate;
          return true;
        }
      } catch (_) {
        // Thử tiếp địa chỉ ứng viên kế tiếp.
      }
    }
    return false;
  }

  Future<Map<String, dynamic>> _send(Future<Response<dynamic>> Function() call) async {
    try {
      final response = await call();
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      throw const AppException(
        'Dữ liệu trả về không đúng định dạng.',
        type: AppErrorType.parsing,
      );
    } on DioException catch (e) {
      final isConnFailure = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout;
      if (_enableAutoFailover && isConnFailure) {
        final switched = await _trySwitchToReachableHost();
        if (switched) {
          try {
            final retryResponse = await call();
            final retryData = retryResponse.data;
            if (retryData is Map<String, dynamic>) return retryData;
          } on DioException catch (retryErr) {
            throw AppException.fromDio(retryErr);
          }
        }
      }
      throw AppException.fromDio(e);
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException('Đã có lỗi không xác định. Vui lòng thử lại.', cause: e);
    }
  }

  static void _log(Object o) => debugPrint('[ApiClient] $o');
}

