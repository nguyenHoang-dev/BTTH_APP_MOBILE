import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../core/errors/app_exception.dart';
import '../core/logic/quiz_engine.dart';
import '../core/state/view_state.dart';
import '../models/question.dart';
import '../models/quiz_result.dart';
import '../repositories/history_repository.dart';
import '../repositories/quiz_repository.dart';

/// Quản lý trạng thái 1 lượt làm bài.
/// Luồng: startQuiz() -> selectAnswer() / next() / previous() -> submit().
class QuizProvider extends ChangeNotifier {
  QuizProvider({
    required QuizRepository quizRepository,
    required HistoryRepository historyRepository,
    QuizEngine engine = const QuizEngine(),
    DateTime Function()? clock,
    this.questionsPerQuiz = AppConfig.questionsPerQuiz,
  })  : _quizRepo = quizRepository,
        _historyRepo = historyRepository,
        _engine = engine, // ignore: prefer_initializing_formals
        _clock = clock ?? DateTime.now;

  final QuizRepository _quizRepo;
  final HistoryRepository _historyRepo;
  final QuizEngine _engine;
  final DateTime Function() _clock;
  final int questionsPerQuiz;

  ViewState<List<Question>> _state = const IdleState();
  int _currentIndex = 0;
  final Map<int, int> _answers = {};
  DateTime? _startedAt;
  bool _submitting = false;
  String? _saveWarning;

  ViewState<List<Question>> get state => _state;
  List<Question> get questions => _state.dataOrNull ?? const [];
  int get currentIndex => _currentIndex;
  Question? get currentQuestion =>
      questions.isEmpty ? null : questions[_currentIndex];
  int? get selectedIndexForCurrent => _answers[_currentIndex];
  bool get isFirst => _currentIndex == 0;
  bool get isLast => _currentIndex == questions.length - 1;
  int get answeredCount => _answers.length;
  bool get isSubmitting => _submitting;

  /// Cảnh báo không chặn luồng (vd. lưu SQLite thất bại nhưng vẫn xem được điểm).
  String? get saveWarning => _saveWarning;

  /// Nạp ngân hàng câu hỏi -> random [questionsPerQuiz] câu.
  /// [onlyWrong] = true: chỉ lấy các câu từng làm sai (lấy từ SQLite).
  Future<void> startQuiz({bool onlyWrong = false}) async {
    _state = const LoadingState();
    _resetProgress();
    notifyListeners();

    try {
      var bank = await _quizRepo.loadAllQuestions();
      if (onlyWrong) {
        final wrongIds = await _historyRepo.getWrongQuestionIds();
        bank = bank.where((q) => wrongIds.contains(q.id)).toList();
      }

      final picked = _engine.pickRandom(bank, questionsPerQuiz);
      if (picked.isEmpty) {
        _state = EmptyState(onlyWrong
            ? 'Bạn chưa có câu sai nào để ôn lại. Giỏi lắm! 🎉'
            : 'Ngân hàng câu hỏi đang trống.');
      } else {
        _startedAt = _clock();
        _state = SuccessState(picked);
      }
    } on AppException catch (e) {
      _state = ErrorState(e.message, error: e);
    } catch (e) {
      _state = ErrorState('Không thể bắt đầu bài làm. Vui lòng thử lại.', error: e);
    }
    notifyListeners();
  }

  void selectAnswer(int optionIndex) {
    if (currentQuestion == null) return;
    _answers[_currentIndex] = optionIndex;
    notifyListeners();
  }

  void next() {
    if (!isLast) {
      _currentIndex++;
      notifyListeners();
    }
  }

  void previous() {
    if (!isFirst) {
      _currentIndex--;
      notifyListeners();
    }
  }

  /// Chấm điểm + lưu SQLite. Lỗi lưu KHÔNG làm mất kết quả.
  Future<QuizResult> submit() async {
    _submitting = true;
    _saveWarning = null;
    notifyListeners();

    final now = _clock();
    final result = _engine.grade(
      questions: questions,
      answers: Map.unmodifiable(_answers),
      duration: now.difference(_startedAt ?? now),
      takenAt: now,
    );

    try {
      await _historyRepo.saveResult(result);
    } on AppException catch (e) {
      _saveWarning = e.message;
    } catch (_) {
      _saveWarning = 'Không lưu được lịch sử làm bài.';
    } finally {
      _submitting = false;
      notifyListeners();
    }
    return result;
  }

  void _resetProgress() {
    _currentIndex = 0;
    _answers.clear();
    _startedAt = null;
    _saveWarning = null;
  }
}
