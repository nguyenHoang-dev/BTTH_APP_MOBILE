import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/localized_text.dart';
import '../models/question.dart';
import '../providers/practice_provider.dart';
import '../providers/quiz_provider.dart';
import '../providers/settings_provider.dart';

/// Bộ giải mã / mã hóa chuỗi JSON câu hỏi trong mã QR.
class QrQuestionCodec {
  const QrQuestionCodec._();

  static String encode(Question q) {
    return jsonEncode(q.toJson());
  }

  static LocalizedText _parseLocalized(dynamic raw, {String fallback = ''}) {
    if (raw is Map) {
      final vi = (raw['vi'] ?? raw['en'] ?? fallback).toString().trim();
      final en = (raw['en'] ?? raw['vi'] ?? fallback).toString().trim();
      return LocalizedText(vi: vi, en: en);
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return LocalizedText(vi: raw.trim(), en: raw.trim());
    }
    return LocalizedText(vi: fallback, en: fallback);
  }

  static Question decode(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Mã QR trống.');
    }
    final decoded = jsonDecode(trimmed);
    if (decoded is! Map) {
      throw const FormatException('Mã QR không phải định dạng JSON câu hỏi.');
    }
    final map = Map<String, dynamic>.from(decoded);

    final idRaw = map['id'];
    final id = idRaw is int ? idRaw : (int.tryParse('$idRaw') ?? 999);
    final category =
        (map['category'] ?? map['cat'] ?? 'Khối 1. Ngôn ngữ Dart').toString();

    final questionRaw = map['question'] ?? map['q'] ?? map['content'];
    if (questionRaw == null) {
      throw const FormatException('Thiếu trường nội dung câu hỏi (question).');
    }
    final content = _parseLocalized(questionRaw);
    if (content.vi.isEmpty && content.en.isEmpty) {
      throw const FormatException('Nội dung câu hỏi trong mã QR đang trống.');
    }

    final optionsRaw = map['options'] ?? map['o'];
    if (optionsRaw is! List || optionsRaw.length < 2) {
      throw const FormatException('Mã QR cần có danh sách đáp án (options).');
    }
    final options = optionsRaw
        .map((e) => _parseLocalized(e))
        .toList(growable: false);

    final correctRaw = map['correctIndex'] ?? map['c'] ?? 0;
    final correctIndex =
        correctRaw is int ? correctRaw : (int.tryParse('$correctRaw') ?? 0);
    if (correctIndex < 0 || correctIndex >= options.length) {
      throw const FormatException('Chỉ số đáp án đúng (correctIndex) không hợp lệ.');
    }

    final expRaw = map['explanation'] ?? map['exp'];
    final explanation = expRaw == null ? null : _parseLocalized(expRaw);

    return Question(
      id: id,
      category: category,
      content: content,
      options: options,
      correctIndex: correctIndex,
      explanation: explanation,
    );
  }

  static Question sampleQrQuestion() {
    return const Question(
      id: 301,
      category: 'Khối 9. Điều hướng',
      content: LocalizedText(
        vi: 'Trong Flutter 3.16+, widget nào thay thế WillPopScope để chặn thao tác thoát màn hình khi đang làm bài thi?',
        en: 'In Flutter 3.16+, which widget replaces WillPopScope to intercept back navigation during an active exam?',
      ),
      options: [
        LocalizedText(vi: 'BackButtonListener', en: 'BackButtonListener'),
        LocalizedText(vi: 'PopScope', en: 'PopScope'),
        LocalizedText(vi: 'NavigatorObserver', en: 'NavigatorObserver'),
        LocalizedText(vi: ' HeroController', en: 'HeroController'),
      ],
      correctIndex: 1,
      explanation: LocalizedText(
        vi: 'PopScope(canPop: false, onPopInvokedWithResult: ...) là widget chuẩn trong Flutter 3.16+ để kiểm soát thao tác Back hệ thống và hiển thị cảnh báo thoát bài thi.',
        en: 'PopScope(canPop: false, onPopInvokedWithResult: ...) is the standard widget in Flutter 3.16+ to intercept system back gestures and show an exit confirmation dialog.',
      ),
    );
  }
}

