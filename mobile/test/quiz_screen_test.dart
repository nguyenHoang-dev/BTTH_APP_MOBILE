import 'package:bilingual_quiz/core/errors/app_exception.dart';
import 'package:bilingual_quiz/models/localized_text.dart';
import 'package:bilingual_quiz/providers/history_provider.dart';
import 'package:bilingual_quiz/providers/quiz_provider.dart';
import 'package:bilingual_quiz/providers/settings_provider.dart';
import 'package:bilingual_quiz/screens/home_screen.dart';
import 'package:bilingual_quiz/screens/qr_question_screen.dart';
import 'package:bilingual_quiz/screens/quiz_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers/fakes.dart';

/// Dựng QuizScreen với repository giả (không đọc asset, không SQLite).
Widget _buildTestApp(FakeQuizRepository quizRepo) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => SettingsProvider(demoMode: true)),
      ChangeNotifierProvider(
        create: (_) => QuizProvider(
          quizRepository: quizRepo,
          historyRepository: FakeHistoryRepository(),
          questionsPerQuiz: 3,
        ),
      ),
    ],
    child: const MaterialApp(home: QuizScreen()),
  );
}

/// Dựng HomeScreen với repository giả để test luồng bấm nút Thi thử -> chọn 1 trong 3 môn.
Widget _buildHomeApp(
  FakeQuizRepository quizRepo, {
  AppLanguage language = AppLanguage.vi,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(demoMode: true, language: language),
      ),
      ChangeNotifierProvider(
        create: (_) => QuizProvider(
          quizRepository: quizRepo,
          historyRepository: FakeHistoryRepository(),
        ),
      ),
      ChangeNotifierProvider(
        create: (_) => HistoryProvider(historyRepository: FakeHistoryRepository()),
      ),
    ],
    child: const MaterialApp(home: HomeScreen()),
  );
}

