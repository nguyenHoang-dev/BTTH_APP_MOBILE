import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/state/view_state.dart';
import '../models/ai_explanation.dart';
import '../models/localized_text.dart';
import '../models/quiz_result.dart';
import '../providers/ai_provider.dart';
import '../providers/settings_provider.dart';
import 'widgets/state_views.dart';

/// Dialog hiển thị lời giải thích của AI cho 1 câu hỏi (cả khi chọn đúng hoặc chọn sai).
class AIExplanationDialog extends StatefulWidget {
  const AIExplanationDialog({super.key, required this.answer});

  final UserAnswer answer;

  static Future<void> show(BuildContext context, UserAnswer answer) {
    return showDialog<void>(
      context: context,
      builder: (_) => AIExplanationDialog(answer: answer),
    );
  }

  @override
  State<AIExplanationDialog> createState() => _AIExplanationDialogState();
}

class _AIExplanationDialogState extends State<AIExplanationDialog> {
  late final AIProvider _ai;

  @override
  void initState() {
    super.initState();
    _ai = context.read<AIProvider>();
    // Gọi AI sau frame đầu – tuyệt đối không gọi mạng trong build().
    WidgetsBinding.instance.addPostFrameCallback((_) => _explain());
  }

  void _explain({bool force = false}) {
    final lang = context.read<SettingsProvider>().language;
    _ai.explainAnswer(widget.answer, lang, forceRefresh: force);
  }

