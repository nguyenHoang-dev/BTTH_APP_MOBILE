import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../models/ai_explanation.dart';
import '../models/localized_text.dart';
import '../models/quiz_result.dart';
import '../services/api_client.dart';
import 'demo_ai_repository.dart';

/// Hợp đồng gọi AI giải thích câu hỏi.
abstract interface class AIRepository {
  Future<AIExplanation> explainAnswer(UserAnswer answer, {required AppLanguage language});
}

/// Bản triển khai chính:
///  - Demo Mode BẬT  -> trả mock data (không gọi mạng).
///  - Demo Mode TẮT  -> POST {baseUrl}/api/explain (timeout 15s qua ApiClient).
///  - Mất mạng/timeout & [fallbackToDemo] = true -> tự trả mock data kèm thông báo.
class AIRepositoryImpl implements AIRepository {
  AIRepositoryImpl({
    required ApiClient apiClient,
    required ValueGetter<bool> isDemoMode,
    AIRepository? demoRepository,
    this.fallbackToDemo = true,
  })  : _api = apiClient,
        _isDemoMode = isDemoMode, // ignore: prefer_initializing_formals
        _demo = demoRepository ?? DemoAIRepository();

  final ApiClient _api;
  final ValueGetter<bool> _isDemoMode;
  final AIRepository _demo;
  final bool fallbackToDemo;

  static const String explainPath = '/api/explain';

  @override
  Future<AIExplanation> explainAnswer(UserAnswer answer, {required AppLanguage language}) async {
    if (_isDemoMode()) {
      return _demo.explainAnswer(answer, language: language);
    }

    try {
      final json = await _api.post(explainPath, body: buildRequestBody(answer, language));
      final parsed = AIExplanation.fromJson(json);
      // Nếu server đang chạy ở chế độ Demo (chưa có GEMINI_API_KEY) và câu hỏi có sẵn
      // lời giải thích tĩnh chính xác trong ngân hàng câu hỏi, kết hợp để hiển thị sâu sắc hơn.
      final lang = language == AppLanguage.en ? AppLanguage.en : AppLanguage.vi;
      final staticExplain = answer.question.explanation?.resolve(lang);
      if (parsed.isDemo && staticExplain != null && staticExplain.trim().isNotEmpty) {
        return AIExplanation(
          whyWrong: parsed.whyWrong,
          correctExplanation: '$staticExplain\n\n${parsed.correctExplanation}',
          example: parsed.example,
          tip: parsed.tip,
          source: parsed.source,
          notice: parsed.notice,
        );
      }
      return parsed;
    } on AppException catch (e) {
      if (fallbackToDemo && e.isConnectivityIssue) {
        final demo = await _demo.explainAnswer(answer, language: language);
        return demo.copyWith(notice: '${e.message}\n→ Đang hiển thị dữ liệu Demo.');
      }
      rethrow;
    }
  }

  /// Tách riêng để unit test được định dạng request gửi lên server.
  @visibleForTesting
  static Map<String, dynamic> buildRequestBody(UserAnswer answer, AppLanguage language) {
    // Server chỉ cần 1 ngôn ngữ; chế độ song ngữ => giải thích bằng tiếng Việt.
    final lang = language == AppLanguage.en ? AppLanguage.en : AppLanguage.vi;
    final q = answer.question;
    final selected = answer.selectedIndex >= 0 && answer.selectedIndex < q.options.length
        ? q.options[answer.selectedIndex].resolve(lang)
        : (lang == AppLanguage.en ? '(No answer)' : '(Không trả lời)');
    return {
      'question': q.content.resolve(lang),
      'options': q.options.map((o) => o.resolve(lang)).toList(),
      'selectedAnswer': selected,
      'correctAnswer': q.correctOption.resolve(lang),
      'language': lang.code,
      'category': q.category.toLowerCase(),
    };
  }
}
