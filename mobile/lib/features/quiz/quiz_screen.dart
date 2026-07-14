import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/sig_api.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import 'package:url_launcher/url_launcher.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  Map<String, dynamic>? _stats;
  List<dynamic>? _leaderboard;
  List<dynamic>? _badges;
  Map<String, dynamic>? _learningPath;
  Map<String, dynamic>? _weeklyChallenge;
  int? _sessionId;
  List<dynamic> _questions = [];
  int _qIndex = 0;
  int _score = 0;
  String _feedback = '';
  String _difficulty = 'facile';
  int _questionCount = 10;
  bool _examMode = false;
  bool _submitting = false;
  bool _answerSubmitted = false;
  bool _loading = true;
  bool _finished = false;
  Map<String, dynamic>? _finishResult;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<SigApi>();
      final results = await Future.wait([
        api.quizStats(),
        api.quizLeaderboard(),
        api.quizBadges().catchError((_) => <dynamic>[]),
        api.quizLearningPath().catchError((_) => <String, dynamic>{}),
        api.quizWeeklyChallenge().catchError((_) => <String, dynamic>{}),
      ]);
      final board = results[1];
      setState(() {
        _stats = Map<String, dynamic>.from(results[0] as Map);
        if (board is List) {
          _leaderboard = board;
        } else {
          final m = Map<String, dynamic>.from(board as Map);
          _leaderboard = m['top_10'] as List? ?? m['results'] as List? ?? [];
        }
        _badges = results[2] as List<dynamic>;
        _learningPath = Map<String, dynamic>.from(results[3] as Map);
        _weeklyChallenge = Map<String, dynamic>.from(results[4] as Map);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _startQuiz() async {
    setState(() {
      _loading = true;
      _error = null;
      _finished = false;
      _finishResult = null;
      _feedback = '';
      _score = 0;
      _submitting = false;
      _answerSubmitted = false;
    });
    try {
      final data = await context.read<SigApi>().startQuiz(
        difficulty: _difficulty,
        count: _questionCount,
        examMode: _examMode,
      );
      setState(() {
        _sessionId = data['session_id'] as int?;
        _questions = data['questions'] as List? ?? [];
        _qIndex = 0;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _answer(int selectedIndex) async {
    if (_submitting ||
        _answerSubmitted ||
        _sessionId == null ||
        _qIndex >= _questions.length) {
      return;
    }
    final q = _questions[_qIndex] as Map<String, dynamic>;
    setState(() => _submitting = true);
    try {
      final r = await context.read<SigApi>().submitQuizAnswer(
        _sessionId!,
        questionId: q['id'] as int,
        selectedIndex: selectedIndex,
      );
      setState(() {
        _score = r['session_score'] as int? ?? _score;
        _feedback =
            _examMode
                ? ''
                : r['correct'] == true
                ? 'Bonne réponse ! +${r['points_earned'] ?? 0} point(s)'
                : 'Réponse incorrecte. ${r['explanation'] ?? ''}';
        _submitting = false;
        _answerSubmitted = !_examMode;
      });
      if (_examMode) await _nextQuestion();
    } catch (e) {
      setState(() {
        _feedback = 'Erreur : $e';
        _submitting = false;
      });
    }
  }

  Future<void> _nextQuestion() async {
    final isLast = _qIndex + 1 >= _questions.length;
    if (isLast) {
      await _finish();
      return;
    }
    if (!mounted) return;
    setState(() {
      _qIndex++;
      _feedback = '';
      _answerSubmitted = false;
    });
  }

  Future<void> _finish() async {
    if (_sessionId == null) return;
    try {
      final r = await context.read<SigApi>().finishQuiz(_sessionId!);
      setState(() {
        _finished = true;
        _finishResult = r;
        _submitting = false;
      });
    } catch (e) {
      setState(() => _feedback = 'Erreur finish: $e');
    }
  }

  void _reset() {
    setState(() {
      _sessionId = null;
      _questions = [];
      _qIndex = 0;
      _finished = false;
      _finishResult = null;
      _feedback = '';
      _answerSubmitted = false;
      _submitting = false;
    });
    _load();
  }

  Future<void> _openCertificate() async {
    if (_sessionId == null) return;
    final uri = Uri.parse(
      context.read<SigApi>().quizCertificateUrl(_sessionId!),
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir le certificat PDF.')),
      );
    }
  }

  Map<String, dynamic> _asMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    if (_finished && _finishResult != null) {
      final score =
          _finishResult!['final_score'] ?? _finishResult!['score'] ?? _score;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Quiz terminé !',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Score final : $score',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'Badges obtenus',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ...((_finishResult!['badges_earned'] as List? ?? const []).map(
            (badge) => Chip(
              avatar: const Icon(Icons.workspace_premium, size: 18),
              label: Text(
                _asMap(badge)['name']?.toString() ??
                    _asMap(badge)['badge']?.toString() ??
                    badge.toString(),
              ),
            ),
          )),
          if ((_finishResult!['badges_earned'] as List? ?? const []).isEmpty)
            const Text('Aucun nouveau badge cette fois-ci.'),
          const SizedBox(height: 16),
          if (_sessionId != null && (score as num) >= 10)
            FilledButton.icon(
              onPressed: _openCertificate,
              icon: const Icon(Icons.workspace_premium),
              label: const Text('Certificat PDF'),
            ),
          OutlinedButton(onPressed: _reset, child: const Text('Nouveau quiz')),
        ],
      );
    }

    if (_sessionId != null && _qIndex < _questions.length) {
      final q = _questions[_qIndex] as Map<String, dynamic>;
      final choices = q['choices'] as List? ?? [];
      final progress =
          (_qIndex + (_answerSubmitted ? 1 : 0)) / _questions.length;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Question ${_qIndex + 1}/${_questions.length} · Score : $_score',
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 12),
              Text(
                q['text']?.toString() ?? '',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              ...choices.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    onPressed:
                        _submitting || _answerSubmitted
                            ? null
                            : () => _answer(e.key),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(e.value.toString()),
                    ),
                  ),
                ),
              ),
              if (_submitting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ),
                ),
              if (!_examMode && _answerSubmitted) ...[
                const SizedBox(height: 8),
                Text(
                  _feedback,
                  style: TextStyle(
                    color:
                        _feedback.startsWith('Bonne')
                            ? Colors.green
                            : Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _nextQuestion,
                  child: Text(
                    _qIndex + 1 == _questions.length
                        ? 'Voir les résultats'
                        : 'Question suivante',
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mes statistiques',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text('Meilleur score : ${_stats?['best_score'] ?? '—'}'),
                Text(
                  'Quiz terminés : ${_stats?['sessions_count'] ?? _stats?['total_sessions'] ?? '—'}',
                ),
              ],
            ),
          ),
        ),
        if (_weeklyChallenge != null && _weeklyChallenge!.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Défi de la semaine',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _weeklyChallenge!['title']?.toString() ??
                        _weeklyChallenge!['description']?.toString() ??
                        'Relevez le défi hebdomadaire.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      final difficulty =
                          _weeklyChallenge!['difficulty']?.toString();
                      if (difficulty != null &&
                          const [
                            'facile',
                            'moyen',
                            'difficile',
                          ].contains(difficulty)) {
                        _difficulty = difficulty;
                      }
                      _startQuiz();
                    },
                    child: const Text('Commencer défi'),
                  ),
                ],
              ),
            ),
          ),
        if (_learningPath != null && _learningPath!.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Parcours pédagogique',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _learningPath!['title']?.toString() ??
                        'Progressez à votre rythme',
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value:
                        ((_learningPath!['progress_pct'] as num?)?.toDouble() ??
                            (_learningPath!['progress'] as num?)?.toDouble() ??
                            0) /
                        100,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Progression : ${_learningPath!['progress_pct'] ?? _learningPath!['progress'] ?? 0}%',
                  ),
                ],
              ),
            ),
          ),
        if (_badges != null && _badges!.isNotEmpty) ...[
          Text('Mes badges', style: Theme.of(context).textTheme.titleMedium),
          Wrap(
            spacing: 8,
            children:
                _badges!.map((b) {
                  final badge = _asMap(b);
                  return Chip(
                    avatar: const Icon(Icons.workspace_premium, size: 18),
                    label: Text(
                      badge['name']?.toString() ??
                          badge['badge']?.toString() ??
                          'Badge',
                    ),
                  );
                }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Démarrer un quiz',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'Difficulté',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Wrap(
                  spacing: 8,
                  children:
                      ['facile', 'moyen', 'difficile']
                          .map(
                            (difficulty) => ChoiceChip(
                              label: Text(
                                difficulty[0].toUpperCase() +
                                    difficulty.substring(1),
                              ),
                              selected: _difficulty == difficulty,
                              onSelected:
                                  (_) =>
                                      setState(() => _difficulty = difficulty),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 12),
                Text(
                  'Nombre de questions',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Wrap(
                  spacing: 8,
                  children:
                      [5, 10, 15]
                          .map(
                            (count) => ChoiceChip(
                              label: Text('$count'),
                              selected: _questionCount == count,
                              onSelected:
                                  (_) => setState(() => _questionCount = count),
                            ),
                          )
                          .toList(),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mode examen'),
                  subtitle: const Text(
                    'Les corrections seront affichées à la fin.',
                  ),
                  value: _examMode,
                  onChanged: (value) => setState(() => _examMode = value),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _startQuiz,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Démarrer le quiz'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Classement', style: Theme.of(context).textTheme.titleMedium),
        ...(_leaderboard ?? []).take(10).map((e) {
          final m = _asMap(e);
          return ListTile(
            leading: CircleAvatar(
              child: Text('${(_leaderboard ?? []).indexOf(e) + 1}'),
            ),
            title: Text(
              m['pseudonym']?.toString() ??
                  m['username']?.toString() ??
                  m['author_display']?.toString() ??
                  '—',
            ),
            trailing: Text('${m['score'] ?? m['best_score'] ?? ''}'),
          );
        }),
      ],
    );
  }
}
