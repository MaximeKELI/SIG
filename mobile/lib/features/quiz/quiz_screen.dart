import 'dart:async';
import 'dart:io' show File, Platform, Process;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../services/sig_api.dart';
import '../../shared/widgets/dusol_ui.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';

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
  int _timerSeconds = 20;
  int _timeLeft = 20;
  Timer? _questionTimer;

  /// Désactive le Timer.periodic sous tests (sinon pumpAndSettle bloque).
  bool get _timersEnabled => !Platform.environment.containsKey('FLUTTER_TEST');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  void _stopTimer() {
    _questionTimer?.cancel();
    _questionTimer = null;
  }

  void _startQuestionTimer() {
    _stopTimer();
    if (!_timersEnabled || _sessionId == null) return;
    setState(() => _timeLeft = _timerSeconds);
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_timeLeft <= 1) {
        timer.cancel();
        setState(() => _timeLeft = 0);
        // Timeout = mauvaise réponse (index invalide forcé hors des choix)
        unawaited(_answer(-1, fromTimeout: true));
        return;
      }
      setState(() => _timeLeft -= 1);
    });
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
    _stopTimer();
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
      final timer =
          data['timer_seconds'] is int
              ? data['timer_seconds'] as int
              : (_examMode ? 120 : 20);
      setState(() {
        _sessionId = data['session_id'] as int?;
        _questions = data['questions'] as List? ?? [];
        _qIndex = 0;
        _timerSeconds = timer;
        _timeLeft = timer;
        _examMode = data['exam_mode'] == true ? true : _examMode;
        _loading = false;
      });
      _startQuestionTimer();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _answer(int selectedIndex, {bool fromTimeout = false}) async {
    if (_submitting ||
        _answerSubmitted ||
        _sessionId == null ||
        _qIndex >= _questions.length) {
      return;
    }
    _stopTimer();
    final q = _questions[_qIndex] as Map<String, dynamic>;
    final choices = q['choices'] as List? ?? [];
    final index =
        fromTimeout
            ? (choices.isEmpty ? 0 : (choices.length - 1).clamp(0, 3))
            : selectedIndex.clamp(0, 3);
    setState(() => _submitting = true);
    try {
      final r = await context.read<SigApi>().submitQuizAnswer(
        _sessionId!,
        questionId: q['id'] as int,
        selectedIndex: index,
      );
      setState(() {
        _score = r['session_score'] as int? ?? _score;
        _feedback =
            _examMode
                ? ''
                : fromTimeout
                ? 'Temps écoulé. ${r['explanation'] ?? ''}'
                : r['correct'] == true
                ? 'Bonne réponse ! +${r['points_earned'] ?? 0} point(s)'
                : 'Réponse incorrecte. ${r['explanation'] ?? ''}';
        _submitting = false;
        _answerSubmitted = !_examMode;
      });
      if (_examMode || fromTimeout) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await _nextQuestion();
      }
    } catch (e) {
      setState(() {
        _feedback = 'Erreur : $e';
        _submitting = false;
      });
      if (!fromTimeout) _startQuestionTimer();
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
      _timeLeft = _timerSeconds;
    });
    _startQuestionTimer();
  }

  Future<void> _finish() async {
    _stopTimer();
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
    _stopTimer();
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
    try {
      final api = context.read<SigApi>();
      final bytes = await api.downloadQuizCertificate(_sessionId!);
      if (!mounted) return;
      if (bytes.length < 100 ||
          !(bytes.length >= 4 &&
              bytes[0] == 0x25 &&
              bytes[1] == 0x50 &&
              bytes[2] == 0x44 &&
              bytes[3] == 0x46)) {
        throw Exception('Réponse serveur invalide (PDF attendu).');
      }
      await _deliverCertificatePdf(Uint8List.fromList(bytes));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Certificat indisponible : $e')),
        );
      }
    }
  }

  /// Sur Linux, share_plus ne gère pas les fichiers — on enregistre + ouvre.
  Future<void> _deliverCertificatePdf(Uint8List bytes) async {
    final fileName = 'certificat-SIG-Sols-$_sessionId.pdf';

    if (Platform.isAndroid || Platform.isIOS) {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf', name: fileName)],
        text: 'Certificat d’excellence — SIG Sols Togo',
        subject: 'Certificat SIG Sols Togo',
      );
      return;
    }

    // Desktop (Linux / Windows / macOS) : dialogue d’enregistrement, puis ouverture.
    String? savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Enregistrer le certificat PDF',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      bytes: bytes,
    );

    if (savedPath == null || savedPath.isEmpty) {
      // Annulé : fallback Documents
      final docs = await getApplicationDocumentsDirectory();
      savedPath = '${docs.path}/$fileName';
      await File(savedPath).writeAsBytes(bytes, flush: true);
    } else {
      if (!savedPath.toLowerCase().endsWith('.pdf')) {
        savedPath = '$savedPath.pdf';
      }
      // Certains backends écrivent déjà via `bytes` ; on force une écriture sûre.
      await File(savedPath).writeAsBytes(bytes, flush: true);
    }

    final opened = await _openPdfExternally(savedPath);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          opened
              ? 'Certificat ouvert · enregistré : $savedPath'
              : 'Certificat enregistré : $savedPath',
        ),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Ouvrir',
          onPressed: () => _openPdfExternally(savedPath!),
        ),
      ),
    );
  }

  Future<bool> _openPdfExternally(String path) async {
    try {
      final uri = Uri.file(path);
      if (await canLaunchUrl(uri)) {
        return launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    try {
      if (Platform.isLinux) {
        final r = await Process.run('xdg-open', [path]);
        return r.exitCode == 0;
      }
      if (Platform.isMacOS) {
        final r = await Process.run('open', [path]);
        return r.exitCode == 0;
      }
      if (Platform.isWindows) {
        final r = await Process.run('cmd', ['/c', 'start', '', path]);
        return r.exitCode == 0;
      }
    } catch (_) {}
    return false;
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
      final canCertify = _sessionId != null && (score as num) >= 10;
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          DusolHeroHeader(
            title: 'Bravo !',
            subtitle: 'Quiz terminé · score $score points',
          ),
          const DusolSectionTitle('Badges obtenus'),
          ...((_finishResult!['badges_earned'] as List? ?? const []).map(
            (badge) => Chip(
              avatar: const Icon(
                Icons.workspace_premium,
                size: 18,
                color: AppTheme.gold500,
              ),
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
          if (canCertify)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: AppRadius.card,
                gradient: AppTheme.heroGradient,
                border: Border.all(
                  color: AppTheme.gold500.withValues(alpha: 0.45),
                ),
                boxShadow: AppTheme.softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Certificat d’excellence',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppTheme.gold300,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    Platform.isLinux || Platform.isWindows || Platform.isMacOS
                        ? 'Enregistrement PDF puis ouverture dans votre lecteur.'
                        : 'Téléchargez et partagez votre diplôme officiel.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _openCertificate,
                    icon: const Icon(Icons.workspace_premium),
                    label: Text(
                      Platform.isAndroid || Platform.isIOS
                          ? 'Obtenir le certificat'
                          : 'Télécharger & ouvrir le PDF',
                    ),
                  ),
                ],
              ),
            )
          else
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Certificat non disponible'),
                subtitle: Text(
                  'Score minimum requis : 10 pts (actuel : $score).',
                ),
              ),
            ),
          const SizedBox(height: 12),
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Question ${_qIndex + 1}/${_questions.length} · Score : $_score',
                    ),
                  ),
                  Chip(
                    avatar: Icon(
                      Icons.timer_outlined,
                      size: 18,
                      color: _timeLeft <= 5 ? Colors.redAccent : null,
                    ),
                    label: Text(
                      '${_timeLeft}s',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _timeLeft <= 5 ? Colors.redAccent : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppTheme.gold500.withValues(alpha: 0.15),
                  color: AppTheme.gold500,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _timerSeconds <= 0 ? 0 : _timeLeft / _timerSeconds,
                  minHeight: 4,
                  color: _timeLeft <= 5
                      ? Colors.redAccent
                      : AppTheme.emerald400,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                q['text']?.toString() ?? '',
                style: Theme.of(context).textTheme.headlineSmall,
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        DusolHeroHeader(
          title: 'Quiz sols',
          subtitle: 'Apprenez · pratiquez · certifiez',
        ).dusolEnter(),
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
        ).dusolEnter(index: 1),
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
