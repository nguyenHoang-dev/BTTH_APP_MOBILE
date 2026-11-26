import 'question.dart';

/// Câu trả lời của người dùng cho 1 câu hỏi.
class UserAnswer {
  const UserAnswer({required this.question, required this.selectedIndex});

  final Question question;
  final int selectedIndex;

  bool get isCorrect => question.isCorrect(selectedIndex);
}

/// Kết quả một lượt làm bài (lưu vào SQLite).
class QuizResult {
  const QuizResult({
    this.id,
    required this.totalQuestions,
    required this.correctCount,
    required this.duration,
    required this.takenAt,
    this.wrongAnswers = const [],
  });

  final int? id;
  final int totalQuestions;
  final int correctCount;
  final Duration duration;
  final DateTime takenAt;

  /// Danh sách câu sai – dùng cho màn Result & nút "Hỏi AI".
  /// Không lưu vào bảng quiz_results (lưu riêng ở bảng wrong_answers).
  final List<UserAnswer> wrongAnswers;

  int get wrongCount => totalQuestions - correctCount;

  /// Điểm thang 10, làm tròn 1 chữ số.
  double get score10 =>
      totalQuestions == 0 ? 0 : double.parse((correctCount * 10 / totalQuestions).toStringAsFixed(1));

  double get accuracy => totalQuestions == 0 ? 0 : correctCount / totalQuestions;

  Map<String, Object?> toDbMap() => {
        if (id != null) 'id': id,
        'total_questions': totalQuestions,
        'correct_count': correctCount,
        'duration_seconds': duration.inSeconds,
        'taken_at': takenAt.toIso8601String(),
      };

  factory QuizResult.fromDbMap(Map<String, Object?> map) => QuizResult(
        id: map['id'] as int?,
        totalQuestions: map['total_questions'] as int,
        correctCount: map['correct_count'] as int,
        duration: Duration(seconds: map['duration_seconds'] as int),
        takenAt: DateTime.parse(map['taken_at'] as String),
      );
}

