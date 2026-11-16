import '../../repositories/ai_repository.dart';
import '../../repositories/history_repository.dart';
import '../../repositories/quiz_repository.dart';
import '../../providers/settings_provider.dart';

/// Gom mọi phụ thuộc ở MỘT chỗ (Composition Root).
///
/// - App thật: lắp ráp trong main.dart (AssetQuizRepository, Sqflite, AIRepositoryImpl).
/// - Test:     tự new AppDependencies với Fake/Mock repository.
class AppDependencies {
  const AppDependencies({
    required this.settings,
    required this.quizRepository,
    required this.historyRepository,
    required this.aiRepository,
  });

  final SettingsProvider settings;
  final QuizRepository quizRepository;
  final HistoryRepository historyRepository;
  final AIRepository aiRepository;
}
