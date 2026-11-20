import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../core/state/view_state.dart';
import '../models/quiz_result.dart';
import '../repositories/history_repository.dart';

/// Thống kê & lịch sử làm bài (đọc từ SQLite).
class HistoryProvider extends ChangeNotifier {
  HistoryProvider({required HistoryRepository historyRepository})
      : _repo = historyRepository;

  final HistoryRepository _repo;

  ViewState<List<QuizResult>> _state = const IdleState();
  ViewState<List<QuizResult>> get state => _state;

  List<CategoryStat> _categoryStats = const [];

  /// Tỷ lệ đúng theo từng khối kiến thức (hiển thị bằng LinearProgressIndicator).
  List<CategoryStat> get categoryStats => _categoryStats;

  int _wrongCount = 0;

  /// Số câu còn nằm trong danh sách "câu sai" (chưa làm đúng lại).
  int get wrongCount => _wrongCount;

  bool _clearing = false;
  bool get isClearing => _clearing;

  int get totalAttempts => _state.dataOrNull?.length ?? 0;

  double get averageScore {
    final list = _state.dataOrNull;
    if (list == null || list.isEmpty) return 0;
    return list.map((r) => r.score10).reduce((a, b) => a + b) / list.length;
  }

  double get bestScore {
    final list = _state.dataOrNull;
    if (list == null || list.isEmpty) return 0;
    return list.map((r) => r.score10).reduce((a, b) => a > b ? a : b);
  }

  Future<void> load() async {
    _state = const LoadingState();
    notifyListeners();
    try {
      final results = await _repo.getResults();
      _categoryStats = await _repo.getCategoryStats();
      _wrongCount = (await _repo.getWrongQuestionIds()).length;
      _state = results.isEmpty
          ? const EmptyState('Chưa có lịch sử. Hãy làm bài đầu tiên nhé!')
          : SuccessState(results);
    } on AppException catch (e) {
      _state = ErrorState(e.message, error: e);
    } catch (e) {
      _state = ErrorState('Không tải được lịch sử.', error: e);
    }
    notifyListeners();
  }

  /// Xóa toàn bộ lịch sử (UI phải hỏi xác nhận bằng AlertDialog TRƯỚC khi gọi).
  /// Trả về thông báo lỗi nếu thất bại, `null` nếu thành công.
  Future<String?> clearHistory() async {
    if (_clearing) return null;
    _clearing = true;
    notifyListeners();
    String? error;
    try {
      await _repo.clearHistory();
    } on AppException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Không xóa được lịch sử làm bài.';
    } finally {
      _clearing = false;
    }
    await load(); // load() tự gọi notifyListeners().
    return error;
  }
}
