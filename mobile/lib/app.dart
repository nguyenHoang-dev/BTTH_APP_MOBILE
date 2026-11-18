import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/di/app_dependencies.dart';
import 'providers/ai_provider.dart';
import 'providers/history_provider.dart';
import 'providers/practice_provider.dart';
import 'providers/quiz_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';

class BilingualQuizApp extends StatelessWidget {
  const BilingualQuizApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    final d = dependencies;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: d.settings),
        ChangeNotifierProvider(
          create: (_) => QuizProvider(
            quizRepository: d.quizRepository,
            historyRepository: d.historyRepository,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => PracticeProvider(quizRepository: d.quizRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => HistoryProvider(historyRepository: d.historyRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => AIProvider(aiRepository: d.aiRepository),
        ),
      ],
      child: MaterialApp(
        title: 'Ôn tập trắc nghiệm song ngữ',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: const HomeScreen(),
      ),
    );
  }
}

