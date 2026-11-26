import '../core/errors/app_exception.dart';
import '../models/quiz_result.dart';
import '../services/local_database.dart';

/// Hợp đồng lưu lịch sử làm bài.
abstract interface class HistoryRepository {
  Future<int> saveResult(QuizResult result);
  Future<List<QuizResult>> getResults({int limit = 50});

  /// Id các câu từng làm sai (không trùng) – dùng cho chế độ "Ôn lại câu sai".
  Future<Set<int>> getWrongQuestionIds();
}

class SqfliteHistoryRepository implements HistoryRepository {
  SqfliteHistoryRepository(this._localDb);

  final LocalDatabase _localDb;

  @override
  Future<int> saveResult(QuizResult result) async {
    try {
      final db = await _localDb.database;
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
}

/// Lưu lịch sử trong bộ nhớ (RAM) khi chạy trên Web (Chrome/Edge) – vì sqflite chỉ hỗ trợ Android/iOS.
/// Trên Android/iOS, app vẫn dùng [SqfliteHistoryRepository] chuẩn SQLite 100%.
class InMemoryHistoryRepository implements HistoryRepository {
  final List<QuizResult> _results = [];
  final Set<int> _wrongQuestionIds = {};
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
    );
    _results.insert(0, saved);
    for (final w in result.wrongAnswers) {
      _wrongQuestionIds.add(w.question.id);
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
}


