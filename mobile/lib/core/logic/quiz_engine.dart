import 'dart:math';

import '../../models/question.dart';
import '../../models/quiz_result.dart';

/// Logic nghiệp vụ THUẦN (không phụ thuộc Flutter, DB hay mạng)
/// => unit test trực tiếp trong test/quiz_logic_test.dart.
class QuizEngine {
  const QuizEngine();

  static const int unanswered = -1;

  /// Chọn ngẫu nhiên [count] câu không trùng lặp từ ngân hàng câu hỏi.
  List<Question> pickRandom(List<Question> bank, int count, {Random? random}) {
    if (bank.isEmpty || count <= 0) return const [];
    final shuffled = List<Question>.of(bank)..shuffle(random ?? Random());
    return shuffled.take(min(count, bank.length)).toList(growable: false);
  }

  /// Chấm điểm. [answers]: index câu hỏi -> index đáp án đã chọn.
  /// Câu chưa trả lời được tính là sai.
  QuizResult grade({
    required List<Question> questions,
    required Map<int, int> answers,
    required Duration duration,
    required DateTime takenAt,
  }) {
    var correct = 0;
    final wrong = <UserAnswer>[];
    final all = <UserAnswer>[]; // TV4: dùng cho thống kê theo khối & xóa câu sai.

    for (var i = 0; i < questions.length; i++) {
      final selected = answers[i] ?? unanswered;
      final answer = UserAnswer(question: questions[i], selectedIndex: selected);
      all.add(answer);
      if (answer.isCorrect) {
        correct++;
      } else {
        wrong.add(answer);
      }
    }

    return QuizResult(
      totalQuestions: questions.length,
      correctCount: correct,
      duration: duration,
      takenAt: takenAt,
      wrongAnswers: List.unmodifiable(wrong),
      answers: List.unmodifiable(all),
    );
  }
}

