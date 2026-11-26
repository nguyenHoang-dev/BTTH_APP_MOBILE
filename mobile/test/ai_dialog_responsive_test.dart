import 'package:bilingual_quiz/models/quiz_result.dart';
import 'package:bilingual_quiz/providers/ai_provider.dart';
import 'package:bilingual_quiz/providers/settings_provider.dart';
import 'package:bilingual_quiz/repositories/demo_ai_repository.dart';
import 'package:bilingual_quiz/screens/ai_explanation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers/fakes.dart';

void main() {
  testWidgets('AI dialog fits phone and large screens without overflow', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final answer = UserAnswer(
      question: fakeQuestion(1, correct: 2),
      selectedIndex: 0,
    );

    for (final size in [const Size(320, 568), const Size(1280, 800)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => SettingsProvider(demoMode: true),
            ),
            ChangeNotifierProvider(
              create: (_) => AIProvider(
                aiRepository: DemoAIRepository(latency: Duration.zero),
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: AIExplanationDialog(answer: answer)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('ai_dialog_question_header')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
