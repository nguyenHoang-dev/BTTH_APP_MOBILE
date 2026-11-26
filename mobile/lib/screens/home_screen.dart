import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/state/view_state.dart';
import '../models/exam_subject.dart';
import '../models/localized_text.dart';
import '../models/quiz_result.dart';
import '../providers/history_provider.dart';
import '../providers/quiz_provider.dart';
import '../providers/settings_provider.dart';
import 'quiz_screen.dart';
import 'widgets/state_views.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // KHÔNG gọi dữ liệu trong build(): kích hoạt 1 lần sau frame đầu tiên.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryProvider>().load();
      context.read<QuizProvider>().loadSubjectCounts();
    });
  }

  Future<void> _openQuiz({bool onlyWrong = false, ExamSubject? subject}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuizScreen(onlyWrong: onlyWrong, subject: subject),
      ),
    );
    if (mounted) context.read<HistoryProvider>().load(); // Làm mới thống kê.
  }

  Future<void> _openMockExamPicker() async {
    final subject = await showModalBottomSheet<ExamSubject>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _SubjectPickerSheet(),
    );
    if (subject == null || !mounted) return;
    await _openQuiz(subject: subject);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Ôn tập song ngữ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsCard(settings: settings),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('mock_exam_button'),
            onPressed: _openMockExamPicker,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Thi thử'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _openQuiz(onlyWrong: true),
            icon: const Icon(Icons.replay),
            label: const Text('Ôn lại các câu đã làm sai'),
          ),
          const SizedBox(height: 24),
          Text('Thống kê', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const SizedBox(height: 320, child: _HistorySection()),
        ],
      ),
    );
  }
}

class _SubjectPickerSheet extends StatelessWidget {
  const _SubjectPickerSheet();

  static IconData _iconFor(String subjectId) => switch (subjectId) {
        'grammar' => Icons.spellcheck,
        'vocabulary' => Icons.menu_book,
        'flutter_network' => Icons.developer_mode,
        _ => Icons.quiz_outlined,
      };

  static String _subtitleFor(ExamSubject subject, int? count) {
    final categories = subject.categories.join(', ');
    if (count == null) return 'Phạm vi: $categories';
    return '$count câu  •  $categories';
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<SettingsProvider>().language;
    final quiz = context.watch<QuizProvider>();
    final counts = quiz.subjectCounts;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Chọn môn thi thử',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Chọn 1 trong 3 môn. Đề chỉ gồm câu hỏi của môn đó và đảo thứ tự mỗi lần thi.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            for (final subject in quiz.subjects)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  key: Key('subject_${subject.id}'),
                  leading: CircleAvatar(child: Icon(_iconFor(subject.id))),
                  title: Text(subject.name.resolve(lang)),
                  subtitle: Text(_subtitleFor(subject, counts[subject.id])),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pop(subject),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.settings});
  final SettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Chế độ Demo AI'),
              subtitle: const Text('Dùng dữ liệu giả lập, không cần mạng/API key'),
              value: settings.demoMode,
              onChanged: settings.setDemoMode,
            ),
            const SizedBox(height: 8),
            SegmentedButton<AppLanguage>(
              segments: [
                for (final l in AppLanguage.values)
                  ButtonSegment(value: l, label: Text(l.label)),
              ],
              selected: {settings.language},
              onSelectionChanged: (s) => settings.setLanguage(s.first),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection();

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryProvider>();

    return switch (history.state) {
      IdleState() || LoadingState() => const LoadingView(message: 'Đang tải lịch sử...'),
      ErrorState(:final message) => ErrorView(message: message, onRetry: history.load),
      EmptyState(:final message) => EmptyView(message: message),
      SuccessState(:final data) => _HistoryList(history: history, results: data),
    };
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.history, required this.results});
  final HistoryProvider history;
  final List<QuizResult> results;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Stat(label: 'Số lượt', value: '${history.totalAttempts}'),
            _Stat(label: 'Điểm TB', value: history.averageScore.toStringAsFixed(1)),
            _Stat(label: 'Cao nhất', value: history.bestScore.toStringAsFixed(1)),
          ],
        ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            itemCount: results.length,
            itemBuilder: (_, i) {
              final r = results[i];
              return ListTile(
                dense: true,
                leading: CircleAvatar(child: Text(r.score10.toStringAsFixed(0))),
                title: Text('${r.correctCount}/${r.totalQuestions} câu đúng'),
                subtitle: Text(_formatDate(r.takenAt)),
                trailing: Text('${r.duration.inMinutes}p${r.duration.inSeconds % 60}s'),
              );
            },
          ),
        ),
      ],
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        Text(label),
      ],
    );
  }
}

