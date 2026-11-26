import '../models/ai_explanation.dart';
import '../models/localized_text.dart';
import '../models/quiz_result.dart';
import 'ai_repository.dart';

/// Mock AI – chạy được 100% offline, không cần server hay API key.
/// Dùng cho: Demo Mode, fallback khi mất mạng, và trong test.
class DemoAIRepository implements AIRepository {
  DemoAIRepository({this.latency = const Duration(milliseconds: 800)});

  /// Giả lập độ trễ mạng để UI hiển thị trạng thái Loading.
  final Duration latency;

  @override
  Future<AIExplanation> explainAnswer(UserAnswer answer, {required AppLanguage language}) async {
    await Future<void>.delayed(latency);

    final isEn = language == AppLanguage.en;
    final lang = isEn ? AppLanguage.en : AppLanguage.vi;
    final q = answer.question;
    final correct = q.correctOption.resolve(lang);
    final hasSelection = answer.selectedIndex >= 0 && answer.selectedIndex < q.options.length;
    final selected = hasSelection ? q.options[answer.selectedIndex].resolve(lang) : '—';
    // Ưu tiên giải thích tĩnh có sẵn trong ngân hàng câu hỏi.
    final staticExplain = q.explanation?.resolve(lang);

    return AIExplanation(
      source: AISource.demo,
      whyWrong: isEn
          ? '"$selected" is not correct for this question.'
          : '"$selected" chưa đúng với yêu cầu của câu hỏi.',
      correctExplanation: staticExplain ??
          (isEn ? 'The correct answer is "$correct".' : 'Đáp án đúng là "$correct".'),
      example: isEn
          ? 'Example (demo): try applying "$correct" in a similar sentence.'
          : 'Ví dụ (demo): hãy thử áp dụng "$correct" vào một câu tương tự.',
      tip: isEn
          ? 'Tip: turn off Demo Mode and start the Node.js server for a real AI explanation.'
          : 'Mẹo: tắt Chế độ Demo và chạy server Node.js để nhận giải thích AI thật.',
    );
  }
}

