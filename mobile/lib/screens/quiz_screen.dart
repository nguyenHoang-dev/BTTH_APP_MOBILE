import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/state/view_state.dart';
import '../models/exam_subject.dart';
import '../models/localized_text.dart';
import '../providers/quiz_provider.dart';
import '../providers/settings_provider.dart';
import 'result_screen.dart';
import 'widgets/state_views.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, this.onlyWrong = false, this.subject});

  final bool onlyWrong;
  final ExamSubject? subject;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() => context.read<QuizProvider>().startQuiz(
        onlyWrong: widget.onlyWrong,
        subject: widget.subject,
      );

  String _buildTitle(AppLanguage lang) {
    if (widget.onlyWrong) return 'Ôn câu sai';
    final subject = widget.subject;
    if (subject == null) return 'Làm bài';
    final subjectName = subject.name.resolve(
      lang == AppLanguage.both ? AppLanguage.vi : lang,
    );
    return 'Thi thử: $subjectName';
  }

  Future<void> _submit(QuizProvider quiz) async {
    final unanswered = quiz.questions.length - quiz.answeredCount;
    if (unanswered > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Nộp bài?'),
          content: Text('Còn $unanswered câu chưa trả lời (sẽ tính là sai).'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Làm tiếp'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Nộp bài'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    final result = await quiz.submit();
    if (!mounted) return;
    final warning = quiz.saveWarning;
    if (warning != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(warning)));
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => ResultScreen(result: result)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quiz = context.watch<QuizProvider>();
    final lang = context.select<SettingsProvider, AppLanguage>((s) => s.language);

    return Scaffold(
      appBar: AppBar(title: Text(_buildTitle(lang))),
      body: switch (quiz.state) {
        IdleState() ||
        LoadingState() => const LoadingView(message: 'Đang nạp câu hỏi...'),
        ErrorState(:final message) => ErrorView(
          message: message,
          onRetry: _start,
        ),
        EmptyState(:final message) => EmptyView(
          message: message,
          action: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Quay lại'),
          ),
        ),
        SuccessState() => _QuizBody(quiz: quiz, onSubmit: () => _submit(quiz)),
      },
    );
  }
}

class _QuizBody extends StatelessWidget {
  const _QuizBody({required this.quiz, required this.onSubmit});
  final QuizProvider quiz;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final lang = context.select<SettingsProvider, AppLanguage>(
      (s) => s.language,
    );
    final q = quiz.currentQuestion!;
    final total = quiz.questions.length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(value: (quiz.currentIndex + 1) / total),
          const SizedBox(height: 8),
          Text('Câu ${quiz.currentIndex + 1}/$total  •  ${q.category}'),
          const SizedBox(height: 12),
          Text(
            q.content.resolve(lang),
            key: const Key('question_text'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: q.options.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final selected = quiz.selectedIndexForCurrent == i;
                return Card(
                  color: selected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  child: ListTile(
                    key: Key('option_$i'),
                    leading: CircleAvatar(
                      child: Text(String.fromCharCode(65 + i)),
                    ),
                    title: Text(q.options[i].resolve(lang)),
                    onTap: () => quiz.selectAnswer(i),
                  ),
                );
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: quiz.isFirst ? null : quiz.previous,
                  child: const Text(
                    'Câu trước',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: quiz.isLast
                    ? FilledButton(
                        key: const Key('submit_button'),
                        onPressed: quiz.isSubmitting ? null : onSubmit,
                        child: quiz.isSubmitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Nộp bài',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                      )
                    : FilledButton(
                        key: const Key('next_button'),
                        onPressed: quiz.next,
                        child: const Text(
                          'Câu tiếp',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
