import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/state/view_state.dart';
import '../models/localized_text.dart';
import '../models/question.dart';
import '../models/quiz_result.dart';
import '../providers/practice_provider.dart';
import '../providers/settings_provider.dart';
import 'ai_explanation_dialog.dart';
import 'widgets/state_views.dart';

/// Màn hình Chế độ Luyện tập (Practice Mode).
///
/// Tính năng chính:
/// - Lọc theo khối kiến thức (category filter).
/// - Phản hồi màu Xanh (Đúng) / Đỏ (Sai) ngay khi chọn đáp án.
/// - Hiển thị giải thích tĩnh có sẵn (offline).
/// - Nút "Hỏi AI giải thích sâu hơn" gọi server Node.js.
/// - Chuyển đổi ngôn ngữ hiển thị (VI / EN / Song ngữ).
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key, this.initialCategory});

  final String? initialCategory;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PracticeProvider>().loadQuestions(category: widget.initialCategory);
    });
  }

  void _reload() {
    final provider = context.read<PracticeProvider>();
    provider.loadQuestions(category: provider.selectedCategory);
  }

  void _showSummary(BuildContext context, PracticeProvider practice, AppLanguage lang) {
    _PracticeBody.showSummaryDialog(context, practice: practice, lang: lang);
  }

  @override
  Widget build(BuildContext context) {
    final practice = context.watch<PracticeProvider>();
    final settings = context.watch<SettingsProvider>();
    final lang = settings.language;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          switch (lang) {
            AppLanguage.vi => 'Chế độ Luyện tập',
            AppLanguage.en => 'Practice Mode',
            AppLanguage.both => 'Luyện tập • Practice',
          },
        ),
        actions: [
          IconButton(
            key: const Key('practice_finish_appbar_button'),
            tooltip: switch (lang) {
              AppLanguage.vi => 'Tổng kết phiên',
              AppLanguage.en => 'Finish session',
              AppLanguage.both => 'Tổng kết • Finish',
            },
            icon: const Icon(Icons.flag_outlined),
            onPressed: () => _showSummary(context, practice, lang),
          ),
          PopupMenuButton<AppLanguage>(
            tooltip: 'Đổi ngôn ngữ',
            icon: const Icon(Icons.language),
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
      body: switch (practice.state) {
        IdleState() || LoadingState() => const LoadingView(message: 'Đang tải câu hỏi luyện tập...'),
        ErrorState(:final message) => ErrorView(message: message, onRetry: _reload),
        EmptyState(:final message) => EmptyView(
            message: message,
            action: OutlinedButton(
              onPressed: () => practice.selectCategory(null),
              child: const Text('Xem tất cả câu hỏi'),
            ),
          ),
        SuccessState() => _PracticeBody(practice: practice, lang: lang),
      },
    );
  }
}

class _PracticeBody extends StatelessWidget {
  const _PracticeBody({required this.practice, required this.lang});

  final PracticeProvider practice;
  final AppLanguage lang;

  static const Map<String, String> _categoryLabelsVi = {
    'all': 'Tất cả',
    'grammar': 'Ngữ pháp',
    'vocabulary': 'Từ vựng',
    'flutter': 'Flutter',
    'network': 'Mạng & API',
    'dart': 'Dart',
  };

  static const Map<String, String> _categoryLabelsEn = {
    'all': 'All',
    'grammar': 'Grammar',
    'vocabulary': 'Vocabulary',
    'flutter': 'Flutter',
    'network': 'Network & API',
    'dart': 'Dart',
  };

  String _getCategoryLabel(String catKey) {
    final key = catKey.toLowerCase();
    final vi = _categoryLabelsVi[key] ?? catKey;
    final en = _categoryLabelsEn[key] ?? catKey;
    return switch (lang) {
      AppLanguage.vi => vi,
      AppLanguage.en => en,
      AppLanguage.both => vi == en ? vi : '$vi ($en)',
    };
  }

