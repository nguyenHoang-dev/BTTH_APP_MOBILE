import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/state/view_state.dart';
import '../models/ai_explanation.dart';
import '../models/quiz_result.dart';
import '../providers/ai_provider.dart';
import '../providers/settings_provider.dart';
import 'widgets/state_views.dart';

/// Dialog hiển thị lời giải thích của AI cho 1 câu sai.
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

  @override
  void dispose() {
    _ai.reset(); // Huỷ nhận kết quả của request còn đang chạy.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AIProvider>().state;
    final settings = context.read<SettingsProvider>();

    return AlertDialog(
      title: const Row(
        children: [Icon(Icons.auto_awesome), SizedBox(width: 8), Text('AI giải thích')],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 360,
        child: switch (state) {
          IdleState() || LoadingState() => const LoadingView(message: 'AI đang phân tích...'),
          ErrorState(:final message) => ErrorView(
              message: message,
              onRetry: () => _explain(force: true),
              extraAction: settings.demoMode
                  ? null
                  : TextButton(
                      onPressed: () {
                        settings.setDemoMode(true);
                        _explain(force: true);
                      },
                      child: const Text('Chuyển sang Chế độ Demo'),
                    ),
            ),
          EmptyState(:final message) => EmptyView(message: message),
          SuccessState(:final data) => _ExplanationContent(data: data),
        },
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
      ],
    );
  }
}

class _ExplanationContent extends StatelessWidget {
  const _ExplanationContent({required this.data});
  final AIExplanation data;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.isDemo)
            const Chip(avatar: Icon(Icons.science, size: 18), label: Text('Dữ liệu Demo')),
          if (data.notice != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(data.notice!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          _section(context, '❌ Vì sao sai', data.whyWrong),
          _section(context, '✅ Đáp án đúng', data.correctExplanation),
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

