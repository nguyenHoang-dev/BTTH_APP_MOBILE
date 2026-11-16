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
}

