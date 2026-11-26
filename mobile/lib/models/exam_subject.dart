import 'localized_text.dart';
import 'question.dart';

/// Môn thi thử, gom 1 hoặc nhiều `category` (bao gồm 20 khối kiến thức) trong ngân hàng câu hỏi.
class ExamSubject {
  const ExamSubject({
    required this.id,
    required this.name,
    required this.categories,
    this.blockCategories = const {},
    this.blockSummary = '',
  });

  final String id;
  final LocalizedText name;
  final Set<String> categories;

  /// Các khối kiến thức trong ngân hàng 300 câu (Khối 1 -> Khối 20) thuộc môn thi này.
  final Set<String> blockCategories;

  /// Mô tả tóm tắt phạm vi các khối kiến thức hiển thị trên màn chọn môn.
  final String blockSummary;

  /// Kiểm tra câu hỏi có thuộc phạm vi môn thi này hay không.
  bool matches(Question question) {
    final normalized = question.category.trim().toLowerCase();
    return categories.any((c) => c.toLowerCase() == normalized) ||
        blockCategories.any((c) => c.toLowerCase() == normalized);
  }

  /// 3 môn thi thử mặc định gom trọn vẹn 20 khối kiến thức (300 câu) trong `questions.json`.
  static const List<ExamSubject> defaults = [
    ExamSubject(
      id: 'grammar',
      name: LocalizedText(vi: 'Ngữ pháp', en: 'Grammar'),
      categories: {'grammar'},
      blockSummary: 'Khối 1 – Khối 6: Ngôn ngữ Dart, Công cụ, Widget & Giao diện',
      blockCategories: {
        'Khối 1. Ngôn ngữ Dart',
        'Khối 2. Môi trường và công cụ',
        'Khối 3. Cách Flutter hoạt động',
        'Khối 4. Bố cục và cuộn',
        'Khối 5. Thiết kế và giao diện chung',
        'Khối 6. Thích ứng và co giãn',
      },
    ),
    ExamSubject(
      id: 'vocabulary',
      name: LocalizedText(vi: 'Từ vựng', en: 'Vocabulary'),
      categories: {'vocabulary'},
      blockSummary: 'Khối 7 – Khối 12: Biểu mẫu, Đa phương tiện, Điều hướng & State',
      blockCategories: {
        'Khối 7. Tương tác và biểu mẫu',
        'Khối 8. Tài nguyên và đa phương tiện',
        'Khối 9. Điều hướng',
        'Khối 10. Hoạt ảnh',
        'Khối 11. Trợ năng và đa ngôn ngữ',
        'Khối 12. Quản lý trạng thái',
      },
    ),
    ExamSubject(
      id: 'flutter_network',
      name: LocalizedText(vi: 'Flutter & Mạng', en: 'Flutter & Network'),
      categories: {'flutter', 'network'},
      blockSummary: 'Khối 13 – Khối 20: Backend, Kiến trúc, Kiểm thử, Hiệu năng & AI',
      blockCategories: {
        'Khối 13. Dữ liệu và backend',
        'Khối 14. Kiến trúc ứng dụng',
        'Khối 15. Gói và plugin',
        'Khối 16. Kiểm thử và gỡ lỗi',
        'Khối 17. Hiệu năng',
        'Khối 18. Tích hợp nền tảng và mã gốc',
        'Khối 19. Triển khai',
        'Khối 20. AI trong Flutter',
      },
    ),
  ];
}