void main() {
  testWidgets('Hiển thị Loading rồi câu hỏi đầu tiên', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        FakeQuizRepository(questions: List.generate(3, fakeQuestion)),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('question_text')), findsOneWidget);
    expect(find.byKey(const Key('option_0')), findsOneWidget);
    expect(find.text('Câu 1/3  •  test'), findsOneWidget);
  });

  testWidgets('Chọn đáp án & chuyển câu tiếp', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        FakeQuizRepository(questions: List.generate(3, fakeQuestion)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('option_1')));
    await tester.tap(find.byKey(const Key('next_button')));
    await tester.pumpAndSettle();

    expect(find.text('Câu 2/3  •  test'), findsOneWidget);
  });

  testWidgets('Repository lỗi -> hiển thị thông báo & nút Thử lại', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        FakeQuizRepository(
          error: const AppException('Không đọc được ngân hàng câu hỏi.'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Không đọc được ngân hàng câu hỏi.'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('Ngân hàng rỗng -> hiển thị trạng thái Rỗng', (tester) async {
    await tester.pumpWidget(_buildTestApp(FakeQuizRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Ngân hàng câu hỏi đang trống.'), findsOneWidget);
  });

  testWidgets('Bố cục câu hỏi không tràn ở màn hình nhỏ và lớn', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in [const Size(320, 568), const Size(1280, 800)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        _buildTestApp(
          FakeQuizRepository(questions: List.generate(3, fakeQuestion)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('question_text')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  group('Luồng Thi thử theo 3 môn', () {
    final bank = [
      fakeQuestion(1, category: 'grammar'),
      fakeQuestion(5, category: 'grammar'),
      fakeQuestion(8, category: 'grammar'),
      fakeQuestion(2, category: 'vocabulary'),
      fakeQuestion(6, category: 'vocabulary'),
      fakeQuestion(3, category: 'flutter'),
      fakeQuestion(9, category: 'network'),
    ];

    testWidgets('Bấm nút Thi thử hiện đúng 3 môn cần thi', (tester) async {
      await tester.pumpWidget(_buildHomeApp(FakeQuizRepository(questions: bank)));
      await tester.pumpAndSettle();

      expect(find.text('Thi thử'), findsOneWidget);
      await tester.tap(find.byKey(const Key('mock_exam_button')));
      await tester.pumpAndSettle();

      expect(find.text('Chọn môn thi thử'), findsOneWidget);
      expect(find.byKey(const Key('subject_grammar')), findsOneWidget);
      expect(find.byKey(const Key('subject_vocabulary')), findsOneWidget);
      expect(find.byKey(const Key('subject_flutter_network')), findsOneWidget);
      expect(find.text('3 câu  •  grammar'), findsOneWidget);
      expect(find.text('2 câu  •  vocabulary'), findsOneWidget);
      expect(find.text('2 câu  •  flutter, network'), findsOneWidget);
    });

    testWidgets('Chọn môn Từ vựng chỉ thi các câu vocabulary', (tester) async {
      await tester.pumpWidget(_buildHomeApp(FakeQuizRepository(questions: bank)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mock_exam_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('subject_vocabulary')));
      await tester.pumpAndSettle();

      expect(find.text('Thi thử: Từ vựng'), findsOneWidget);
      expect(find.text('Câu 1/2  •  vocabulary'), findsOneWidget);

      await tester.tap(find.byKey(const Key('next_button')));
      await tester.pumpAndSettle();

      expect(find.text('Câu 2/2  •  vocabulary'), findsOneWidget);
      expect(find.byKey(const Key('submit_button')), findsOneWidget);
    });

    testWidgets('Chọn môn Flutter & Mạng chỉ thi các câu flutter và network', (tester) async {
      await tester.pumpWidget(_buildHomeApp(FakeQuizRepository(questions: bank)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mock_exam_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('subject_flutter_network')));
      await tester.pumpAndSettle();

      expect(find.text('Thi thử: Flutter & Mạng'), findsOneWidget);

      final firstMeta = tester.widget<Text>(find.textContaining('Câu 1/2')).data!;
      expect(firstMeta == 'Câu 1/2  •  flutter' || firstMeta == 'Câu 1/2  •  network', isTrue);

      await tester.tap(find.byKey(const Key('next_button')));
      await tester.pumpAndSettle();

      final secondMeta = tester.widget<Text>(find.textContaining('Câu 2/2')).data!;
      expect(secondMeta == 'Câu 2/2  •  flutter' || secondMeta == 'Câu 2/2  •  network', isTrue);
      expect(secondMeta, isNot(equals(firstMeta)));
    });

    testWidgets('PopScope chặn nút Back khi đang thi thử: Ở lại hoặc Thoát & Nộp bài', (
      tester,
    ) async {
      await tester.pumpWidget(_buildHomeApp(FakeQuizRepository(questions: bank)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mock_exam_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('subject_vocabulary')));
      await tester.pumpAndSettle();

      // Chọn 1 đáp án rồi bấm Back trên AppBar
      await tester.tap(find.byKey(const Key('option_0')));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Cảnh báo thoát bài thi'), findsOneWidget);
      expect(find.byKey(const Key('stay_in_quiz_button')), findsOneWidget);
      expect(find.byKey(const Key('exit_and_submit_button')), findsOneWidget);

      // Chọn "Ở lại làm tiếp" -> đóng dialog, vẫn ở màn thi thử
      await tester.tap(find.byKey(const Key('stay_in_quiz_button')));
      await tester.pumpAndSettle();
      expect(find.text('Cảnh báo thoát bài thi'), findsNothing);
      expect(find.text('Thi thử: Từ vựng'), findsOneWidget);

      // Bấm Back lần nữa -> chọn "Thoát & Nộp bài" -> chuyển thẳng sang màn Kết quả
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('exit_and_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Kết quả'), findsOneWidget);
    });

    test('QrQuestionCodec mã hóa và giải mã câu hỏi song ngữ chính xác', () {
      final sample = QrQuestionCodec.sampleQrQuestion();
      final encoded = QrQuestionCodec.encode(sample);
      final decoded = QrQuestionCodec.decode(encoded);

      expect(decoded.category, equals(sample.category));
      expect(decoded.content.vi, equals(sample.content.vi));
      expect(decoded.content.en, equals(sample.content.en));
      expect(decoded.options.length, equals(4));
      expect(decoded.correctIndex, equals(sample.correctIndex));
    });
  });
}
