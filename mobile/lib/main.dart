import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/app_dependencies.dart';
import 'providers/settings_provider.dart';
import 'repositories/history_repository.dart';
import 'repositories/quiz_repository.dart';
import 'services/local_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = SettingsProvider();

  // Trên Android/iOS dùng SQLite (sqflite); trên Web dùng InMemoryHistoryRepository.
  final HistoryRepository historyRepo = kIsWeb
      ? InMemoryHistoryRepository()
      : SqfliteHistoryRepository(LocalDatabase());

  final deps = AppDependencies(
    settings: settings,
    quizRepository: AssetQuizRepository(),
    historyRepository: historyRepo,
  );

  runApp(BilingualQuizApp(dependencies: deps));
}
