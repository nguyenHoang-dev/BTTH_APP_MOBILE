import 'dart:math';

import '../../models/exam_subject.dart';
import '../../models/question.dart';
import '../../models/quiz_result.dart';

/// Logic nghiệp vụ THUẦN (không phụ thuộc Flutter, DB hay mạng)
/// => unit test trực tiếp trong test/quiz_logic_test.dart.
class QuizEngine {
  const QuizEngine();

  static const int unanswered = -1;

  /// Đảo ngẫu nhiên thứ tự danh sách câu hỏi trên một bản sao mới.
  List<Question> shuffleQuestions(List<Question> questions, {Random? random}) {
    if (questions.isEmpty) return const [];
    final shuffled = List<Question>.of(questions)..shuffle(random ?? Random());
    return List<Question>.unmodifiable(shuffled);
  }

  /// Lọc câu hỏi theo [subject] và đảo thứ tự toàn bộ câu trong môn đó.
  List<Question> prepareSubjectExam(
    List<Question> bank,
    ExamSubject subject, {
    Random? random,
  }) {
    final filtered = bank.where(subject.matches).toList(growable: false);
    return shuffleQuestions(filtered, random: random);
  }

  /// Chọn ngẫu nhiên [count] câu không trùng lặp từ ngân hàng câu hỏi.
  List<Question> pickRandom(List<Question> bank, int count, {Random? random}) {
    if (bank.isEmpty || count <= 0) return const [];
    final shuffled = shuffleQuestions(bank, random: random);
    return shuffled.take(min(count, shuffled.length)).toList(growable: false);
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

    for (var i = 0; i < questions.length; i++) {
      final selected = answers[i] ?? unanswered;
      final answer = UserAnswer(question: questions[i], selectedIndex: selected);
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
    );
  }
}

