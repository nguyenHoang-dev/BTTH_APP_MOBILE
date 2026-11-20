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
    this.answers = const [],
  });

  final int? id;
  final int totalQuestions;
  final int correctCount;
  final Duration duration;
  final DateTime takenAt;

  /// Danh sách câu sai – dùng cho màn Result & nút "Hỏi AI".
  /// Không lưu vào bảng quiz_results (lưu riêng ở bảng wrong_answers).
  final List<UserAnswer> wrongAnswers;

  /// TẤT CẢ câu trả lời (đúng + sai) – dùng để cộng dồn thống kê theo khối
  /// và xóa câu đã làm đúng ở chế độ "Ôn lại câu sai".
  /// Không lưu vào bảng quiz_results.
  final List<UserAnswer> answers;

  /// Gom số câu đúng / tổng số câu của lượt này theo từng category.
  Map<String, CategoryStat> get statsByCategory {
    final map = <String, CategoryStat>{};
    for (final a in answers) {
      final c = a.question.category;
      final old = map[c] ?? CategoryStat(category: c, correct: 0, total: 0);
      map[c] = CategoryStat(
        category: c,
        correct: old.correct + (a.isCorrect ? 1 : 0),
        total: old.total + 1,
      );
    }
    return map;
  }

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


/// Thống kê 1 khối kiến thức: số câu đúng / tổng số câu đã làm (bảng category_stats).
class CategoryStat {
  const CategoryStat({
    required this.category,
    required this.correct,
    required this.total,
  });

  final String category;
  final int correct;
  final int total;

  /// Tỷ lệ đúng 0..1 – dùng trực tiếp cho LinearProgressIndicator.value.
  double get accuracy => total == 0 ? 0 : correct / total;

  factory CategoryStat.fromDbMap(Map<String, Object?> map) => CategoryStat(
        category: map['category'] as String,
        correct: map['correct_count'] as int,
        total: map['total_count'] as int,
      );
}
