import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config/app_config.dart';
import '../core/state/view_state.dart';
import '../models/exam_subject.dart';
import '../models/localized_text.dart';
import '../models/quiz_result.dart';
import '../providers/history_provider.dart';
import '../providers/quiz_provider.dart';
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
      isScrollControlled: true,
      builder: (_) => const _SubjectPickerSheet(),
    );
    if (subject == null || !mounted) return;
    await _openQuiz(subject: subject);
  }

  Future<void> _openPractice({String? initialCategory}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PracticeScreen(initialCategory: initialCategory),
      ),
    );
    if (mounted) context.read<HistoryProvider>().load();
  }

  /// Hỏi xác nhận bằng AlertDialog rồi mới xóa (an toàn dữ liệu).
  Future<void> _confirmClearHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(ctx).colorScheme.error,
          size: 36,
        ),
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.translate_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Ôn tập song ngữ',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: settings.demoMode
                  ? Colors.amber.shade100
                  : Colors.green.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  settings.demoMode ? Icons.science_rounded : Icons.bolt_rounded,
                  size: 14,
                  color: settings.demoMode
                      ? Colors.amber.shade900
                      : Colors.green.shade800,
                ),
                const SizedBox(width: 4),
                Text(
                  settings.demoMode ? 'Demo AI' : 'Gemini AI',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: settings.demoMode
                        ? Colors.amber.shade900
                        : Colors.green.shade800,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('clear_history_button'),
            tooltip: 'Xóa lịch sử',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: canClear ? _confirmClearHistory : null,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          _HeroBanner(settings: settings, history: history),
          const SizedBox(height: 12),
          _SettingsCard(settings: settings),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('home_practice_button'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: () => _openPractice(),
            icon: const Icon(Icons.school_outlined),
            label: const Text('Luyện tập theo chủ đề (Xem đáp án tức thì)'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('mock_exam_button'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: _openMockExamPicker,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Thi thử'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('random_quiz_button'),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: () => _openQuiz(),
            icon: const Icon(Icons.shuffle_rounded),
            label: Text('Thi thử ngẫu nhiên (${AppConfig.questionsPerQuiz} câu)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              backgroundColor: history.wrongCount > 0
                  ? const Color(0xFFFFF7ED)
                  : Colors.white,
              foregroundColor: history.wrongCount > 0
                  ? const Color(0xFFC2410C)
                  : null,
              side: history.wrongCount > 0
                  ? const BorderSide(color: Color(0xFFFB923C), width: 1.2)
                  : null,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: () => _openQuiz(onlyWrong: true),
            icon: const Icon(Icons.replay_rounded),
            label: Text('Ôn lại các câu đã làm sai (${history.wrongCount})'),
          ),
          const SizedBox(height: 14),
          _QuickCategoryStrip(onSelectCategory: (cat) => _openPractice(initialCategory: cat)),
          const SizedBox(height: 20),
          if (history.categoryStats.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.pie_chart_outline_rounded,
              title: 'Tỷ lệ đúng theo khối kiến thức',
              subtitle: 'Theo dõi tiến độ nắm vững từng mảng chuyên đề',
            ),
            const SizedBox(height: 10),
            _CategoryStatsCard(stats: history.categoryStats),
            const SizedBox(height: 22),
          ],
          _SectionHeader(
            icon: Icons.insights_rounded,
            title: 'Thống kê',
            subtitle: 'Lịch sử các lượt thi và điểm số chi tiết',
          ),
          const SizedBox(height: 10),
          const SizedBox(height: 360, child: _HistorySection()),
        ],
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.settings, required this.history});

  final SettingsProvider settings;
  final HistoryProvider history;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF4338CA), Color(0xFF6366F1), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 15, color: Colors.amberAccent),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Hệ thống Ôn tập Trắc nghiệm Song ngữ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                settings.language.label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              const _HeroBadge(
                icon: Icons.library_books_rounded,
                label: '300 câu hỏi',
              ),
              const _HeroBadge(
                icon: Icons.category_rounded,
                label: '20 khối kiến thức',
              ),
              _HeroBadge(
                icon: Icons.history_edu_rounded,
                label: '${history.totalAttempts} lượt đã thi',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickCategoryStrip extends StatelessWidget {
  const _QuickCategoryStrip({required this.onSelectCategory});

  final ValueChanged<String?> onSelectCategory;

  static const List<({String id, String label, IconData icon, Color color})> _items = [
    (id: 'Khối 1. Ngôn ngữ Dart', label: 'Khối 1. Dart', icon: Icons.code_rounded, color: Color(0xFFD97706)),
    (id: 'Khối 3. Cách Flutter hoạt động', label: 'Khối 3. Flutter Core', icon: Icons.widgets_rounded, color: Color(0xFF0284C7)),
    (id: 'Khối 4. Bố cục và cuộn', label: 'Khối 4. Bố cục', icon: Icons.dashboard_customize_rounded, color: Color(0xFF4F46E5)),
    (id: 'Khối 9. Điều hướng', label: 'Khối 9. Điều hướng', icon: Icons.alt_route_rounded, color: Color(0xFF0D9488)),
    (id: 'Khối 12. Quản lý trạng thái', label: 'Khối 12. State', icon: Icons.sync_alt_rounded, color: Color(0xFF7C3AED)),
    (id: 'Khối 13. Dữ liệu và backend', label: 'Khối 13. Backend', icon: Icons.cloud_sync_rounded, color: Color(0xFF2563EB)),
    (id: 'Khối 16. Kiểm thử và gỡ lỗi', label: 'Khối 16. Kiểm thử', icon: Icons.fact_check_rounded, color: Color(0xFF16A34A)),
    (id: 'Khối 20. AI trong Flutter', label: 'Khối 20. AI Flutter', icon: Icons.auto_awesome_rounded, color: Color(0xFFDB2777)),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.flash_on_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Luyện nhanh theo chuyên đề',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in _items)
                  ActionChip(
                    avatar: Icon(item.icon, size: 16, color: item.color),
                    label: Text(
                      item.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: item.color,
                        fontSize: 12.5,
                      ),
                    ),
                    backgroundColor: item.color.withValues(alpha: 0.08),
                    side: BorderSide(color: item.color.withValues(alpha: 0.25)),
                    onPressed: () => onSelectCategory(item.id),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectPickerSheet extends StatelessWidget {
  const _SubjectPickerSheet();

  static IconData _iconFor(String subjectId) => switch (subjectId) {
        'grammar' => Icons.spellcheck_rounded,
        'vocabulary' => Icons.menu_book_rounded,
        'flutter_network' => Icons.developer_mode_rounded,
        _ => Icons.quiz_outlined,
      };

  static Color _colorFor(String subjectId) => switch (subjectId) {
        'grammar' => const Color(0xFF4F46E5),
        'vocabulary' => const Color(0xFF0D9488),
        'flutter_network' => const Color(0xFF0284C7),
        _ => const Color(0xFF6366F1),
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
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.assignment_turned_in_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chọn môn thi thử',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Chọn 1 trong 3 môn. Đề chỉ gồm câu hỏi của môn đó và đảo thứ tự mỗi lần thi.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (final subject in quiz.subjects)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: _colorFor(subject.id).withValues(alpha: 0.28),
                    ),
                  ),
                  child: ListTile(
                    key: Key('subject_${subject.id}'),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: _colorFor(subject.id).withValues(alpha: 0.12),
                      foregroundColor: _colorFor(subject.id),
                      child: Icon(_iconFor(subject.id)),
                    ),
                    title: Text(
                      subject.name.resolve(lang),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_subtitleFor(subject, counts[subject.id])),
                        if (subject.blockSummary.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subject.blockSummary,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: _colorFor(subject.id),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _colorFor(subject.id).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: _colorFor(subject.id),
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(subject),
                  ),
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
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              secondary: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: settings.demoMode
                      ? Colors.amber.shade50
                      : theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  settings.demoMode
                      ? Icons.science_outlined
                      : Icons.auto_awesome_rounded,
                  size: 20,
                  color: settings.demoMode
                      ? Colors.amber.shade800
                      : theme.colorScheme.primary,
                ),
              ),
              title: const Text(
                'Chế độ Demo AI',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Dùng dữ liệu giả lập, không cần mạng/API key',
                style: TextStyle(fontSize: 12),
              ),
              value: settings.demoMode,
              onChanged: settings.setDemoMode,
            ),
            const SizedBox(height: 6),
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

  static Color _barColor(double accuracy) {
    if (accuracy >= 0.8) return const Color(0xFF16A34A);
    if (accuracy >= 0.5) return const Color(0xFF4F46E5);
    return const Color(0xFFEA580C);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            for (final s in stats)
              Padding(
                key: Key('category_stat_${s.category}'),
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _barColor(s.accuracy),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.category,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '${s.correct}/${s.total} '
                          '(${(s.accuracy * 100).toStringAsFixed(0)}%)',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _barColor(s.accuracy),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: s.accuracy,
                      minHeight: 8,
                      color: _barColor(s.accuracy),
                      backgroundColor: _barColor(s.accuracy).withValues(alpha: 0.14),
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: switch (history.state) {
          IdleState() || LoadingState() =>
            const LoadingView(message: 'Đang tải lịch sử...'),
          ErrorState(:final message) =>
            ErrorView(message: message, onRetry: history.load),
          EmptyState(:final message) => EmptyView(message: message),
          SuccessState(:final data) =>
            _HistoryList(history: history, results: data),
        },
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.history, required this.results});
  final HistoryProvider history;
  final List<QuizResult> results;

  static Color _scoreColor(double score10) {
    if (score10 >= 8.0) return const Color(0xFF16A34A);
    if (score10 >= 5.0) return const Color(0xFF4F46E5);
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Stat(
              label: 'Số lượt',
              value: '${history.totalAttempts}',
              icon: Icons.fact_check_outlined,
              color: const Color(0xFF4F46E5),
            ),
            _Stat(
              label: 'Điểm TB',
              value: history.averageScore.toStringAsFixed(1),
              icon: Icons.trending_up_rounded,
              color: const Color(0xFF0D9488),
            ),
            _Stat(
              label: 'Cao nhất',
              value: history.bestScore.toStringAsFixed(1),
              icon: Icons.emoji_events_outlined,
              color: const Color(0xFFD97706),
            ),
          ],
        ),
        const Divider(height: 20),
        Expanded(
          child: ListView.separated(
            itemCount: results.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (_, i) {
              final r = results[i];
              final color = _scoreColor(r.score10);
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.14),
                    foregroundColor: color,
                    child: Text(
                      r.score10.toStringAsFixed(0),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  title: Text(
                    '${r.correctCount}/${r.totalQuestions} câu đúng',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(_formatDate(r.takenAt)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${r.duration.inMinutes}p${r.duration.inSeconds % 60}s',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
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
  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
