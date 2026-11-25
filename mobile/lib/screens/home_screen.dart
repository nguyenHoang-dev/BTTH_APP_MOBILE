import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config/app_config.dart';
import '../core/state/view_state.dart';
import '../models/localized_text.dart';
import '../models/quiz_result.dart';
import '../providers/history_provider.dart';
import '../providers/settings_provider.dart';
import 'practice_screen.dart';
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
    });
  }

  Future<void> _openQuiz({bool onlyWrong = false}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => QuizScreen(onlyWrong: onlyWrong)),
    );
    if (mounted) context.read<HistoryProvider>().load(); // Làm mới thống kê.
  }

  Future<void> _openPractice() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PracticeScreen()),
    );
    if (mounted) context.read<HistoryProvider>().load();
  }

  /// Hỏi xác nhận bằng AlertDialog rồi mới xóa (an toàn dữ liệu).
  Future<void> _confirmClearHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa lịch sử?'),
        content: const Text(
          'Toàn bộ lịch sử điểm, danh sách câu sai và thống kê theo khối '
          'sẽ bị xóa vĩnh viễn. Không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const Key('confirm_clear_history'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final error = await context.read<HistoryProvider>().clearHistory();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Đã xóa lịch sử làm bài.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final history = context.watch<HistoryProvider>();
    final canClear = !history.isClearing &&
        (history.totalAttempts > 0 || history.categoryStats.isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ôn tập song ngữ'),
        actions: [
          IconButton(
            key: const Key('clear_history_button'),
            tooltip: 'Xóa lịch sử',
            icon: const Icon(Icons.delete_outline),
            onPressed: canClear ? _confirmClearHistory : null,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsCard(settings: settings),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('home_practice_button'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.tertiary,
              foregroundColor: Theme.of(context).colorScheme.onTertiary,
            ),
            onPressed: _openPractice,
            icon: const Icon(Icons.school_outlined),
            label: const Text('Luyện tập theo chủ đề (Xem đáp án tức thì)'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => _openQuiz(),
            icon: const Icon(Icons.play_arrow),
            label: Text('Thi thử ngẫu nhiên (${AppConfig.questionsPerQuiz} câu)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _openQuiz(onlyWrong: true),
            icon: const Icon(Icons.replay),
            label: Text('Ôn lại các câu đã làm sai (${history.wrongCount})'),
          ),
          const SizedBox(height: 24),
          if (history.categoryStats.isNotEmpty) ...[
            Text('Tỷ lệ đúng theo khối kiến thức',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _CategoryStatsCard(stats: history.categoryStats),
            const SizedBox(height: 24),
          ],
          Text('Thống kê', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const SizedBox(height: 320, child: _HistorySection()),
        ],
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

/// Mỗi khối kiến thức 1 dòng: tên khối, đúng/tổng (%), thanh tiến độ.
class _CategoryStatsCard extends StatelessWidget {
  const _CategoryStatsCard({required this.stats});
  final List<CategoryStat> stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            for (final s in stats)
              Padding(
                key: Key('category_stat_${s.category}'),
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(s.category)),
                        Text('${s.correct}/${s.total} '
                            '(${(s.accuracy * 100).toStringAsFixed(0)}%)'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: s.accuracy,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
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

