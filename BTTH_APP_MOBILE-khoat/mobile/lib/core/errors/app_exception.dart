import 'package:dio/dio.dart';

/// Loại lỗi – giúp tầng trên quyết định có fallback sang Demo Mode hay không.
enum AppErrorType { network, timeout, server, badRequest, parsing, unknown }

/// Exception thống nhất của app: luôn mang theo thông điệp thân thiện (tiếng Việt).
class AppException implements Exception {
  const AppException(this.message, {this.type = AppErrorType.unknown, this.cause});

  final String message;
  final AppErrorType type;
  final Object? cause;

  /// Lỗi do không tới được server (mất mạng / timeout) => có thể dùng Demo data.
  bool get isConnectivityIssue =>
      type == AppErrorType.network || type == AppErrorType.timeout;

  /// Chuyển mọi lỗi Dio sang thông báo dễ hiểu cho người dùng.
  factory AppException.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return AppException(
          'Máy chủ phản hồi quá lâu. Vui lòng kiểm tra mạng và thử lại.',
          type: AppErrorType.timeout,
          cause: e,
        );
      case DioExceptionType.connectionError:
        return AppException(
          'Không thể kết nối tới máy chủ AI. Hãy kiểm tra Internet hoặc bật Chế độ Demo.',
          type: AppErrorType.network,
          cause: e,
        );
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        final serverMsg = _extractServerMessage(e.response?.data);
        return AppException(
          serverMsg ??
              (status >= 500
                  ? 'Máy chủ AI đang gặp sự cố, vui lòng thử lại sau.'
                  : 'Yêu cầu không hợp lệ (mã $status).'),
          type: status >= 500 ? AppErrorType.server : AppErrorType.badRequest,
          cause: e,
        );
      case DioExceptionType.cancel:
        return AppException('Yêu cầu đã bị huỷ.', cause: e);
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return AppException(
          'Đã có lỗi xảy ra khi kết nối. Vui lòng thử lại.',
          type: AppErrorType.network,
          cause: e,
        );
    }
  }

  static String? _extractServerMessage(Object? data) {
    if (data is Map && data['error'] is Map) {
      final msg = (data['error'] as Map)['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    }
    return null;
  }

  @override
  String toString() => 'AppException($type): $message';
}