/// Màn hình Quét mã QR thêm câu hỏi & Tạo mã QR chia sẻ bộ đề.
class QrQuestionScreen extends StatefulWidget {
  const QrQuestionScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  /// Hiển thị BottomSheet mã QR chia sẻ cho bất kỳ câu hỏi nào.
  static Future<void> showShareSheet(
    BuildContext context,
    Question question,
  ) async {
    final payload = QrQuestionCodec.encode(question);
    final lang = context.read<SettingsProvider>().language;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colorScheme = theme.colorScheme;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.qr_code_2_rounded, color: colorScheme.primary, size: 26),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mã QR chia sẻ câu hỏi #${question.id}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Bạn bè mở mục "Quét mã QR" và hướng camera vào mã dưới đây để lưu câu hỏi này vào máy.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: payload,
                      version: QrVersions.auto,
                      size: 230,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          question.category,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        question.content.resolve(lang),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: payload));
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Đã sao chép chuỗi JSON mã QR vào bộ nhớ tạm.'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Sao chép mã'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Đóng'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  State<QrQuestionScreen> createState() => _QrQuestionScreenState();
}

class _QrQuestionScreenState extends State<QrQuestionScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _isPreviewOpen = false;
  List<Question> _allQuestions = const [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBank());
  }

  Future<void> _loadBank() async {
    final quizProvider = context.read<QuizProvider>();
    await quizProvider.loadSubjectCounts();
    final bank = await quizProvider.loadAllBankQuestions();
    if (!mounted) return;
    setState(() {
      _allQuestions = bank.reversed.toList(growable: false);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleRawQrString(String raw) async {
    if (_isPreviewOpen) return;
    setState(() => _isPreviewOpen = true);

    try {
      final parsed = QrQuestionCodec.decode(raw);
      if (!mounted) return;
      await _showScannedPreviewDialog(parsed);
    } on FormatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text('Mã QR không hợp lệ: ${e.message}'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: const Text('Không thể đọc dữ liệu câu hỏi từ mã QR này.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isPreviewOpen = false);
      }
    }
  }

  Future<void> _showScannedPreviewDialog(Question question) async {
    final colorScheme = Theme.of(context).colorScheme;

    final shouldSave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.qr_code_scanner_rounded,
          color: colorScheme.primary,
          size: 34,
        ),
        title: const Text('Xem trước câu hỏi từ QR'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  question.category,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                question.content.vi,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                ),
              ),
              if (question.content.en.isNotEmpty &&
                  question.content.en != question.content.vi) ...[
                const SizedBox(height: 4),
                Text(
                  question.content.en,
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'Các phương án trả lời:',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              for (var i = 0; i < question.options.length; i++)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: i == question.correctIndex
                        ? Colors.green.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: i == question.correctIndex
                          ? Colors.green.shade600
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        i == question.correctIndex
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 18,
                        color: i == question.correctIndex
                            ? Colors.green.shade700
                            : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${String.fromCharCode(65 + i)}. ${question.options[i].resolve(AppLanguage.both)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: i == question.correctIndex
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (question.explanation != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Giải thích: ${question.explanation!.vi}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Quét lại'),
          ),
          FilledButton.icon(
            key: const Key('save_qr_question_button'),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.download_done_rounded, size: 18),
            label: const Text('Lưu vào bộ đề ôn tập'),
          ),
        ],
      ),
    );

    if (shouldSave != true || !mounted) return;

    final quizProvider = context.read<QuizProvider>();
    final practiceProvider = context.read<PracticeProvider>();
    final saved = await quizProvider.addCustomQuestion(question);
    await practiceProvider.loadQuestions(category: practiceProvider.selectedCategory);
    await _loadBank();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green.shade700,
        content: Text(
          'Đã lưu câu hỏi #${saved.id} vào ngân hàng ôn tập (Tổng: ${quizProvider.totalBankCount} câu)!',
        ),
      ),
    );
  }

  Future<void> _showPasteQrDialog() async {
    final ctrl = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nhập / Dán dữ liệu mã QR'),
        content: TextField(
          key: const Key('paste_qr_input'),
          controller: ctrl,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: '{"category":"Khối 1. Ngôn ngữ Dart","question":{"vi":"...","en":"..."},...}',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Kiểm tra & Xem trước'),
          ),
        ],
      ),
    );
    if (raw == null || raw.trim().isEmpty) return;
    await _handleRawQrString(raw);
  }

  Future<void> _showCreateQuestionDialog() async {
    final formKey = GlobalKey<FormState>();
    final viCtrl = TextEditingController();
    final enCtrl = TextEditingController();
    final optCtrls = List.generate(4, (_) => TextEditingController());
    final expCtrl = TextEditingController();
    var selectedCategory = 'Khối 1. Ngôn ngữ Dart';
    var correctIndex = 0;

    final created = await showDialog<Question>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Tạo câu hỏi & Mã QR chia sẻ'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Chủ đề (Khối kiến thức)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Khối 1. Ngôn ngữ Dart',
                        child: Text('Khối 1. Ngôn ngữ Dart'),
                      ),
                      DropdownMenuItem(
                        value: 'Khối 3. Cách Flutter hoạt động',
                        child: Text('Khối 3. Cách Flutter hoạt động'),
                      ),
                      DropdownMenuItem(
                        value: 'Khối 4. Bố cục và cuộn',
                        child: Text('Khối 4. Bố cục và cuộn'),
                      ),
                      DropdownMenuItem(
                        value: 'Khối 9. Điều hướng',
                        child: Text('Khối 9. Điều hướng'),
                      ),
                      DropdownMenuItem(
                        value: 'Khối 12. Quản lý trạng thái',
                        child: Text('Khối 12. Quản lý trạng thái'),
                      ),
                      DropdownMenuItem(
                        value: 'Khối 13. Dữ liệu và backend',
                        child: Text('Khối 13. Dữ liệu và backend'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedCategory = val);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: viCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Câu hỏi (Tiếng Việt)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Vui lòng nhập câu hỏi tiếng Việt'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: enCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Question (English - tùy chọn)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < 4; i++) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextFormField(
                        controller: optCtrls[i],
                        decoration: InputDecoration(
                          labelText: 'Đáp án ${String.fromCharCode(65 + i)}',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Nhập đáp án ${String.fromCharCode(65 + i)}'
                            : null,
                      ),
                    ),
                  ],
                  DropdownButtonFormField<int>(
                    initialValue: correctIndex,
                    decoration: InputDecoration(
                      labelText: 'Đáp án đúng',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [
                      for (var i = 0; i < 4; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text('Đáp án ${String.fromCharCode(65 + i)}'),
                        ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => correctIndex = val);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: expCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Giải thích đáp án (tùy chọn)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final vi = viCtrl.text.trim();
                final en = enCtrl.text.trim().isEmpty ? vi : enCtrl.text.trim();
                final exp = expCtrl.text.trim();
                Navigator.pop(
                  ctx,
                  Question(
                    id: 999,
                    category: selectedCategory,
                    content: LocalizedText(vi: vi, en: en),
                    options: [
                      for (final c in optCtrls)
                        LocalizedText(vi: c.text.trim(), en: c.text.trim()),
                    ],
                    correctIndex: correctIndex,
                    explanation: exp.isEmpty
                        ? null
                        : LocalizedText(vi: exp, en: exp),
                  ),
                );
              },
              icon: const Icon(Icons.qr_code_2_rounded, size: 18),
              label: const Text('Lưu & Tạo QR'),
            ),
          ],
        ),
      ),
    );

    if (created == null || !mounted) return;
    final quizProvider = context.read<QuizProvider>();
    final practiceProvider = context.read<PracticeProvider>();
    final saved = await quizProvider.addCustomQuestion(created);
    await practiceProvider.loadQuestions(category: practiceProvider.selectedCategory);
    await _loadBank();
    if (!mounted) return;
    await QrQuestionScreen.showShareSheet(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    final quizProvider = context.watch<QuizProvider>();
    final customList = quizProvider.customQuestions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mã QR Câu hỏi Ôn tập'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.qr_code_scanner_rounded),
              text: 'Quét mã QR',
            ),
            Tab(
              icon: Icon(Icons.qr_code_2_rounded),
              text: 'Tạo mã QR chia sẻ',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScannerTab(context),
          _buildShareTab(context, customList),
        ],
      ),
    );
  }

  Widget _buildScannerTab(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.camera_alt_outlined, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Hướng camera vào mã QR câu hỏi của bạn bè',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Bật/Tắt đèn Flash',
                      icon: const Icon(Icons.flash_on_rounded),
                      onPressed: _scannerController.toggleTorch,
                    ),
                    IconButton(
                      tooltip: 'Đổi camera trước/sau',
                      icon: const Icon(Icons.cameraswitch_rounded),
                      onPressed: _scannerController.switchCamera,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 290,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        MobileScanner(
                          controller: _scannerController,
                          onDetect: (capture) {
                            for (final barcode in capture.barcodes) {
                              final raw = barcode.rawValue;
                              if (raw != null && raw.isNotEmpty) {
                                _handleRawQrString(raw);
                                break;
                              }
                            }
                          },
                        ),
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.amberAccent,
                              width: 2.5,
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Sau khi quét trúng mã QR hợp lệ, hệ thống sẽ hiện Thẻ xem trước (Preview) để bạn kiểm tra rồi bấm "Lưu vào bộ đề ôn tập".',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.tonalIcon(
          key: const Key('demo_qr_scan_button'),
          onPressed: () {
            final sampleJson = QrQuestionCodec.encode(
              QrQuestionCodec.sampleQrQuestion(),
            );
            _handleRawQrString(sampleJson);
          },
          icon: const Icon(Icons.qr_code_scanner_rounded),
          label: const Text('Quét thử mã QR mẫu (Xem trước & Lưu vào bộ đề)'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('paste_qr_button'),
          onPressed: _showPasteQrDialog,
          icon: const Icon(Icons.content_paste_rounded),
          label: const Text('Nhập / Dán chuỗi mã QR JSON'),
        ),
      ],
    );
  }

  Widget _buildShareTab(BuildContext context, List<Question> customList) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final lang = context.watch<SettingsProvider>().language;

    final filtered = _searchQuery.trim().isEmpty
        ? _allQuestions.take(30).toList(growable: false)
        : _allQuestions
            .where((q) {
              final keyword = _searchQuery.toLowerCase();
              return q.content.vi.toLowerCase().contains(keyword) ||
                  q.content.en.toLowerCase().contains(keyword) ||
                  q.category.toLowerCase().contains(keyword) ||
                  '${q.id}'.contains(keyword);
            })
            .take(30)
            .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          key: const Key('create_custom_qr_button'),
          onPressed: _showCreateQuestionDialog,
          icon: const Icon(Icons.add_circle_outline_rounded),
          label: const Text('Tự biên soạn câu hỏi mới & Tạo mã QR'),
        ),
        const SizedBox(height: 14),
        if (customList.isNotEmpty) ...[
          Text(
            'Câu hỏi đã thêm từ mã QR (${customList.length} câu):',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          for (final q in customList.reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    child: Text('#${q.id}', style: const TextStyle(fontSize: 11)),
                  ),
                  title: Text(
                    q.content.resolve(lang),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                  subtitle: Text(q.category, style: const TextStyle(fontSize: 11.5)),
                  trailing: IconButton(
                    icon: Icon(Icons.qr_code_2_rounded, color: colorScheme.primary),
                    tooltip: 'Hiện mã QR',
                    onPressed: () => QrQuestionScreen.showShareSheet(context, q),
                  ),
                  onTap: () => QrQuestionScreen.showShareSheet(context, q),
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
        Text(
          'Chọn câu hỏi trong bộ đề để tạo mã QR chia sẻ:',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            hintText: 'Tìm câu hỏi theo từ khóa, khối hoặc #ID...',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onChanged: (val) => setState(() => _searchQuery = val),
        ),
        const SizedBox(height: 10),
        for (final q in filtered)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  child: Text(
                    '#${q.id}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
                title: Text(
                  q.content.resolve(lang),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(q.category, style: const TextStyle(fontSize: 11.5)),
                trailing: FilledButton.tonalIcon(
                  onPressed: () => QrQuestionScreen.showShareSheet(context, q),
                  icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                  label: const Text('Mã QR'),
                ),
                onTap: () => QrQuestionScreen.showShareSheet(context, q),
              ),
            ),
          ),
      ],
    );
  }
}
