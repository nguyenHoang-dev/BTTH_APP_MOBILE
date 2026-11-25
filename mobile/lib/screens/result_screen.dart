import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/localized_text.dart';
import '../models/quiz_result.dart';
import '../providers/settings_provider.dart';
import 'widgets/state_views.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.result});

  final QuizResult result;

  @override
  Widget build(BuildContext context) {
    final lang = context.select<SettingsProvider, AppLanguage>((s) => s.language);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Kết quả bài thi')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text('${result.score10}', style: theme.textTheme.displayMedium),
                Text('${result.correctCount}/${result.totalQuestions} câu đúng '
                    '(${(result.accuracy * 100).toStringAsFixed(0)}%)'),
                Text('Thời gian: ${result.duration.inMinutes} phút ${result.duration.inSeconds % 60} giây'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: result.wrongAnswers.isEmpty
                ? const EmptyView(message: 'Xuất sắc! Bạn không sai câu nào 🎉')
                : ListView.builder(
                    itemCount: result.wrongAnswers.length,
                    itemBuilder: (_, i) {
                      final w = result.wrongAnswers[i];
                      final q = w.question;
                      final chosen = w.selectedIndex >= 0
                          ? q.options[w.selectedIndex].resolve(lang)
                          : '(Không trả lời)';
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(q.content.resolve(lang), style: theme.textTheme.titleSmall),
                              const SizedBox(height: 6),
                              Text('✗ Bạn chọn (Sai): $chosen',
                                  style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text('✓ Đáp án đúng: ${q.correctOption.resolve(lang)}',
                                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Về trang chủ'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

