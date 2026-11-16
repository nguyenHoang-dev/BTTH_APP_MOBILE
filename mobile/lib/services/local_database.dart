import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// SQLite cục bộ (sqflite) – lưu lịch sử làm bài & các câu làm sai.
/// Không dùng Firebase / DB server ngoài: file .db nằm ngay trên thiết bị.
class LocalDatabase {
  LocalDatabase({this.fileName = 'bilingual_quiz.db'});

  final String fileName;
  static const int _version = 1;

  static const String tableResults = 'quiz_results';
  static const String tableWrongAnswers = 'wrong_answers';

  Database? _db;

  /// Mở DB lười (lazy) – lần đầu gọi mới tạo file.
  Future<Database> get database async {
    final existing = _db;
    if (existing != null && existing.isOpen) return existing;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, fileName),
      version: _version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
    );
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableResults (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        total_questions  INTEGER NOT NULL,
        correct_count    INTEGER NOT NULL,
        duration_seconds INTEGER NOT NULL,
        taken_at         TEXT    NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE $tableWrongAnswers (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        result_id      INTEGER NOT NULL,
        question_id    INTEGER NOT NULL,
        selected_index INTEGER NOT NULL,
        created_at     TEXT    NOT NULL,
        FOREIGN KEY (result_id) REFERENCES $tableResults(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_wrong_question ON $tableWrongAnswers(question_id)',
    );
  }

  Future<void> close() async => _db?.close();
}

