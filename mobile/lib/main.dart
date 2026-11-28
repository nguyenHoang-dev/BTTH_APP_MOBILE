import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/app_dependencies.dart';
import 'providers/settings_provider.dart';
import 'repositories/ai_repository.dart';
import 'repositories/history_repository.dart';
import 'repositories/quiz_repository.dart';
import 'services/api_client.dart';
import 'services/base_url_resolver.dart';
import 'services/local_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Tự nhận diện Emulator (10.0.2.2) / Web (localhost) / thiết bị thật (API_BASE_URL).
  final baseUrl = await BaseUrlResolver().resolve();
  debugPrint('[main] API base URL = $baseUrl');

  final settings = SettingsProvider();
  final apiClient = ApiClient(baseUrl: baseUrl);

  // Trên Android/iOS dùng SQLite (sqflite); trên Web dùng InMemoryHistoryRepository.
  final localDb = kIsWeb ? null : LocalDatabase();
  final HistoryRepository historyRepo = localDb == null
      ? InMemoryHistoryRepository()
      : SqfliteHistoryRepository(localDb);

  final deps = AppDependencies(
    settings: settings,
    quizRepository: AssetQuizRepository(localDatabase: localDb),
    historyRepository: historyRepo,
    aiRepository: AIRepositoryImpl(
      apiClient: apiClient,
      isDemoMode: () => settings.demoMode,
    ),
  );

  runApp(BilingualQuizApp(dependencies: deps));
}
