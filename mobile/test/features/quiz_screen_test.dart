import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sig_sols_mobile/core/api/api_client.dart';
import 'package:sig_sols_mobile/features/quiz/quiz_screen.dart';
import 'package:sig_sols_mobile/services/sig_api.dart';

class _QuizApi extends SigApi {
  _QuizApi() : super(ApiClient());

  final List<int> answers = [];

  @override
  Future<Map<String, dynamic>> quizStats() async => {
    'best_score': 8,
    'sessions_count': 2,
  };

  @override
  Future<dynamic> quizLeaderboard() async => {
    'top_10': [
      {'username': 'agriculteur', 'score': 12},
    ],
  };

  @override
  Future<List<dynamic>> quizBadges() async => [
    {'badge': 'Premier pas'},
  ];

  @override
  Future<Map<String, dynamic>> quizLearningPath() async => {'progress_pct': 40};

  @override
  Future<Map<String, dynamic>> quizWeeklyChallenge() async => {
    'title': 'Défi sols',
  };

  @override
  Future<Map<String, dynamic>> startQuiz({
    String difficulty = 'facile',
    int count = 10,
    bool examMode = false,
  }) async => {
    'session_id': 7,
    'timer_seconds': examMode ? 120 : 20,
    'exam_mode': examMode,
    'questions': [
      {
        'id': 1,
        'text': 'Quelle réponse est correcte ?',
        'choices': ['La première', 'La seconde'],
      },
      {
        'id': 2,
        'text': 'Question finale',
        'choices': ['Oui', 'Non'],
      },
    ],
  };

  @override
  Future<Map<String, dynamic>> submitQuizAnswer(
    int sessionId, {
    required int questionId,
    required int selectedIndex,
  }) async {
    answers.add(selectedIndex);
    return {
      'session_score': answers.length * 5,
      'correct': true,
      'points_earned': 5,
    };
  }

  @override
  Future<Map<String, dynamic>> finishQuiz(int sessionId) async => {
    'final_score': 10,
    'badges_earned': [
      {'name': 'Expert sols'},
    ],
  };
}

void main() {
  testWidgets('normal quiz shows feedback then completes with certificate', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _QuizApi();
    await tester.pumpWidget(
      Provider<SigApi>.value(
        value: api,
        child: const MaterialApp(home: Scaffold(body: QuizScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mes statistiques'), findsOneWidget);
    expect(find.text('Commencer défi'), findsOneWidget);

    await tester.tap(find.text('Démarrer le quiz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('La première'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Bonne réponse'), findsOneWidget);
    await tester.tap(find.text('Question suivante'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oui'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voir les résultats'));
    await tester.pumpAndSettle();

    expect(api.answers, [0, 0]);
    expect(find.text('Quiz terminé !'), findsOneWidget);
    expect(find.text('Certificat PDF'), findsOneWidget);
  });

  testWidgets('exam mode advances without intermediate feedback', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _QuizApi();
    await tester.pumpWidget(
      Provider<SigApi>.value(
        value: api,
        child: const MaterialApp(home: Scaffold(body: QuizScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.tap(find.text('Démarrer le quiz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('La première'));
    await tester.pumpAndSettle();

    expect(find.text('Question finale'), findsOneWidget);
    expect(find.textContaining('Bonne réponse'), findsNothing);
    await tester.tap(find.text('Oui'));
    await tester.pumpAndSettle();
    expect(find.text('Quiz terminé !'), findsOneWidget);
  });
}
