import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../core/state/view_state.dart';
import '../models/ai_explanation.dart';
import '../models/localized_text.dart';
import '../models/quiz_result.dart';
import '../repositories/ai_repository.dart';

/// Trạng thái của AIExplanationDialog.
class AIProvider extends ChangeNotifier {
  AIProvider({required AIRepository aiRepository}) : _repo = aiRepository;

  final AIRepository _repo;

  ViewState<AIExplanation> _state = const IdleState();
  ViewState<AIExplanation> get state => _state;

  /// Cache theo (questionId, selectedIndex, language) -> không gọi lại AI cho cùng 1 câu.
  final Map<String, AIExplanation> _cache = {};

  /// Chống race-condition: chỉ nhận kết quả của request mới nhất.
  int _requestId = 0;

  Future<void> explainAnswer(UserAnswer answer, AppLanguage language, {bool forceRefresh = false}) async {
    final key = '${answer.question.id}_${answer.selectedIndex}_${language.code}';
    final cached = _cache[key];
    if (!forceRefresh && cached != null) {
      _state = SuccessState(cached);
      notifyListeners();
      return;
    }

    final myId = ++_requestId;
    _state = const LoadingState();
    notifyListeners();

    ViewState<AIExplanation> next;
    try {
      final result = await _repo.explainAnswer(answer, language: language);
      final isBlank = result.whyWrong.trim().isEmpty && result.correctExplanation.trim().isEmpty;
      if (isBlank) {
        next = const EmptyState('AI chưa đưa ra được giải thích cho câu này.');
      } else {
        // Chỉ cache kết quả Gemini thật – tắt Demo Mode sẽ không bị trả về dữ liệu demo cũ.
        if (!result.isDemo) _cache[key] = result;
        next = SuccessState(result);
      }
    } on AppException catch (e) {
      next = ErrorState(e.message, error: e);
    } catch (e) {
      next = ErrorState('Không lấy được giải thích từ AI. Vui lòng thử lại.', error: e);
    }

    if (myId != _requestId) return; // Đã có request mới hơn.
    _state = next;
    notifyListeners();
  }

  void reset() {
    _requestId++;
    _state = const IdleState();
    notifyListeners();
  }
}
