import 'localized_text.dart';

/// Một câu hỏi trắc nghiệm song ngữ (đọc từ assets/data/questions.json).
class Question {
  const Question({
    required this.id,
    required this.category,
    required this.content,
    required this.options,
    required this.correctIndex,
    this.explanation,
  });

  final int id;
  final String category;
  final LocalizedText content;
  final List<LocalizedText> options;
  final int correctIndex;

  /// Giải thích tĩnh có sẵn trong ngân hàng câu hỏi (offline).
  final LocalizedText? explanation;

  bool isCorrect(int selectedIndex) => selectedIndex == correctIndex;

  LocalizedText get correctOption => options[correctIndex];

  factory Question.fromJson(Map<String, dynamic> json) {
    final options = (json['options'] as List)
        .map((e) => LocalizedText.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    final correctIndex = json['correctIndex'] as int;
    if (correctIndex < 0 || correctIndex >= options.length) {
      throw FormatException('Câu ${json['id']}: correctIndex vượt quá số lựa chọn');
    }
    return Question(
      id: json['id'] as int,
      category: (json['category'] ?? 'general') as String,
      content: LocalizedText.fromJson(json['question'] as Map<String, dynamic>),
      options: options,
      correctIndex: correctIndex,
      explanation: json['explanation'] == null
          ? null
          : LocalizedText.fromJson(json['explanation'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'question': content.toJson(),
        'options': options.map((e) => e.toJson()).toList(),
        'correctIndex': correctIndex,
        if (explanation != null) 'explanation': explanation!.toJson(),
      };
}

