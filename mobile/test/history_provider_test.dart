import 'package:bilingual_quiz/core/state/view_state.dart';
import 'package:bilingual_quiz/models/quiz_result.dart';
import 'package:bilingual_quiz/providers/history_provider.dart';
import 'package:bilingual_quiz/providers/quiz_provider.dart';
import 'package:bilingual_quiz/repositories/history_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';

QuizResult _result({required int correct, int total = 10}) => QuizResult(
      totalQuestions: total,
      correctCount: correct,
      duration: const Duration(minutes: 5),
      takenAt: DateTime(2026, 11, 20),
    );

void main() {
  group('HistoryProvider', () {
    test('Chưa có lịch sử -> EmptyState, thống kê bằng 0', () async {
      final provider = HistoryProvider(historyRepository: FakeHistoryRepository());

      await provider.load();

      expect(provider.state, isA<EmptyState<List<QuizResult>>>());
      expect(provider.totalAttempts, 0);
      expect(provider.averageScore, 0);
      expect(provider.bestScore, 0);
      expect(provider.categoryStats, isEmpty);
    });

    test('Tính đúng điểm trung bình và điểm cao nhất', () async {
      final repo = FakeHistoryRepository()
        ..saved.addAll([
          _result(correct: 8), // 8.0
          _result(correct: 6), // 6.0
          _result(correct: 5), // 5.0
        ]);
      final provider = HistoryProvider(historyRepository: repo);

      await provider.load();

      expect(provider.state, isA<SuccessState<List<QuizResult>>>());
      expect(provider.totalAttempts, 3);
      expect(provider.averageScore, closeTo(6.333, 0.001));
      expect(provider.bestScore, 8.0);
    });

    test('Repository lỗi -> ErrorState với thông báo thân thiện', () async {
      final provider = HistoryProvider(historyRepository: _ThrowingHistoryRepository());

      await provider.load();

      final state = provider.state;
      expect(state, isA<ErrorState<List<QuizResult>>>());
      expect((state as ErrorState).message, 'Không tải được lịch sử.');
    });

    test('clearHistory() xóa sạch dữ liệu và chuyển về EmptyState', () async {
      final repo = FakeHistoryRepository()
        ..saved.add(_result(correct: 7))
        ..wrongIds = {1, 2}
        ..categoryStats = [const CategoryStat(category: 'dart', correct: 7, total: 10)];
      final provider = HistoryProvider(historyRepository: repo);
      await provider.load();
      expect(provider.wrongCount, 2);

      final error = await provider.clearHistory();

      expect(error, isNull);
      expect(repo.clearCalls, 1);
      expect(provider.state, isA<EmptyState<List<QuizResult>>>());
      expect(provider.wrongCount, 0);
      expect(provider.categoryStats, isEmpty);
    });

    test('clearHistory() lỗi -> trả về thông báo, giữ nguyên dữ liệu', () async {
      final repo = FakeHistoryRepository()
        ..saved.add(_result(correct: 7))
        ..failOnClear = true;
      final provider = HistoryProvider(historyRepository: repo);
      await provider.load();

      final error = await provider.clearHistory();

      expect(error, 'Không xóa được lịch sử làm bài.');
      expect(provider.totalAttempts, 1);
      expect(provider.isClearing, isFalse);
    });
  });

  group('Ôn lại câu sai & thống kê theo khối', () {
    test('Làm ĐÚNG lại câu từng sai -> bị xóa khỏi danh sách câu sai', () async {
      // Câu 1, 2 từng sai. Đáp án đúng của mọi câu là index 0.
      final history = FakeHistoryRepository()..wrongIds = {1, 2};
      final quiz = QuizProvider(
        quizRepository: FakeQuizRepository(
          questions: [fakeQuestion(1), fakeQuestion(2), fakeQuestion(3)],
        ),
        historyRepository: history,
      );

      await quiz.startQuiz(onlyWrong: true);
      expect(quiz.questions.map((q) => q.id).toSet(), {1, 2});

      // Trả lời đúng câu 1, sai câu 2 (thứ tự câu bị xáo nên tra theo id).
      for (var i = 0; i < quiz.questions.length; i++) {
        quiz.selectAnswer(quiz.currentQuestion!.id == 1 ? 0 : 3);
        quiz.next();
      }
      await quiz.submit();

      final provider = HistoryProvider(historyRepository: history);
      await provider.load();
      expect(history.wrongIds, {2});
      expect(provider.wrongCount, 1);
    });

    test('Làm bài thường thì KHÔNG xóa câu sai cũ dù trả lời đúng', () async {
      final history = FakeHistoryRepository()..wrongIds = {1};
      final quiz = QuizProvider(
        quizRepository: FakeQuizRepository(questions: [fakeQuestion(1)]),
        historyRepository: history,
      );

      await quiz.startQuiz();
      quiz.selectAnswer(0);
      await quiz.submit();

      expect(history.wrongIds, {1});
    });

    test('InMemoryHistoryRepository cộng dồn đúng/tổng theo từng khối', () async {
      final repo = InMemoryHistoryRepository();
      final dart1 = fakeQuestion(1);
      final dart2 = fakeQuestion(2);

      QuizResult attempt(List<UserAnswer> answers) => QuizResult(
            totalQuestions: answers.length,
            correctCount: answers.where((a) => a.isCorrect).length,
            duration: Duration.zero,
            takenAt: DateTime(2026, 11, 20),
            wrongAnswers: answers.where((a) => !a.isCorrect).toList(),
            answers: answers,
          );

      // Lượt 1: đúng 1/2. Lượt 2: đúng 2/2 -> tổng 3/4 cho khối 'test'.
      await repo.saveResult(attempt([
        UserAnswer(question: dart1, selectedIndex: 0),
        UserAnswer(question: dart2, selectedIndex: 1),
      ]));
      await repo.saveResult(attempt([
        UserAnswer(question: dart1, selectedIndex: 0),
        UserAnswer(question: dart2, selectedIndex: 0),
      ]));

      final stats = await repo.getCategoryStats();
      expect(stats, hasLength(1));
      expect(stats.single.category, 'test');
      expect(stats.single.correct, 3);
      expect(stats.single.total, 4);
      expect(stats.single.accuracy, 0.75);

      await repo.removeWrongAnswers({2});
      expect(await repo.getWrongQuestionIds(), isEmpty);

      await repo.clearHistory();
      expect(await repo.getResults(), isEmpty);
      expect(await repo.getCategoryStats(), isEmpty);
    });
  });
}

/// Repository luôn ném lỗi không phải AppException (giả lập lỗi bất ngờ).
class _ThrowingHistoryRepository extends FakeHistoryRepository {
  @override
  Future<List<QuizResult>> getResults({int limit = 50}) async =>
      throw StateError('DB hỏng');
}
