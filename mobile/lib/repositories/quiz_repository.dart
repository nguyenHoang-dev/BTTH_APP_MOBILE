import 'dart:convert';

import 'package:flutter/services.dart';

import '../core/config/app_config.dart';
import '../core/errors/app_exception.dart';
import '../models/question.dart';

/// Hợp đồng truy cập ngân hàng câu hỏi.
/// UI/Provider chỉ biết interface này => test thay bằng FakeQuizRepository.
abstract interface class QuizRepository {
  /// Toàn bộ ngân hàng câu hỏi (~300 câu).
  Future<List<Question>> loadAllQuestions();
}

/// Đọc câu hỏi từ file JSON cục bộ trong assets (chạy offline 100%).
class AssetQuizRepository implements QuizRepository {
  AssetQuizRepository({AssetBundle? bundle, this.assetPath = AppConfig.questionBankAsset})
      : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final String assetPath;
  List<Question>? _cache;

  @override
  Future<List<Question>> loadAllQuestions() async {
    final cached = _cache;
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
      return _cache = questions;
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
}