  Future<void> _copyExplanation(AIExplanation data) async {
    final lang = context.read<SettingsProvider>().language;
    final q = widget.answer.question;
    final isCorrect = widget.answer.isCorrect;
    final hasSelection =
        widget.answer.selectedIndex >= 0 &&
        widget.answer.selectedIndex < q.options.length;
    final selectedText = hasSelection
        ? q.options[widget.answer.selectedIndex].resolve(lang)
        : (lang == AppLanguage.en ? '(No answer)' : '(Chưa chọn)');
    final correctText = q.correctOption.resolve(lang);

    final buffer = StringBuffer()
      ..writeln('Câu hỏi: ${q.content.resolve(lang)}')
      ..writeln(
        'Đã chọn: $selectedText ${isCorrect ? "(Chính xác)" : "(Chưa đúng)"}',
      )
      ..writeln('Đáp án đúng: $correctText')
      ..writeln();

    if (isCorrect) {
      if (data.whyWrong.trim().isNotEmpty) {
        buffer.writeln('🎯 Phân tích lựa chọn: ${data.whyWrong}');
      }
      buffer.writeln('✅ Giải thích chi tiết: ${data.correctExplanation}');
    } else {
      buffer
        ..writeln('❌ Vì sao sai: ${data.whyWrong}')
        ..writeln('✅ Đáp án đúng: ${data.correctExplanation}');
    }

    if (data.example.trim().isNotEmpty) {
      buffer.writeln('📝 Ví dụ: ${data.example}');
    }
    if (data.tip.trim().isNotEmpty) {
      buffer.writeln('💡 Mẹo nhớ: ${data.tip}');
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép lời giải thích vào bộ nhớ tạm.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _ai.reset(); // Huỷ nhận kết quả của request còn đang chạy.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AIProvider>().state;
    final settings = context.watch<SettingsProvider>();

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.auto_awesome),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'AI giải thích',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: (MediaQuery.sizeOf(context).height * 0.55).clamp(240.0, 440.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _QuestionSummaryHeader(
              answer: widget.answer,
              language: settings.language,
            ),
            const Divider(height: 16),
            Expanded(
              child: switch (state) {
                IdleState() || LoadingState() => const LoadingView(
                  message: 'AI đang phân tích...',
                ),
                ErrorState(:final message) => ErrorView(
                  message: message,
                  onRetry: () => _explain(force: true),
                  extraAction: settings.demoMode
                      ? null
                      : TextButton.icon(
                          key: const Key('switch_demo_mode_button'),
                          onPressed: () {
                            settings.setDemoMode(true);
                            _explain(force: true);
                          },
                          icon: const Icon(Icons.science_outlined),
                          label: const Text('Chuyển sang Chế độ Demo'),
                        ),
                ),
                EmptyState(:final message) => EmptyView(message: message),
                SuccessState(:final data) => _ExplanationContent(
                  data: data,
                  isUserCorrect: widget.answer.isCorrect,
                  isDemoModeSetting: settings.demoMode,
                  onSwitchToDemoMode: () {
                    settings.setDemoMode(true);
                  },
                ),
              },
            ),
          ],
        ),
      ),
      actions: [
        if (state case SuccessState(:final data))
          TextButton.icon(
            key: const Key('copy_explanation_button'),
            onPressed: () => _copyExplanation(data),
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Sao chép lời giải thích'),
          ),
        TextButton(
          key: const Key('close_ai_dialog_button'),
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}

/// Phần đầu Dialog: hiển thị rõ câu hỏi, đáp án người dùng đã chọn và đáp án đúng.
class _QuestionSummaryHeader extends StatelessWidget {
  const _QuestionSummaryHeader({required this.answer, required this.language});

  final UserAnswer answer;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final q = answer.question;
    final isCorrect = answer.isCorrect;
    final hasSelection =
        answer.selectedIndex >= 0 && answer.selectedIndex < q.options.length;
    final selectedText = hasSelection
        ? q.options[answer.selectedIndex].resolve(language)
        : (language == AppLanguage.en ? '(No answer)' : '(Chưa trả lời)');
    final correctText = q.correctOption.resolve(language);
    final colorScheme = Theme.of(context).colorScheme;
    final selectedColor = isCorrect ? Colors.green.shade700 : colorScheme.error;

    return Container(
      key: const Key('ai_dialog_question_header'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            q.content.resolve(language),
            key: const Key('ai_dialog_question_text'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel_outlined,
                size: 16,
                color: selectedColor,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  isCorrect
                      ? 'Bạn chọn: $selectedText (Chính xác)'
                      : 'Bạn chọn: $selectedText',
                  key: const Key('ai_dialog_selected_answer'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: selectedColor,
                    fontWeight: isCorrect ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 16,
                color: Colors.green,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Đáp án đúng: $correctText',
                  key: const Key('ai_dialog_correct_answer'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
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

class _ExplanationContent extends StatelessWidget {
  const _ExplanationContent({
    required this.data,
    required this.isUserCorrect,
    required this.isDemoModeSetting,
    required this.onSwitchToDemoMode,
  });

  final AIExplanation data;
  final bool isUserCorrect;
  final bool isDemoModeSetting;
  final VoidCallback onSwitchToDemoMode;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.isDemo)
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Chip(
                  avatar: Icon(Icons.science, size: 18),
                  label: Text('Dữ liệu Demo'),
                ),
                if (data.notice != null && !isDemoModeSetting)
                  TextButton.icon(
                    key: const Key('quick_enable_demo_button'),
                    onPressed: onSwitchToDemoMode,
                    icon: const Icon(Icons.toggle_on_outlined, size: 18),
                    label: const Text('Bật luôn Chế độ Demo'),
                  ),
              ],
            ),
          if (data.notice != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                data.notice!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          _section(
            context,
            isUserCorrect ? '🎯 Phân tích lựa chọn' : '❌ Vì sao sai',
            data.whyWrong,
          ),
          _section(
            context,
            isUserCorrect ? '✅ Giải thích chi tiết' : '✅ Đáp án đúng',
            data.correctExplanation,
          ),
          _section(context, '📝 Ví dụ', data.example),
          _section(context, '💡 Mẹo nhớ', data.tip),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, String body) {
    if (body.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(body),
        ],
      ),
    );
  }
}
