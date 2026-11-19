import 'dart:async';

import 'package:bilingual_quiz/core/errors/app_exception.dart';
import 'package:bilingual_quiz/core/state/view_state.dart';
import 'package:bilingual_quiz/models/ai_explanation.dart';
import 'package:bilingual_quiz/models/localized_text.dart';
import 'package:bilingual_quiz/models/quiz_result.dart';
import 'package:bilingual_quiz/providers/ai_provider.dart';
import 'package:bilingual_quiz/providers/settings_provider.dart';
import 'package:bilingual_quiz/repositories/ai_repository.dart';
import 'package:bilingual_quiz/repositories/demo_ai_repository.dart';
import 'package:bilingual_quiz/screens/ai_explanation_dialog.dart';
import 'package:bilingual_quiz/services/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers/fakes.dart';

void main() {
  final sampleAnswer = UserAnswer(
    question: fakeQuestion(10, correct: 2),
    selectedIndex: 0,
  );
  final zeroLatencyDemo = DemoAIRepository(latency: Duration.zero);

  group('TV5 - Kiểm thử ApiClient, AIRepositoryImpl & AIProvider', () {
    test('1. ApiClient timeout -> chuyển DioException thành AppException(type: timeout)', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://timeout.test'))
        ..httpClientAdapter = _TimeoutAdapter();
      final client = ApiClient(baseUrl: 'http://timeout.test', dio: dio);

      expect(
        () => client.post('/api/explain', body: {'question': 'test'}),
        throwsA(
          isA<AppException>()
              .having((e) => e.type, 'type', AppErrorType.timeout)
              .having((e) => e.isConnectivityIssue, 'isConnectivityIssue', isTrue),
        ),
      );
    });

    test('2. AIRepositoryImpl ở Chế độ Demo -> trả dữ liệu Demo và không gọi mạng', () async {
      final adapter = _OfflineAdapter();
      final client = ApiClient(
        baseUrl: 'http://demo.test',
        dio: Dio()..httpClientAdapter = adapter,
      );
      final repo = AIRepositoryImpl(
        apiClient: client,
        isDemoMode: () => true,
        demoRepository: zeroLatencyDemo,
      );

      final explanation = await repo.explainAnswer(sampleAnswer, language: AppLanguage.vi);

      expect(explanation.isDemo, isTrue);
      expect(explanation.source, AISource.demo);
      expect(adapter.calls, 0);
    });

    test('3. AIRepositoryImpl tự động fallback sang Demo khi mất mạng hoặc timeout', () async {
      final client = ApiClient(
        baseUrl: 'http://offline.test',
        dio: Dio()..httpClientAdapter = _OfflineAdapter(),
      );
      final repo = AIRepositoryImpl(
        apiClient: client,
        isDemoMode: () => false,
        demoRepository: zeroLatencyDemo,
      );

      final explanation = await repo.explainAnswer(sampleAnswer, language: AppLanguage.vi);

      expect(explanation.isDemo, isTrue);
      expect(explanation.notice, isNotNull);
      expect(explanation.notice, contains('Đang hiển thị dữ liệu Demo'));
    });

    test('4. AIProvider chống race-condition: bỏ qua kết quả của request cũ về muộn', () async {
      final repo = _ControllableAIRepository();
      final provider = AIProvider(aiRepository: repo);

      final answer1 = UserAnswer(question: fakeQuestion(1, correct: 1), selectedIndex: 0);
      final answer2 = UserAnswer(question: fakeQuestion(2, correct: 2), selectedIndex: 0);

      // Gọi request 1 (chưa hoàn thành) rồi gọi tiếp request 2 ngay lập tức.
      final future1 = provider.explainAnswer(answer1, AppLanguage.vi);
      final future2 = provider.explainAnswer(answer2, AppLanguage.vi);

      // Request 2 hoàn thành trước.
      repo.completers[1].complete(
        const AIExplanation(
          whyWrong: 'Giải thích câu 2',
          correctExplanation: 'Đúng câu 2',
          example: 'Ví dụ 2',
          tip: 'Mẹo 2',
          source: AISource.gemini,
        ),
      );
      await future2;

      expect(provider.state, isA<SuccessState<AIExplanation>>());
      expect((provider.state as SuccessState<AIExplanation>).data.whyWrong, 'Giải thích câu 2');

      // Request 1 hoàn thành muộn sau đó -> không được ghi đè kết quả của request 2.
      repo.completers[0].complete(
        const AIExplanation(
          whyWrong: 'Giải thích câu 1 (cũ)',
          correctExplanation: 'Đúng câu 1',
          example: 'Ví dụ 1',
          tip: 'Mẹo 1',
          source: AISource.gemini,
        ),
      );
      await future1;

      final current = (provider.state as SuccessState<AIExplanation>).data;
      expect(current.whyWrong, 'Giải thích câu 2');
    });

    testWidgets('5. AIExplanationDialog hiển thị rõ câu hỏi, đáp án đã chọn, đáp án đúng & nút Sao chép',
        (tester) async {
      final aiProvider = AIProvider(aiRepository: zeroLatencyDemo);
      final settingsProvider = SettingsProvider(demoMode: true, language: AppLanguage.vi);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settingsProvider),
            ChangeNotifierProvider.value(value: aiProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AIExplanationDialog(answer: sampleAnswer),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ai_dialog_question_header')), findsOneWidget);
      expect(find.text('Câu hỏi 10'), findsOneWidget);
      expect(find.textContaining('Bạn chọn: A-vi'), findsOneWidget);
      expect(find.textContaining('Đáp án đúng: C-vi'), findsOneWidget);
      expect(find.byKey(const Key('copy_explanation_button')), findsOneWidget);
    });
  });
}

class _TimeoutAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw DioException.receiveTimeout(
      timeout: const Duration(seconds: 15),
      requestOptions: options,
    );
  }

  @override
  void close({bool force = false}) {}
}

class _OfflineAdapter implements HttpClientAdapter {
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    calls++;
    throw DioException.connectionError(requestOptions: options, reason: 'offline');
  }

  @override
  void close({bool force = false}) {}
}

class _ControllableAIRepository implements AIRepository {
  final List<Completer<AIExplanation>> completers = [];

  @override
  Future<AIExplanation> explainAnswer(UserAnswer answer, {required AppLanguage language}) {
    final c = Completer<AIExplanation>();
    completers.add(c);
    return c.future;
  }
}
