import 'localized_text.dart';
import 'question.dart';

/// Môn thi thử, gom 1 hoặc nhiều `category` trong ngân hàng câu hỏi.
class ExamSubject {
  const ExamSubject({
    required this.id,
    required this.name,
    required this.categories,
  });

  final String id;
  final LocalizedText name;
  final Set<String> categories;

  /// Kiểm tra câu hỏi có thuộc phạm vi môn thi này hay không.
  bool matches(Question question) {
    final normalized = question.category.trim().toLowerCase();
    return categories.any((c) => c.toLowerCase() == normalized);
  }

  /// 3 môn thi thử mặc định tương ứng với 4 category trong `questions.json`.
  static const List<ExamSubject> defaults = [
    ExamSubject(
      id: 'grammar',
      name: LocalizedText(vi: 'Ngữ pháp', en: 'Grammar'),
      categories: {'grammar'},
    ),
    ExamSubject(
      id: 'vocabulary',
      name: LocalizedText(vi: 'Từ vựng', en: 'Vocabulary'),
      categories: {'vocabulary'},
    ),
    ExamSubject(
      id: 'flutter_network',
      name: LocalizedText(vi: 'Flutter & Mạng', en: 'Flutter & Network'),
      categories: {'flutter', 'network'},
    ),
  ];
}

