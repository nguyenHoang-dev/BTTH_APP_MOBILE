import 'package:bilingual_quiz/core/errors/app_exception.dart';
import 'package:bilingual_quiz/providers/quiz_provider.dart';
import 'package:bilingual_quiz/providers/settings_provider.dart';
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
}
