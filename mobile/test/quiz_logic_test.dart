import 'dart:math';

import 'package:bilingual_quiz/core/errors/app_exception.dart';
import 'package:bilingual_quiz/core/logic/quiz_engine.dart';
import 'package:bilingual_quiz/core/state/view_state.dart';
import 'package:bilingual_quiz/models/ai_explanation.dart';
import 'package:bilingual_quiz/models/exam_subject.dart';
import 'package:bilingual_quiz/models/localized_text.dart';
import 'package:bilingual_quiz/models/question.dart';
import 'package:bilingual_quiz/models/quiz_result.dart';
import 'package:bilingual_quiz/providers/quiz_provider.dart';
import 'package:bilingual_quiz/repositories/ai_repository.dart';
import 'package:bilingual_quiz/repositories/demo_ai_repository.dart';
import 'package:bilingual_quiz/repositories/quiz_repository.dart';
import 'package:bilingual_quiz/services/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const engine = QuizEngine();

  group('QuizEngine.pickRandom', () {
    final bank = List.generate(300, (i) => fakeQuestion(i));

    test('lấy đúng số lượng & không trùng lặp', () {
      final picked = engine.pickRandom(bank, 20, random: Random(1));
      expect(picked, hasLength(20));
      expect(picked.map((q) => q.id).toSet(), hasLength(20));
    });

    test('ngân hàng ít hơn số câu yêu cầu -> lấy hết', () {
      expect(engine.pickRandom(bank.take(5).toList(), 20), hasLength(5));
    });

    test('ngân hàng rỗng -> danh sách rỗng', () {
      expect(engine.pickRandom(const [], 20), isEmpty);
    });
  });

  group('QuizEngine.prepareSubjectExam – 3 môn & đảo thứ tự', () {
    final bank = [
      fakeQuestion(1, category: 'grammar'),
      fakeQuestion(2, category: 'vocabulary'),
      fakeQuestion(3, category: 'flutter'),
      fakeQuestion(4, category: 'flutter'),
      fakeQuestion(5, category: 'grammar'),
      fakeQuestion(6, category: 'vocabulary'),
      fakeQuestion(7, category: 'flutter'),
      fakeQuestion(8, category: 'grammar'),
      fakeQuestion(9, category: 'network'),
      fakeQuestion(10, category: 'vocabulary'),
    ];

    test('chọn môn nào chỉ lấy toàn bộ câu của môn đó', () {
      final grammar = ExamSubject.defaults[0];
      final vocabulary = ExamSubject.defaults[1];
      final flutterNet = ExamSubject.defaults[2];

      final gPicked = engine.prepareSubjectExam(bank, grammar, random: Random(1));
      expect(gPicked.map((q) => q.id).toSet(), {1, 5, 8});
      expect(gPicked.every((q) => q.category == 'grammar'), isTrue);

      final vPicked = engine.prepareSubjectExam(bank, vocabulary, random: Random(1));
      expect(vPicked.map((q) => q.id).toSet(), {2, 6, 10});
      expect(vPicked.every((q) => q.category == 'vocabulary'), isTrue);

      final fPicked = engine.prepareSubjectExam(bank, flutterNet, random: Random(1));
      expect(fPicked.map((q) => q.id).toSet(), {3, 4, 7, 9});
      expect(
        fPicked.every((q) => q.category == 'flutter' || q.category == 'network'),
        isTrue,
      );
    });

    test('mỗi lần thi đảo thứ tự câu trong phạm vi môn đó', () {
      final grammar = ExamSubject.defaults[0];
      final first = engine.prepareSubjectExam(bank, grammar, random: Random(1));
      final second = engine.prepareSubjectExam(bank, grammar, random: Random(7));

      expect(first.map((q) => q.id).toSet(), {1, 5, 8});
      expect(second.map((q) => q.id).toSet(), {1, 5, 8});
      expect(first.map((q) => q.id).toList(), isNot(equals(second.map((q) => q.id).toList())));
    });

    test('AssetQuizRepository map đủ 10/10 câu của questions.json vào 3 môn', () async {
      final questions = await AssetQuizRepository().loadAllQuestions();
      final totalMapped = ExamSubject.defaults
          .map((s) => engine.prepareSubjectExam(questions, s).length)
          .reduce((a, b) => a + b);

      expect(questions, hasLength(10));
      expect(totalMapped, 10);
    });
  });

  group('QuizProvider – thi thử theo môn', () {
    test('startQuiz(subject) lấy toàn bộ câu của môn (kể cả > questionsPerQuiz)', () async {
      final bank = [
        for (var i = 1; i <= 5; i++) fakeQuestion(i, category: 'grammar'),
        for (var i = 6; i <= 10; i++) fakeQuestion(i, category: 'vocabulary'),
      ];
      final provider = QuizProvider(
        quizRepository: FakeQuizRepository(questions: bank),
        historyRepository: FakeHistoryRepository(),
        questionsPerQuiz: 2,
      );

      await provider.loadSubjectCounts();
      expect(provider.subjectCounts['grammar'], 5);
      expect(provider.subjectCounts['vocabulary'], 5);
      expect(provider.subjectCounts['flutter_network'], 0);

      await provider.startQuiz(subject: ExamSubject.defaults[0], random: Random(3));
      expect(provider.questions, hasLength(5));
      expect(provider.questions.every((q) => q.category == 'grammar'), isTrue);
    });

    test('môn chưa có câu hỏi -> EmptyState', () async {
      final provider = QuizProvider(
        quizRepository: FakeQuizRepository(questions: [fakeQuestion(1, category: 'grammar')]),
        historyRepository: FakeHistoryRepository(),
      );

      await provider.startQuiz(subject: ExamSubject.defaults[1]);
      expect(provider.state, isA<EmptyState<List<Question>>>());
    });
  });

  group('QuizEngine.grade', () {
    test('chấm đúng/sai/chưa trả lời', () {
      final qs = [fakeQuestion(1), fakeQuestion(2), fakeQuestion(3), fakeQuestion(4)];
      final result = engine.grade(
        questions: qs,
        answers: {0: 0, 1: 0, 2: 3}, // câu 4 bỏ trống
        duration: const Duration(minutes: 2),
        takenAt: DateTime(2026),
      );
      expect(result.correctCount, 2);
      expect(result.wrongCount, 2);
      expect(result.score10, 5.0);
      expect(result.wrongAnswers.map((w) => w.selectedIndex), [3, QuizEngine.unanswered]);
    });
  });

  group('Question.fromJson', () {
    test('correctIndex vượt phạm vi -> FormatException', () {
      expect(
        () => Question.fromJson({
          'id': 1,
          'question': {'vi': 'x', 'en': 'x'},
          'options': [
            {'vi': 'a', 'en': 'a'},
          ],
          'correctIndex': 3,
        }),
        throwsFormatException,
      );
    });

    test('LocalizedText.resolve song ngữ', () {
      const t = LocalizedText(vi: 'Xin chào', en: 'Hello');
      expect(t.resolve(AppLanguage.both), 'Xin chào\nHello');
      expect(t.resolve(AppLanguage.en), 'Hello');
    });
  });

  group('QuizProvider – 3 trạng thái Loading / Error / Empty', () {
    test('thành công -> SuccessState + lưu lịch sử khi nộp', () async {
      final history = FakeHistoryRepository();
      final provider = QuizProvider(
        quizRepository: FakeQuizRepository(questions: List.generate(30, fakeQuestion)),
        historyRepository: history,
        questionsPerQuiz: 10,
      );

      final future = provider.startQuiz();
      expect(provider.state, isA<LoadingState<List<Question>>>());
      await future;

      expect(provider.state, isA<SuccessState<List<Question>>>());
      expect(provider.questions, hasLength(10));

      provider.selectAnswer(0);
      final result = await provider.submit();
      expect(result.totalQuestions, 10);
      expect(history.saved, hasLength(1));
    });

    test('repository lỗi -> ErrorState với thông báo thân thiện', () async {
      final provider = QuizProvider(
        quizRepository: FakeQuizRepository(error: const AppException('Không đọc được ngân hàng câu hỏi.')),
        historyRepository: FakeHistoryRepository(),
      );
      await provider.startQuiz();
      final state = provider.state as ErrorState<List<Question>>;
      expect(state.message, 'Không đọc được ngân hàng câu hỏi.');
    });

    test('ôn câu sai khi chưa có câu sai -> EmptyState', () async {
      final provider = QuizProvider(
        quizRepository: FakeQuizRepository(questions: List.generate(5, fakeQuestion)),
        historyRepository: FakeHistoryRepository(),
      );
      await provider.startQuiz(onlyWrong: true);
      expect(provider.state, isA<EmptyState<List<Question>>>());
    });

    test('lưu SQLite lỗi vẫn trả kết quả + saveWarning', () async {
      final history = FakeHistoryRepository()..failOnSave = true;
      final provider = QuizProvider(
        quizRepository: FakeQuizRepository(questions: [fakeQuestion(1)]),
        historyRepository: history,
      );
      await provider.startQuiz();
      final result = await provider.submit();
      expect(result.totalQuestions, 1);
      expect(provider.saveWarning, isNotNull);
    });
  });

  group('AIRepositoryImpl – Demo Mode & fallback', () {
    final answer = UserAnswer(question: fakeQuestion(1, correct: 2), selectedIndex: 0);
    final demo = DemoAIRepository(latency: Duration.zero);

    ApiClient offlineClient() {
      final dio = Dio(BaseOptions(baseUrl: 'http://offline.test'))
        ..httpClientAdapter = _OfflineAdapter();
      return ApiClient(baseUrl: 'http://offline.test', dio: dio);
    }

    test('Demo Mode bật -> trả mock, không gọi mạng', () async {
      final adapter = _OfflineAdapter();
      final repo = AIRepositoryImpl(
        apiClient: ApiClient(
          baseUrl: 'http://x',
          dio: Dio()..httpClientAdapter = adapter,
        ),
        isDemoMode: () => true,
        demoRepository: demo,
      );
      final r = await repo.explainAnswer(answer, language: AppLanguage.vi);
      expect(r.source, AISource.demo);
      expect(adapter.calls, 0);
    });

    test('Real Mode + mất mạng -> fallback sang Demo kèm notice', () async {
      final repo = AIRepositoryImpl(
        apiClient: offlineClient(),
        isDemoMode: () => false,
        demoRepository: demo,
      );
      final r = await repo.explainAnswer(answer, language: AppLanguage.vi);
      expect(r.isDemo, isTrue);
      expect(r.notice, contains('Demo'));
    });

    test('Real Mode + mất mạng + tắt fallback -> ném AppException', () async {
      final repo = AIRepositoryImpl(
        apiClient: offlineClient(),
        isDemoMode: () => false,
        demoRepository: demo,
        fallbackToDemo: false,
      );
      expect(
        () => repo.explainAnswer(answer, language: AppLanguage.vi),
        throwsA(isA<AppException>().having((e) => e.isConnectivityIssue, 'connectivity', true)),
      );
    });

    test('request body đúng định dạng server mong đợi', () {
      final body = AIRepositoryImpl.buildRequestBody(answer, AppLanguage.en);
      expect(body['selectedAnswer'], 'A-en');
      expect(body['correctAnswer'], 'C-en');
      expect(body['language'], 'en');
    });
  });
}

/// Adapter giả lập mất mạng: mọi request đều lỗi connectionError.
class _OfflineAdapter implements HttpClientAdapter {
  int calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) {
    calls++;
    throw DioException.connectionError(requestOptions: options, reason: 'offline');
  }

  @override
  void close({bool force = false}) {}
}

