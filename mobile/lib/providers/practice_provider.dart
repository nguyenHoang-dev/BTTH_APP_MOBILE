import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../core/state/view_state.dart';
import '../models/question.dart';
import '../repositories/quiz_repository.dart';

/// Quản lý trạng thái cho Chế độ Luyện tập (Practice Mode).
///
/// Đặc trưng của Practice Mode:
/// - Không giới hạn thời gian.
/// - Phản hồi Đúng/Sai ngay lập tức khi bấm chọn đáp án.
/// - Khóa đáp án khi đã chọn, hiển thị giải thích tĩnh và nút gọi AI.
/// - Cho phép lọc câu hỏi theo khối kiến thức (category).
class PracticeProvider extends ChangeNotifier {
  PracticeProvider({required QuizRepository quizRepository})
      : _quizRepo = quizRepository;

  final QuizRepository _quizRepo;

  ViewState<List<Question>> _state = const IdleState();
  List<String> _categories = const [];
  String? _selectedCategory;
  int _currentIndex = 0;
  int? _selectedAnswer;

  // Thống kê phiên luyện tập hiện tại
  int _correctCount = 0;
  int _answeredCount = 0;

  ViewState<List<Question>> get state => _state;
  List<Question> get questions => _state.dataOrNull ?? const [];
  List<String> get categories => _categories;
  String? get selectedCategory => _selectedCategory;
  int get currentIndex => _currentIndex;
  int? get selectedAnswer => _selectedAnswer;
  int get correctCount => _correctCount;
  int get answeredCount => _answeredCount;

  Question? get currentQuestion =>
      questions.isEmpty ? null : questions[_currentIndex];

  bool get isAnswered => _selectedAnswer != null;

  bool get isCurrentCorrect =>
      isAnswered && (currentQuestion?.isCorrect(_selectedAnswer!) ?? false);

  bool get isFirst => _currentIndex == 0;
  bool get isLast => questions.isEmpty || _currentIndex == questions.length - 1;
  int get totalQuestions => questions.length;

  /// Nạp ngân hàng câu hỏi và danh sách khối kiến thức.
  Future<void> loadQuestions({String? category}) async {
    _state = const LoadingState();
    _selectedCategory = category;
    _currentIndex = 0;
    _selectedAnswer = null;
    notifyListeners();

    try {
      final cats = await _quizRepo.getCategories();
      _categories = cats;

      final list = await _quizRepo.loadQuestionsByCategory(category);
      if (list.isEmpty) {
        _state = EmptyState(
          category != null
              ? 'Không có câu hỏi nào thuộc chủ đề "$category".'
              : 'Ngân hàng câu hỏi đang trống.',
        );
      } else {
        _state = SuccessState(list);
      }
    } on AppException catch (e) {
      _state = ErrorState(e.message, error: e);
    } catch (e) {
      _state = ErrorState('Không thể nạp danh sách câu hỏi luyện tập.', error: e);
    }
    notifyListeners();
  }

  /// Chuyển đổi khối kiến thức (category).
  Future<void> selectCategory(String? category) async {
    if (_selectedCategory == category && questions.isNotEmpty) return;
    await loadQuestions(category: category);
  }

  /// Chọn đáp án cho câu hỏi hiện tại.
  /// Khóa lại ngay sau khi chọn để hiển thị kết quả Đúng/Sai.
  void selectOption(int optionIndex) {
    if (currentQuestion == null || isAnswered) return;

    _selectedAnswer = optionIndex;
    _answeredCount++;
    if (currentQuestion!.isCorrect(optionIndex)) {
      _correctCount++;
    }
    notifyListeners();
  }

  /// Làm lại câu hiện tại (mở khóa để chọn lại).
  void retryCurrent() {
    if (!isAnswered) return;
    if (isCurrentCorrect) {
      _correctCount--;
    }
    _answeredCount--;
    _selectedAnswer = null;
    notifyListeners();
  }

  /// Chuyển sang câu kế tiếp.
  void nextQuestion() {
    if (!isLast) {
      _currentIndex++;
      _selectedAnswer = null;
      notifyListeners();
    }
  }

  /// Quay lại câu hỏi trước.
  void previousQuestion() {
    if (!isFirst) {
      _currentIndex--;
      _selectedAnswer = null;
      notifyListeners();
    }
  }

  /// Nhảy tới câu hỏi bất kỳ trong danh sách.
  void jumpToQuestion(int index) {
    if (index >= 0 && index < questions.length && index != _currentIndex) {
      _currentIndex = index;
      _selectedAnswer = null;
      notifyListeners();
    }
  }

  /// Đặt lại toàn bộ tiến độ của phiên luyện tập.
  void resetSession() {
    _currentIndex = 0;
    _selectedAnswer = null;
    _correctCount = 0;
    _answeredCount = 0;
    notifyListeners();
  }
}

