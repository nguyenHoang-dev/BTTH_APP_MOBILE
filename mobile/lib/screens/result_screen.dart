import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/localized_text.dart';
import '../models/quiz_result.dart';
import '../providers/settings_provider.dart';
import 'ai_explanation_dialog.dart';
import 'widgets/state_views.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.result});

  final QuizResult result;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _showAllAnswers = false;

  static Color _scoreColor(double score10) {
    if (score10 >= 8.0) return const Color(0xFF16A34A);
    if (score10 >= 5.0) return const Color(0xFF4F46E5);
    return const Color(0xFFDC2626);
  }

  static String _rankLabel(double score10) {
    if (score10 >= 8.0) return 'Xuất sắc 🌟';
    if (score10 >= 5.0) return 'Đạt yêu cầu 👍';
    return 'Cần ôn tập thêm 💪';
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final lang = context.select<SettingsProvider, AppLanguage>((s) => s.language);
    final theme = Theme.of(context);
    final scoreColor = _scoreColor(result.score10);
    final displayedAnswers = _showAllAnswers && result.answers.isNotEmpty
        ? result.answers
        : result.wrongAnswers;

    return Scaffold(
      appBar: AppBar(title: const Text('Kết quả')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: scoreColor.withValues(alpha: 0.28),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: scoreColor.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _rankLabel(result.score10),
                    style: TextStyle(
                      color: scoreColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${result.score10}',
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: scoreColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${result.correctCount}/${result.totalQuestions} câu đúng '
                  '(${(result.accuracy * 100).toStringAsFixed(0)}%)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Thời gian: ${result.duration.inMinutes} phút ${result.duration.inSeconds % 60} giây',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (result.answers.isNotEmpty && result.wrongAnswers.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment<bool>(
                        value: false,
                        icon: const Icon(Icons.error_outline_rounded, size: 16),
                        label: Text('Câu sai (${result.wrongAnswers.length})'),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        icon: const Icon(Icons.list_alt_rounded, size: 16),
                        label: Text('Tất cả (${result.answers.length})'),
                      ),
                    ],
                    selected: {_showAllAnswers},
                    onSelectionChanged: (s) {
                      setState(() => _showAllAnswers = s.first);
                    },
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: displayedAnswers.isEmpty
                ? const EmptyView(message: 'Xuất sắc! Bạn không sai câu nào 🎉')
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: displayedAnswers.length,
                    itemBuilder: (_, i) {
                      final w = displayedAnswers[i];
                      final q = w.question;
                      final isCorrect = w.isCorrect;
                      final chosen = w.selectedIndex >= 0
                          ? q.options[w.selectedIndex].resolve(lang)
                          : '(Không trả lời)';
                      final explanation = q.explanation?.resolve(lang);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      q.category,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: theme
                                            .colorScheme
                                            .onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '#${q.id}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                q.content.resolve(lang),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isCorrect
                                    ? '✓ Bạn chọn: $chosen'
                                    : '✗ Bạn chọn: $chosen',
                                style: TextStyle(
                                  color: isCorrect
                                      ? Colors.green.shade700
                                      : theme.colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '✓ Đáp án: ${q.correctOption.resolve(lang)}',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (explanation != null &&
                                  explanation.trim().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '💡 $explanation',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.tonalIcon(
                                  icon: const Icon(Icons.auto_awesome, size: 17),
                                  label: Text(
                                    isCorrect
                                        ? 'Hỏi AI phân tích thêm'
                                        : 'Hỏi AI tại sao sai',
                                  ),
                                  onPressed: () =>
                                      AIExplanationDialog.show(context, w),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Về trang chủ'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
