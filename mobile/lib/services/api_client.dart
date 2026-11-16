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
      : _dio = dio ??
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

  String get baseUrl => _dio.options.baseUrl;

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) {
    return _send(() => _dio.get<dynamic>(path, queryParameters: query));
  }

  Future<Map<String, dynamic>> post(String path, {Object? body}) {
    return _send(() => _dio.post<dynamic>(path, data: body));
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
      throw AppException.fromDio(e);
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException('Đã có lỗi không xác định. Vui lòng thử lại.', cause: e);
    }
  }

  static void _log(Object o) => debugPrint('[ApiClient] $o');
}

