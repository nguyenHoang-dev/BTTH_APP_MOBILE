import 'package:bilingual_quiz/core/errors/app_exception.dart';
import 'package:bilingual_quiz/models/localized_text.dart';
import 'package:bilingual_quiz/models/question.dart';
import 'package:bilingual_quiz/models/quiz_result.dart';
import 'package:bilingual_quiz/repositories/history_repository.dart';
import 'package:bilingual_quiz/repositories/quiz_repository.dart';

/// Tạo câu hỏi giả: đáp án đúng luôn ở index [correct].
Question fakeQuestion(int id, {int correct = 0, String category = 'test'}) => Question(
      id: id,
      category: category,
      content: LocalizedText(vi: 'Câu hỏi $id', en: 'Question $id'),
      options: const [
        LocalizedText(vi: 'A-vi', en: 'A-en'),
        LocalizedText(vi: 'B-vi', en: 'B-en'),
        LocalizedText(vi: 'C-vi', en: 'C-en'),
        LocalizedText(vi: 'D-vi', en: 'D-en'),
      ],
      correctIndex: correct,
    );

/// Fake QuizRepository – thay cho AssetQuizRepository khi test.
class FakeQuizRepository implements QuizRepository {
  FakeQuizRepository({this.questions = const [], this.error});

  final List<Question> questions;
  final AppException? error;

  @override
  Future<List<Question>> loadAllQuestions() async {
    if (error != null) throw error!;
    return questions;
  }
}

/// Fake HistoryRepository – lưu trong RAM thay vì SQLite.
class FakeHistoryRepository implements HistoryRepository {
  final List<QuizResult> saved = [];
  Set<int> wrongIds = {};
  bool failOnSave = false;

  @override
  Future<int> saveResult(QuizResult result) async {
    if (failOnSave) throw const AppException('Không lưu được kết quả làm bài.');
    saved.add(result);
    return saved.length;
  }

  @override
  Future<List<QuizResult>> getResults({int limit = 50}) async => saved;

  @override
  Future<Set<int>> getWrongQuestionIds() async => wrongIds;
}

