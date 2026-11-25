import '../core/errors/app_exception.dart';
import '../models/quiz_result.dart';
import '../services/local_database.dart';

/// Hợp đồng lưu lịch sử làm bài.
abstract interface class HistoryRepository {
  /// Lưu 1 lượt làm bài + các câu sai + cộng dồn thống kê theo khối.
  Future<int> saveResult(QuizResult result);
  Future<List<QuizResult>> getResults({int limit = 50});

  /// Id các câu từng làm sai (không trùng) – dùng cho chế độ "Ôn lại câu sai".
  Future<Set<int>> getWrongQuestionIds();

  /// Thống kê đúng/tổng của từng khối kiến thức (sắp xếp theo tên khối).
  Future<List<CategoryStat>> getCategoryStats();

  /// Xóa các câu đã làm ĐÚNG lại khỏi danh sách câu sai.
  Future<void> removeWrongAnswers(Set<int> questionIds);

  /// Xóa toàn bộ: lịch sử điểm, câu sai và thống kê theo khối.
  Future<void> clearHistory();
}

class SqfliteHistoryRepository implements HistoryRepository {
  SqfliteHistoryRepository(this._localDb);

  final LocalDatabase _localDb;

  @override
  Future<int> saveResult(QuizResult result) async {
    try {
      final db = await _localDb.database;
      // Transaction: lỗi giữa chừng thì rollback hết, không lưu dở dang.
      return await db.transaction((txn) async {
        final resultId = await txn.insert(LocalDatabase.tableResults, result.toDbMap());
        final now = DateTime.now().toIso8601String();
        final batch = txn.batch();
        for (final w in result.wrongAnswers) {
          batch.insert(LocalDatabase.tableWrongAnswers, {
            'result_id': resultId,
            'question_id': w.question.id,
            'selected_index': w.selectedIndex,
            'created_at': now,
          });
        }
        // Cộng dồn thống kê: khối chưa có thì tạo dòng 0/0 rồi UPDATE cộng thêm.
        // (Không dùng ON CONFLICT DO UPDATE vì SQLite trên Android cũ < 3.24 không hỗ trợ.)
        for (final s in result.statsByCategory.values) {
          batch.rawInsert(
            'INSERT OR IGNORE INTO ${LocalDatabase.tableCategoryStats} '
            '(category, correct_count, total_count) VALUES (?, 0, 0)',
            [s.category],
          );
          batch.rawUpdate(
            'UPDATE ${LocalDatabase.tableCategoryStats} '
            'SET correct_count = correct_count + ?, total_count = total_count + ? '
            'WHERE category = ?',
            [s.correct, s.total, s.category],
          );
        }
        await batch.commit(noResult: true);
        return resultId;
      });
    } catch (e) {
      throw AppException('Không lưu được kết quả làm bài.', cause: e);
    }
  }

  @override
  Future<List<QuizResult>> getResults({int limit = 50}) async {
    try {
      final db = await _localDb.database;
      final rows = await db.query(
        LocalDatabase.tableResults,
        orderBy: 'taken_at DESC',
        limit: limit,
      );
      return rows.map(QuizResult.fromDbMap).toList(growable: false);
    } catch (e) {
      throw AppException('Không đọc được lịch sử làm bài.', cause: e);
    }
  }

  @override
  Future<Set<int>> getWrongQuestionIds() async {
    try {
      final db = await _localDb.database;
      final rows = await db.rawQuery(
        'SELECT DISTINCT question_id FROM ${LocalDatabase.tableWrongAnswers}',
      );
      return rows.map((r) => r['question_id'] as int).toSet();
    } catch (e) {
      throw AppException('Không đọc được danh sách câu sai.', cause: e);
    }
  }

  @override
  Future<List<CategoryStat>> getCategoryStats() async {
    try {
      final db = await _localDb.database;
      final rows = await db.query(
        LocalDatabase.tableCategoryStats,
        orderBy: 'category ASC',
      );
      return rows.map(CategoryStat.fromDbMap).toList(growable: false);
    } catch (e) {
      throw AppException('Không đọc được thống kê theo khối.', cause: e);
    }
  }

  @override
  Future<void> removeWrongAnswers(Set<int> questionIds) async {
    if (questionIds.isEmpty) return;
    try {
      final db = await _localDb.database;
      // Tạo đúng số dấu ? theo số phần tử -> tránh SQL injection.
      final placeholders = List.filled(questionIds.length, '?').join(', ');
      await db.delete(
        LocalDatabase.tableWrongAnswers,
        where: 'question_id IN ($placeholders)',
        whereArgs: questionIds.toList(),
      );
    } catch (e) {
      throw AppException('Không cập nhật được danh sách câu sai.', cause: e);
    }
  }

  @override
  Future<void> clearHistory() async {
    try {
      final db = await _localDb.database;
      await db.transaction((txn) async {
        // wrong_answers cũng tự xóa nhờ ON DELETE CASCADE; xóa thêm cho chắc chắn.
        await txn.delete(LocalDatabase.tableWrongAnswers);
        await txn.delete(LocalDatabase.tableResults); // DELETE FROM quiz_results
        await txn.delete(LocalDatabase.tableCategoryStats);
      });
    } catch (e) {
      throw AppException('Không xóa được lịch sử làm bài.', cause: e);
    }
  }
}

/// Lưu lịch sử trong bộ nhớ (RAM) khi chạy trên Web (Chrome/Edge) – vì sqflite chỉ hỗ trợ Android/iOS.
/// Trên Android/iOS, app vẫn dùng [SqfliteHistoryRepository] chuẩn SQLite 100%.
class InMemoryHistoryRepository implements HistoryRepository {
  final List<QuizResult> _results = [];
  final Set<int> _wrongQuestionIds = {};
  final Map<String, CategoryStat> _categoryStats = {};
  int _autoIncrement = 0;

  @override
  Future<int> saveResult(QuizResult result) async {
    final id = ++_autoIncrement;
    final saved = QuizResult(
      id: id,
      totalQuestions: result.totalQuestions,
      correctCount: result.correctCount,
      duration: result.duration,
      takenAt: result.takenAt,
      wrongAnswers: result.wrongAnswers,
      answers: result.answers,
    );
    _results.insert(0, saved);
    for (final w in result.wrongAnswers) {
      _wrongQuestionIds.add(w.question.id);
    }
    for (final s in result.statsByCategory.values) {
      final old = _categoryStats[s.category];
      _categoryStats[s.category] = CategoryStat(
        category: s.category,
        correct: (old?.correct ?? 0) + s.correct,
        total: (old?.total ?? 0) + s.total,
      );
    }
    return id;
  }

  @override
  Future<List<QuizResult>> getResults({int limit = 50}) async {
    return _results.take(limit).toList(growable: false);
  }

  @override
  Future<Set<int>> getWrongQuestionIds() async {
    return Set.unmodifiable(_wrongQuestionIds);
  }

  @override
  Future<List<CategoryStat>> getCategoryStats() async {
    final list = _categoryStats.values.toList()
      ..sort((a, b) => a.category.compareTo(b.category));
    return List.unmodifiable(list);
  }

  @override
  Future<void> removeWrongAnswers(Set<int> questionIds) async {
    _wrongQuestionIds.removeAll(questionIds);
  }

  @override
  Future<void> clearHistory() async {
    _results.clear();
    _wrongQuestionIds.clear();
    _categoryStats.clear();
  }
}
