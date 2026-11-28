import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../core/config/app_config.dart';
import '../core/errors/app_exception.dart';
import '../models/question.dart';
import '../services/local_database.dart';

/// Hợp đồng truy cập ngân hàng câu hỏi.
/// UI/Provider chỉ biết interface này => test thay bằng FakeQuizRepository.
abstract interface class QuizRepository {
  /// Toàn bộ ngân hàng câu hỏi (~300 câu gốc + câu hỏi quét từ QR).
  Future<List<Question>> loadAllQuestions();

  /// Danh sách các khối kiến thức (category) có trong ngân hàng.
  Future<List<String>> getCategories();

  /// Lọc câu hỏi theo category (truyền null hoặc 'all' để lấy tất cả).
  Future<List<Question>> loadQuestionsByCategory(String? category);

  /// Lưu thêm 1 câu hỏi mới (từ mã QR hoặc tự soạn) vào ngân hàng ôn tập.
  Future<Question> addCustomQuestion(Question question);

  /// Lấy danh sách các câu hỏi đã thêm qua mã QR.
  Future<List<Question>> loadCustomQuestions();
}

/// Đọc câu hỏi từ file JSON cục bộ trong assets + câu hỏi QR trong SQLite (chạy offline 100%).
class AssetQuizRepository implements QuizRepository {
  AssetQuizRepository({
    AssetBundle? bundle,
    this.assetPath = AppConfig.questionBankAsset,
    LocalDatabase? localDatabase,
  })  : _bundle = bundle ?? rootBundle,
        _localDatabase = localDatabase; // ignore: prefer_initializing_formals

  final AssetBundle _bundle;
  final String assetPath;
  final LocalDatabase? _localDatabase;

  List<Question>? _assetCache;
  final List<Question> _customMemoryQuestions = [];

  Future<List<Question>> _loadAssetQuestions() async {
    final cached = _assetCache;
    if (cached != null) return cached;

    try {
      final raw = await _bundle.loadString(assetPath);
      final decoded = jsonDecode(raw);
      final list = decoded is Map<String, dynamic> ? decoded['questions'] : decoded;
      if (list is! List) {
        throw const FormatException('Thiếu mảng "questions"');
      }
      final questions = list
          .map((e) => Question.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
      return _assetCache = questions;
    } on FormatException catch (e) {
      throw AppException(
        'Ngân hàng câu hỏi bị lỗi định dạng.',
        type: AppErrorType.parsing,
        cause: e,
      );
    } catch (e) {
      throw AppException('Không đọc được ngân hàng câu hỏi.', cause: e);
    }
  }

  @override
  Future<List<Question>> loadCustomQuestions() async {
    final dbHelper = _localDatabase;
    if (dbHelper == null) {
      return List.unmodifiable(_customMemoryQuestions);
    }
    try {
      final db = await dbHelper.database;
      final rows = await db.query(
        LocalDatabase.tableCustomQuestions,
        orderBy: 'id ASC',
      );
      final custom = <Question>[];
      for (final row in rows) {
        final rawJson = row['payload_json'] as String?;
        if (rawJson == null || rawJson.isEmpty) continue;
        final map = jsonDecode(rawJson) as Map<String, dynamic>;
        custom.add(Question.fromJson(map));
      }
      return custom;
    } catch (_) {
      return List.unmodifiable(_customMemoryQuestions);
    }
  }

  @override
  Future<List<Question>> loadAllQuestions() async {
    final baseQuestions = await _loadAssetQuestions();
    final customQuestions = await loadCustomQuestions();
    if (customQuestions.isEmpty) return baseQuestions;

    final byId = <int, Question>{
      for (final q in baseQuestions) q.id: q,
      for (final q in customQuestions) q.id: q,
    };
    return byId.values.toList(growable: false);
  }

  @override
  Future<Question> addCustomQuestion(Question question) async {
    final all = await loadAllQuestions();
    var maxId = 300;
    for (final q in all) {
      if (q.id > maxId) maxId = q.id;
    }
    final assignedId = (question.id > 300 && !all.any((q) => q.id == question.id))
        ? question.id
        : maxId + 1;

    final savedQuestion = Question(
      id: assignedId,
      category: question.category.trim().isEmpty
          ? 'Khối 1. Ngôn ngữ Dart'
          : question.category.trim(),
      content: question.content,
      options: question.options,
      correctIndex: question.correctIndex,
      explanation: question.explanation,
    );

    _customMemoryQuestions.removeWhere((q) => q.id == savedQuestion.id);
    _customMemoryQuestions.add(savedQuestion);

    final dbHelper = _localDatabase;
    if (dbHelper != null) {
      try {
        final db = await dbHelper.database;
        await db.insert(
          LocalDatabase.tableCustomQuestions,
          {
            'id': savedQuestion.id,
            'payload_json': jsonEncode(savedQuestion.toJson()),
            'created_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (_) {
        // Nếu DB lỗi vẫn giữ trong _customMemoryQuestions của phiên hiện tại.
      }
    }
    return savedQuestion;
  }

  @override
  Future<List<String>> getCategories() async {
    final questions = await loadAllQuestions();
    final categories = <String>{};
    for (final q in questions) {
      if (q.category.isNotEmpty) {
        categories.add(q.category);
      }
    }
    return categories.toList(growable: false);
  }

  @override
  Future<List<Question>> loadQuestionsByCategory(String? category) async {
    final questions = await loadAllQuestions();
    if (category == null || category.isEmpty || category.toLowerCase() == 'all') {
      return questions;
    }
    return questions
        .where((q) => q.category.toLowerCase() == category.toLowerCase())
        .toList(growable: false);
  }
}

