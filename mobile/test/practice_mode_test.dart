import 'package:bilingual_quiz/core/errors/app_exception.dart';
import 'package:bilingual_quiz/core/state/view_state.dart';
import 'package:bilingual_quiz/models/localized_text.dart';
import 'package:bilingual_quiz/models/question.dart';
import 'package:bilingual_quiz/providers/practice_provider.dart';
import 'package:bilingual_quiz/providers/settings_provider.dart';
import 'package:bilingual_quiz/screens/practice_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers/fakes.dart';

Widget _buildPracticeTestApp({
  required FakeQuizRepository quizRepo,
  SettingsProvider? settings,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => settings ?? SettingsProvider(demoMode: true)),
      ChangeNotifierProvider(create: (_) => PracticeProvider(quizRepository: quizRepo)),
    ],
    child: const MaterialApp(home: PracticeScreen()),
  );
}

void main() {
  group('PracticeProvider – Quản lý trạng thái Luyện tập', () {
    late List<Question> sampleQuestions;

    setUp(() {
      sampleQuestions = [
        Question(
          id: 1,
          category: 'grammar',
          content: const LocalizedText(vi: 'Câu 1 vi', en: 'Q1 en'),
          options: const [
            LocalizedText(vi: 'A', en: 'A'),
            LocalizedText(vi: 'B', en: 'B'),
            LocalizedText(vi: 'C', en: 'C'),
            LocalizedText(vi: 'D', en: 'D'),
          ],
          correctIndex: 1, // B là đáp án đúng
          explanation: const LocalizedText(vi: 'Giải thích 1', en: 'Exp 1'),
        ),
        Question(
          id: 2,
          category: 'vocabulary',
          content: const LocalizedText(vi: 'Câu 2 vi', en: 'Q2 en'),
          options: const [
            LocalizedText(vi: 'A', en: 'A'),
            LocalizedText(vi: 'B', en: 'B'),
            LocalizedText(vi: 'C', en: 'C'),
            LocalizedText(vi: 'D', en: 'D'),
          ],
          correctIndex: 0, // A là đáp án đúng
          explanation: const LocalizedText(vi: 'Giải thích 2', en: 'Exp 2'),
        ),
        Question(
          id: 3,
          category: 'grammar',
          content: const LocalizedText(vi: 'Câu 3 vi', en: 'Q3 en'),
          options: const [
            LocalizedText(vi: 'A', en: 'A'),
            LocalizedText(vi: 'B', en: 'B'),
            LocalizedText(vi: 'C', en: 'C'),
            LocalizedText(vi: 'D', en: 'D'),
          ],
          correctIndex: 2, // C là đáp án đúng
          explanation: const LocalizedText(vi: 'Giải thích 3', en: 'Exp 3'),
        ),
      ];
    });

    test('Lọc câu hỏi theo category chính xác', () async {
      final repo = FakeQuizRepository(questions: sampleQuestions);
      final provider = PracticeProvider(quizRepository: repo);

      await provider.loadQuestions();
      expect(provider.totalQuestions, 3);
      expect(provider.categories, containsAll(['grammar', 'vocabulary']));

      // Lọc category grammar
      await provider.selectCategory('grammar');
      expect(provider.totalQuestions, 2);
      expect(provider.selectedCategory, 'grammar');
      expect(provider.questions.every((q) => q.category == 'grammar'), isTrue);

      // Quay lại tất cả
      await provider.selectCategory(null);
      expect(provider.totalQuestions, 3);
      expect(provider.selectedCategory, isNull);
    });

    test('Chọn đáp án phản hồi Đúng/Sai tức thì và khóa không cho chọn lại', () async {
      final repo = FakeQuizRepository(questions: sampleQuestions);
      final provider = PracticeProvider(quizRepository: repo);

      await provider.loadQuestions();
      expect(provider.isAnswered, isFalse);

      // Chọn đáp án SAI (chọn A trong khi B đúng)
      provider.selectOption(0);
      expect(provider.isAnswered, isTrue);
      expect(provider.isCurrentCorrect, isFalse);
      expect(provider.selectedAnswer, 0);
      expect(provider.answeredCount, 1);
      expect(provider.correctCount, 0);

      // Cố gắng chọn lại đáp án khác -> không đổi (đã bị khóa)
      provider.selectOption(1);
      expect(provider.selectedAnswer, 0);

      // Thử lại câu hiện tại
      provider.retryCurrent();
      expect(provider.isAnswered, isFalse);
      expect(provider.selectedAnswer, isNull);
      expect(provider.answeredCount, 0);

      // Giờ chọn ĐÚNG (chọn B)
      provider.selectOption(1);
      expect(provider.isAnswered, isTrue);
      expect(provider.isCurrentCorrect, isTrue);
      expect(provider.correctCount, 1);
      expect(provider.answeredCount, 1);
    });

    test('Điều hướng câu hỏi: next, previous, jumpToQuestion', () async {
      final repo = FakeQuizRepository(questions: sampleQuestions);
      final provider = PracticeProvider(quizRepository: repo);
      await provider.loadQuestions();

      expect(provider.currentIndex, 0);
      expect(provider.isFirst, isTrue);
      expect(provider.isLast, isFalse);

      provider.nextQuestion();
      expect(provider.currentIndex, 1);
      expect(provider.isFirst, isFalse);

      provider.nextQuestion();
      expect(provider.currentIndex, 2);
      expect(provider.isLast, isTrue);

      provider.previousQuestion();
      expect(provider.currentIndex, 1);

      provider.jumpToQuestion(0);
      expect(provider.currentIndex, 0);
    });

    test('Xử lý lỗi repository -> ErrorState thân thiện', () async {
      final repo = FakeQuizRepository(error: const AppException('Lỗi nạp câu hỏi'));
      final provider = PracticeProvider(quizRepository: repo);

      await provider.loadQuestions();
      expect(provider.state, isA<ErrorState<List<Question>>>());
      final errorState = provider.state as ErrorState<List<Question>>;
      expect(errorState.message, 'Lỗi nạp câu hỏi');
    });
  });

  group('PracticeScreen – Widget Tests', () {
    testWidgets('Hiển thị câu hỏi, Category Chips và các lựa chọn ban đầu', (tester) async {
      final sample = [
        Question(
          id: 1,
          category: 'grammar',
          content: const LocalizedText(vi: 'Học tiếng Anh?', en: 'Study English?'),
          options: const [
            LocalizedText(vi: 'Lựa chọn A', en: 'Option A'),
            LocalizedText(vi: 'Lựa chọn B', en: 'Option B'),
            LocalizedText(vi: 'Lựa chọn C', en: 'Option C'),
            LocalizedText(vi: 'Lựa chọn D', en: 'Option D'),
          ],
          correctIndex: 1,
          explanation: const LocalizedText(vi: 'B là đáp án chuẩn', en: 'B is correct'),
        ),
      ];

      final settings = SettingsProvider(language: AppLanguage.vi);
      final repo = FakeQuizRepository(questions: sample);
      await tester.pumpWidget(_buildPracticeTestApp(quizRepo: repo, settings: settings));
      await tester.pumpAndSettle();

      expect(find.text('Học tiếng Anh?'), findsOneWidget);
      expect(find.byKey(const Key('practice_option_0')), findsOneWidget);
      expect(find.byKey(const Key('practice_option_1')), findsOneWidget);
      expect(find.byKey(const Key('practice_option_2')), findsOneWidget);
      expect(find.byKey(const Key('practice_option_3')), findsOneWidget);
      // Chưa chọn nên chưa có nút hỏi AI hay giải thích
      expect(find.byKey(const Key('ask_ai_button')), findsNothing);
    });

    testWidgets('Chọn đáp án: hiện Xanh/Đỏ, giải thích tĩnh và nút Hỏi AI', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sample = [
        Question(
          id: 1,
          category: 'grammar',
          content: const LocalizedText(vi: 'Học tiếng Anh?', en: 'Study English?'),
          options: const [
            LocalizedText(vi: 'Lựa chọn A', en: 'Option A'),
            LocalizedText(vi: 'Lựa chọn B', en: 'Option B'),
            LocalizedText(vi: 'Lựa chọn C', en: 'Option C'),
            LocalizedText(vi: 'Lựa chọn D', en: 'Option D'),
          ],
          correctIndex: 1,
          explanation: const LocalizedText(vi: 'B là đáp án chuẩn', en: 'B is correct'),
        ),
      ];

      final settings = SettingsProvider(language: AppLanguage.vi);
      final repo = FakeQuizRepository(questions: sample);
      await tester.pumpWidget(_buildPracticeTestApp(quizRepo: repo, settings: settings));
      await tester.pumpAndSettle();

      // Bấm chọn đáp án SAI (chọn A - index 0)
      await tester.tap(find.byKey(const Key('practice_option_0')));
      await tester.pumpAndSettle();

      // Hiện icon cancel (đỏ) cho đáp án sai và check_circle (xanh) cho đáp án đúng
      expect(find.byIcon(Icons.cancel), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // Hiển thị phần giải thích tĩnh
      expect(find.byKey(const Key('practice_explanation_text')), findsOneWidget);
      expect(find.text('B là đáp án chuẩn'), findsOneWidget);

      // Hiển thị nút hỏi AI
      expect(find.byKey(const Key('ask_ai_button')), findsOneWidget);
    });

    testWidgets('Đổi ngôn ngữ trên giao diện theo SettingsProvider', (tester) async {
      final sample = [
        Question(
          id: 1,
          category: 'grammar',
          content: const LocalizedText(vi: 'Tiếng Việt', en: 'English text'),
          options: const [
            LocalizedText(vi: 'A-vi', en: 'A-en'),
            LocalizedText(vi: 'B-vi', en: 'B-en'),
            LocalizedText(vi: 'C-vi', en: 'C-en'),
            LocalizedText(vi: 'D-vi', en: 'D-en'),
          ],
          correctIndex: 0,
        ),
      ];

      final settings = SettingsProvider(language: AppLanguage.en);
      final repo = FakeQuizRepository(questions: sample);
      await tester.pumpWidget(_buildPracticeTestApp(quizRepo: repo, settings: settings));
      await tester.pumpAndSettle();

      // Tiêu đề và câu hỏi bằng tiếng Anh
      expect(find.text('English text'), findsOneWidget);
      expect(find.text('Practice Mode'), findsOneWidget);
      expect(find.text('A-en'), findsOneWidget);
    });

    testWidgets('Bấm nút cờ Tổng kết hiển thị Dialog tổng kết phiên', (tester) async {
      final sample = [
        Question(
          id: 1,
          category: 'grammar',
          content: const LocalizedText(vi: 'Câu 1', en: 'Q1'),
          options: const [
            LocalizedText(vi: 'A', en: 'A'),
            LocalizedText(vi: 'B', en: 'B'),
          ],
          correctIndex: 0,
        ),
      ];

      final repo = FakeQuizRepository(questions: sample);
      await tester.pumpWidget(_buildPracticeTestApp(quizRepo: repo));
      await tester.pumpAndSettle();

      // Bấm nút cờ tổng kết trên AppBar
      await tester.tap(find.byKey(const Key('practice_finish_appbar_button')));
      await tester.pumpAndSettle();

      // Hiện AlertDialog tổng kết
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Luyện tiếp • Continue'), findsOneWidget);
      expect(find.text('Trang chủ • Home'), findsOneWidget);
    });
  });
}
