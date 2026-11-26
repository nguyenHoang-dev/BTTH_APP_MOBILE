import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../core/errors/app_exception.dart';
import '../core/logic/quiz_engine.dart';
import '../core/state/view_state.dart';
import '../models/exam_subject.dart';
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
  Map<String, int> _subjectCounts = const {};
  int _currentIndex = 0;
  final Map<int, int> _answers = {};
  DateTime? _startedAt;
  bool _submitting = false;
  String? _saveWarning;

  /// true khi đang ở chế độ "Ôn lại câu sai" (TV4: để xóa câu đã làm đúng lại).
  bool _onlyWrong = false;

  ViewState<List<Question>> get state => _state;
  List<ExamSubject> get subjects => ExamSubject.defaults;
  Map<String, int> get subjectCounts => _subjectCounts;
  List<Question> get questions => _state.dataOrNull ?? const [];
  int get currentIndex => _currentIndex;
  Question? get currentQuestion =>
      questions.isEmpty ? null : questions[_currentIndex];
  int? get selectedIndexForCurrent => _answers[_currentIndex];
  bool isQuestionAnswered(int index) => _answers.containsKey(index);
  int? answerFor(int index) => _answers[index];
  bool get isFirst => _currentIndex == 0;
  bool get isLast => _currentIndex == questions.length - 1;
  int get answeredCount => _answers.length;
  bool get isSubmitting => _submitting;

  /// Cảnh báo không chặn luồng (vd. lưu SQLite thất bại nhưng vẫn xem được điểm).
  String? get saveWarning => _saveWarning;

  /// Đếm trước số lượng câu hỏi của từng môn để hiển thị ở màn chọn môn.
  Future<void> loadSubjectCounts() async {
    try {
      final bank = await _quizRepo.loadAllQuestions();
      _subjectCounts = Map.unmodifiable({
        for (final subject in subjects)
          subject.id: bank.where(subject.matches).length,
      });
      notifyListeners();
    } catch (_) {
      // Không chặn màn hình chính; lỗi nạp câu hỏi sẽ được xử lý ở QuizScreen.
    }
  }

  /// Nạp ngân hàng câu hỏi và khởi tạo lượt làm bài.
  /// - [onlyWrong] = true: chỉ lấy các câu từng làm sai (lấy từ SQLite).
  /// - [subject] != null: lọc toàn bộ câu thuộc [subject] và đảo thứ tự mỗi lần thi.
  /// - Mặc định: random [questionsPerQuiz] câu từ toàn bộ ngân hàng.
  Future<void> startQuiz({
    bool onlyWrong = false,
    ExamSubject? subject,
    Random? random,
  }) async {
    _state = const LoadingState();
    _resetProgress();
    _onlyWrong = onlyWrong;
    notifyListeners();

    try {
      var bank = await _quizRepo.loadAllQuestions();
      if (onlyWrong) {
        final wrongIds = await _historyRepo.getWrongQuestionIds();
        bank = bank.where((q) => wrongIds.contains(q.id)).toList();
      }

      final picked = (!onlyWrong && subject != null)
          ? _engine.prepareSubjectExam(bank, subject, random: random)
          : _engine.pickRandom(bank, questionsPerQuiz, random: random);
      if (picked.isEmpty) {
        _state = EmptyState(
          onlyWrong
              ? 'Bạn chưa có câu sai nào để ôn lại. Giỏi lắm! 🎉'
              : subject != null
                  ? 'Môn "${subject.name.vi}" hiện chưa có câu hỏi nào.'
                  : 'Ngân hàng câu hỏi đang trống.',
        );
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

  /// Nhảy nhanh tới câu hỏi bất kỳ từ Bảng điều hướng câu hỏi (Question Palette).
  void jumpToQuestion(int index) {
    if (index >= 0 && index < questions.length && index != _currentIndex) {
      _currentIndex = index;
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
      // Ôn lại câu sai: câu nào làm ĐÚNG lại thì xóa khỏi bảng wrong_answers.
      if (_onlyWrong) {
        final fixedIds = result.answers
            .where((a) => a.isCorrect)
            .map((a) => a.question.id)
            .toSet();
        if (fixedIds.isNotEmpty) {
          await _historyRepo.removeWrongAnswers(fixedIds);
        }
      }
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