  @override
  Widget build(BuildContext context) {
    final q = practice.currentQuestion;
    if (q == null) return const SizedBox.shrink();

    final total = practice.totalQuestions;
    final currentIdx = practice.currentIndex;

    return Column(
      children: [
        // Thanh bộ lọc khối kiến thức
        _buildCategoryBar(context),

        // Thanh tiến độ & thống kê kết quả phiên
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              LinearProgressIndicator(
                value: total > 0 ? (currentIdx + 1) / total : 0,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Câu ${currentIdx + 1}/$total',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Đúng: ${practice.correctCount}/${practice.answeredCount}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: practice.answeredCount > 0
                          ? (practice.correctCount / practice.answeredCount >= 0.5
                              ? Colors.green.shade700
                              : Colors.orange.shade800)
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Thân câu hỏi và các lựa chọn
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              // Khối nội dung câu hỏi
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(128),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _getCategoryLabel(q.category),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '#${q.id}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        q.content.resolve(lang),
                        key: const Key('practice_question_text'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Danh sách 4 đáp án
              for (var i = 0; i < q.options.length; i++)
                _buildOptionTile(context, question: q, optionIndex: i),

              // Khối giải thích & gọi AI (chỉ hiện khi đã chọn đáp án)
              if (practice.isAnswered) ...[
                const SizedBox(height: 16),
                _buildExplanationSection(context, question: q),
              ],
            ],
          ),
        ),

        // Thanh điều hướng dưới cùng
        _buildBottomNav(context),
      ],
    );
  }

  Widget _buildCategoryBar(BuildContext context) {
    final categories = ['all', ...practice.categories];
    final selected = practice.selectedCategory ?? 'all';

    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (ctx, idx) {
          final cat = categories[idx];
          final isSelected = cat.toLowerCase() == selected.toLowerCase();

          return ChoiceChip(
            key: Key('category_chip_$cat'),
            label: Text(_getCategoryLabel(cat)),
            selected: isSelected,
            onSelected: (_) {
              practice.selectCategory(cat == 'all' ? null : cat);
            },
          );
        },
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required Question question,
    required int optionIndex,
  }) {
    final isAnswered = practice.isAnswered;
    final selectedIndex = practice.selectedAnswer;
    final isCorrectOption = question.isCorrect(optionIndex);
    final isUserPick = selectedIndex == optionIndex;

    Color? cardColor;
    Color? borderColor;
    Widget leadingWidget = CircleAvatar(
      radius: 14,
      backgroundColor: Colors.transparent,
      child: Text(
        String.fromCharCode(65 + optionIndex),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );

    if (isAnswered) {
      if (isCorrectOption) {
        // Đáp án đúng luôn có màu Xanh
        cardColor = Colors.green.shade50;
        borderColor = Colors.green.shade600;
        leadingWidget = const Icon(Icons.check_circle, color: Colors.green, size: 22);
      } else if (isUserPick) {
        // Người dùng chọn sai => màu Đỏ
        cardColor = Colors.red.shade50;
        borderColor = Colors.red.shade600;
        leadingWidget = const Icon(Icons.cancel, color: Colors.red, size: 22);
      } else {
        // Các đáp án khác mờ đi
        cardColor = Theme.of(context).cardColor.withAlpha(128);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: borderColor ?? Theme.of(context).dividerColor.withAlpha(50),
            width: borderColor != null ? 1.8 : 1,
          ),
        ),
        elevation: isUserPick ? 1 : 0,
        child: ListTile(
          key: Key('practice_option_$optionIndex'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: leadingWidget,
          title: Text(
            question.options[optionIndex].resolve(lang),
            style: TextStyle(
              fontSize: 15,
              fontWeight: isUserPick || (isAnswered && isCorrectOption)
                  ? FontWeight.w600
                  : FontWeight.normal,
              color: isAnswered && !isCorrectOption && !isUserPick ? Colors.grey.shade600 : null,
            ),
          ),
          onTap: isAnswered ? null : () => practice.selectOption(optionIndex),
        ),
      ),
    );
  }

  Widget _buildExplanationSection(BuildContext context, {required Question question}) {
    final isCorrect = practice.isCurrentCorrect;
    final explanation = question.explanation?.resolve(lang);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCorrect ? Colors.green.shade50.withAlpha(180) : Colors.amber.shade50.withAlpha(180),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect ? Colors.green.shade300 : Colors.amber.shade400,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle_outline : Icons.info_outline,
                color: isCorrect ? Colors.green.shade800 : Colors.amber.shade900,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect ? 'Chính xác! 🎉' : 'Chưa đúng!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isCorrect ? Colors.green.shade900 : Colors.amber.shade900,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: practice.retryCurrent,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Thử lại'),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
          if (explanation != null && explanation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Giải thích:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              explanation,
              key: const Key('practice_explanation_text'),
              style: const TextStyle(fontSize: 14, height: 1.3),
            ),
          ],
          const SizedBox(height: 12),
          // Nút gọi AI giải thích sâu hơn
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              key: const Key('ask_ai_button'),
              onPressed: () {
                final answer = UserAnswer(
                  question: question,
                  selectedIndex: practice.selectedAnswer ?? 0,
                );
                AIExplanationDialog.show(context, answer);
              },
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: Text(
                switch (lang) {
                  AppLanguage.vi => 'Hỏi AI giải thích sâu hơn',
                  AppLanguage.en => 'Ask AI for detailed explanation',
                  AppLanguage.both => 'Hỏi AI giải thích • Ask AI',
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final isLast = practice.isLast;
    final answered = practice.answeredCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            key: const Key('practice_prev_button'),
            onPressed: practice.isFirst ? null : practice.previousQuestion,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Câu trước'),
          ),
          const Spacer(),
          if (answered > 0 && !isLast)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                key: const Key('practice_summary_bottom_button'),
                onPressed: () => showSummaryDialog(context, practice: practice, lang: lang),
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: Text(
                  switch (lang) {
                    AppLanguage.vi => 'Tổng kết',
                    AppLanguage.en => 'Summary',
                    AppLanguage.both => 'Tổng kết • Summary',
                  },
                ),
              ),
            ),
          if (isLast)
            FilledButton.icon(
              key: const Key('practice_finish_bottom_button'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () => showSummaryDialog(context, practice: practice, lang: lang),
              icon: const Icon(Icons.check_circle_outline),
              label: Text(
                switch (lang) {
                  AppLanguage.vi => 'Hoàn thành',
                  AppLanguage.en => 'Complete',
                  AppLanguage.both => 'Hoàn thành • Complete',
                },
              ),
            )
          else
            FilledButton.icon(
              key: const Key('practice_next_button'),
              onPressed: practice.nextQuestion,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Câu tiếp'),
            ),
        ],
      ),
    );
  }

  static void showSummaryDialog(
    BuildContext context, {
    required PracticeProvider practice,
    required AppLanguage lang,
  }) {
    final answered = practice.answeredCount;
    final correct = practice.correctCount;
    final percent = answered > 0 ? (correct / answered * 100).round() : 0;

    final evaluation = switch (lang) {
      AppLanguage.vi => percent >= 80
          ? 'Xuất sắc! Bạn nắm rất vững kiến thức. 🌟'
          : (percent >= 50
              ? 'Khá tốt! Hãy ôn lại các câu chưa đúng nhé. 👍'
              : 'Cố gắng lên! Hãy đọc kỹ giải thích để tiến bộ hơn. 💪'),
      AppLanguage.en => percent >= 80
          ? 'Excellent! You have a strong grasp of the material. 🌟'
          : (percent >= 50
              ? 'Good job! Keep reviewing what you missed. 👍'
              : 'Keep going! Read the explanations carefully to improve. 💪'),
      AppLanguage.both => percent >= 80
          ? 'Xuất sắc! 🌟 • Excellent!'
          : (percent >= 50
              ? 'Khá tốt! 👍 • Good job!'
              : 'Cố gắng lên! 💪 • Keep going!'),
    };

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.emoji_events_outlined, color: Colors.amber, size: 28),
            const SizedBox(width: 8),
            Text(switch (lang) {
              AppLanguage.vi => 'Tổng kết phiên',
              AppLanguage.en => 'Session Summary',
              AppLanguage.both => 'Tổng kết • Summary',
            }),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              evaluation,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              color: Theme.of(ctx).colorScheme.surfaceContainerHighest.withAlpha(128),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(switch (lang) {
                          AppLanguage.vi => 'Số câu đã làm:',
                          AppLanguage.en => 'Questions answered:',
                          AppLanguage.both => 'Đã làm • Answered:',
                        }),
                        Text('$answered', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(switch (lang) {
                          AppLanguage.vi => 'Số câu đúng:',
                          AppLanguage.en => 'Correct answers:',
                          AppLanguage.both => 'Đúng • Correct:',
                        }),
                        Text(
                          '$correct',
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(switch (lang) {
                          AppLanguage.vi => 'Tỷ lệ chính xác:',
                          AppLanguage.en => 'Accuracy rate:',
                          AppLanguage.both => 'Tỷ lệ • Accuracy:',
                        }),
                        Text(
                          '$percent%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: percent >= 80
                                ? Colors.green.shade700
                                : (percent >= 50 ? Colors.orange.shade800 : Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(switch (lang) {
              AppLanguage.vi => 'Luyện tiếp',
              AppLanguage.en => 'Continue',
              AppLanguage.both => 'Luyện tiếp • Continue',
            }),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Về trang chủ
            },
            child: Text(switch (lang) {
              AppLanguage.vi => 'Về trang chủ',
              AppLanguage.en => 'Home',
              AppLanguage.both => 'Trang chủ • Home',
            }),
          ),
        ],
      ),
    );
  }
}

