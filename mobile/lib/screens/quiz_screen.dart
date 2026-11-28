import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/state/view_state.dart';
import '../models/exam_subject.dart';
import '../models/localized_text.dart';
import '../providers/quiz_provider.dart';
import '../providers/settings_provider.dart';
import 'qr_question_screen.dart';
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

  Future<void> _openQuestionPalette(QuizProvider quiz) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _QuestionPaletteSheet(
        quiz: quiz,
        onSubmit: () {
          Navigator.of(context).pop();
          _submit(quiz);
        },
      ),
    );
  }

  Future<void> _submit(QuizProvider quiz) async {
    final unanswered = quiz.questions.length - quiz.answeredCount;
    if (unanswered > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(
            Icons.help_outline_rounded,
            color: Colors.orange,
            size: 36,
          ),
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

    await _gradeAndNavigateToResult(quiz);
  }

  Future<void> _gradeAndNavigateToResult(QuizProvider quiz) async {
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

  /// Cảnh báo thoát khi đang thi thử (PopScope - Mục 1.1 Kế hoạch nâng cấp 8.8).
  Future<void> _confirmExitDuringExam(QuizProvider quiz) async {
    final exitAndSubmit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(ctx).colorScheme.error,
          size: 38,
        ),
        title: const Text('Cảnh báo thoát bài thi'),
        content: const Text(
          'Bạn đang trong giờ thi thử. Nếu thoát ngay bây giờ, bài thi sẽ kết thúc '
          'và tự động chấm điểm dựa trên số câu đã làm. Bạn có chắc chắn muốn thoát?',
        ),
        actions: [
          TextButton(
            key: const Key('stay_in_quiz_button'),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ở lại làm tiếp'),
          ),
          FilledButton(
            key: const Key('exit_and_submit_button'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Thoát & Nộp bài'),
          ),
        ],
      ),
    );
    if (exitAndSubmit == true && mounted) {
      await _gradeAndNavigateToResult(quiz);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quiz = context.watch<QuizProvider>();
    final settings = context.watch<SettingsProvider>();
    final lang = settings.language;
    final isExamActive = quiz.state is SuccessState && !quiz.isSubmitting;

    return PopScope(
      canPop: !isExamActive,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmExitDuringExam(quiz);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_buildTitle(lang)),
          actions: [
            if (quiz.currentQuestion != null)
              IconButton(
                key: const Key('quiz_qr_share_button'),
                tooltip: 'Tạo mã QR chia sẻ câu hỏi',
                icon: const Icon(Icons.qr_code_2_rounded),
                onPressed: () => QrQuestionScreen.showShareSheet(
                  context,
                  quiz.currentQuestion!,
                ),
              ),
            if (quiz.questions.isNotEmpty)
              IconButton(
                key: const Key('quiz_palette_button'),
                tooltip: 'Bảng câu hỏi',
                icon: const Icon(Icons.grid_view_rounded),
                onPressed: () => _openQuestionPalette(quiz),
              ),
            PopupMenuButton<AppLanguage>(
              tooltip: 'Đổi ngôn ngữ',
              icon: const Icon(Icons.language_rounded),
              initialValue: lang,
              onSelected: settings.setLanguage,
              itemBuilder: (_) => [
                for (final l in AppLanguage.values)
                  PopupMenuItem(
                    value: l,
                    child: Row(
                      children: [
                        if (l == lang)
                          const Icon(Icons.check, size: 18, color: Colors.green)
                        else
                          const SizedBox(width: 18),
                        const SizedBox(width: 8),
                        Text(l.label),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
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
          SuccessState() => _QuizBody(
            quiz: quiz,
            onSubmit: () => _submit(quiz),
            onOpenPalette: () => _openQuestionPalette(quiz),
          ),
        },
      ),
    );
  }
}

class _QuizBody extends StatelessWidget {
  const _QuizBody({
    required this.quiz,
    required this.onSubmit,
    required this.onOpenPalette,
  });

  final QuizProvider quiz;
  final VoidCallback onSubmit;
  final VoidCallback onOpenPalette;

  @override
  Widget build(BuildContext context) {
    final lang = context.select<SettingsProvider, AppLanguage>(
      (s) => s.language,
    );
    final q = quiz.currentQuestion!;
    final total = quiz.questions.length;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (quiz.currentIndex + 1) / total,
              minHeight: 7,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Câu ${quiz.currentIndex + 1}/$total  •  ${q.category}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onOpenPalette,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Đã chọn ${quiz.answeredCount}/$total',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Text(
                    q.content.resolve(lang),
                    key: const Key('question_text'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < q.options.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  Builder(
                    builder: (_) {
                      final selected = quiz.selectedIndexForCurrent == i;
                      return Card(
                        color: selected
                            ? colorScheme.primaryContainer
                            : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: selected
                                ? colorScheme.primary
                                : colorScheme.outlineVariant.withValues(
                                    alpha: 0.6,
                                  ),
                            width: selected ? 1.8 : 1,
                          ),
                        ),
                        child: ListTile(
                          key: Key('option_$i'),
                          leading: CircleAvatar(
                            backgroundColor: selected
                                ? colorScheme.primary
                                : colorScheme.surfaceContainerHighest,
                            foregroundColor: selected
                                ? colorScheme.onPrimary
                                : colorScheme.onSurfaceVariant,
                            child: Text(
                              String.fromCharCode(65 + i),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          title: Text(
                            q.options[i].resolve(lang),
                            style: TextStyle(
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          trailing: selected
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: colorScheme.primary,
                                )
                              : null,
                          onTap: () => quiz.selectAnswer(i),
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SafeArea(
            top: false,
            child: Row(
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
          ),
        ],
      ),
    );
  }
}

class _QuestionPaletteSheet extends StatelessWidget {
  const _QuestionPaletteSheet({
    required this.quiz,
    required this.onSubmit,
  });

  final QuizProvider quiz;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final total = quiz.questions.length;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Bảng điều hướng câu hỏi',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  'Đã làm: ${quiz.answeredCount}/$total',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.42,
              ),
              child: GridView.builder(
                shrinkWrap: true,
                itemCount: total,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.25,
                ),
                itemBuilder: (ctx, i) {
                  final isCurrent = i == quiz.currentIndex;
                  final answered = quiz.isQuestionAnswered(i);
                  final pick = quiz.answerFor(i);
                  final pickLetter = pick != null
                      ? String.fromCharCode(65 + pick)
                      : '';

                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      quiz.jumpToQuestion(i);
                      Navigator.of(ctx).pop();
                    },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: answered
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerHighest.withValues(
                                alpha: 0.5,
                              ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCurrent
                              ? colorScheme.primary
                              : (answered
                                    ? colorScheme.primary.withValues(alpha: 0.4)
                                    : Colors.transparent),
                          width: isCurrent ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        answered ? '${i + 1} ($pickLetter)' : '${i + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: answered
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onSubmit,
              icon: const Icon(Icons.assignment_turned_in_rounded),
              label: const Text('Nộp bài ngay'),
            ),
          ],
        ),
      ),
    );
  }
}
