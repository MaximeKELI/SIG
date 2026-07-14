import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/sig_api.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';

/// Équivalent web : #view-my-dashboard /platform/me/dashboard/
class MyDashboardScreen extends StatefulWidget {
  const MyDashboardScreen({super.key});

  @override
  State<MyDashboardScreen> createState() => _MyDashboardScreenState();
}

class _MyDashboardScreenState extends State<MyDashboardScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
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
      final data = await context.read<SigApi>().personalDashboard();
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Map<String, dynamic> _map(String key) {
    final raw = _data?[key];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    final quiz = _map('quiz');
    final videos = _map('videos');
    final social = _map('social');
    final badges = quiz['badges'] is List ? quiz['badges'] as List : const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon espace'),
        leading: IconButton(
          tooltip: 'Retour',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body:
          _loading
              ? const LoadingView()
              : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Bienvenue, ${_data?['display_name'] ?? _data?['username'] ?? ''}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    _summaryCard(
                      icon: Icons.agriculture,
                      label: 'Points sol',
                      value: '${_data?['soil_points_submitted'] ?? 0}',
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    _summaryCard(
                      icon: Icons.video_library_outlined,
                      label: 'Vidéos publiées',
                      value: '${videos['published'] ?? 0}',
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    _summaryCard(
                      icon: Icons.quiz_outlined,
                      label: 'Quiz terminés',
                      value: '${quiz['sessions_completed'] ?? 0}',
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                    _summaryCard(
                      icon: Icons.emoji_events_outlined,
                      label: 'Meilleur score',
                      value: '${quiz['best_score'] ?? 0}',
                      color: Colors.amber.shade800,
                    ),
                    _summaryCard(
                      icon: Icons.people_outline,
                      label: 'Abonnés',
                      value: '${social['followers'] ?? 0}',
                      color: Colors.teal,
                    ),
                    _summaryCard(
                      icon: Icons.person_add_alt_1_outlined,
                      label: 'Abonnements',
                      value: '${social['following'] ?? 0}',
                      color: Colors.indigo,
                    ),
                    const SizedBox(height: 16),
                    Text('Badges', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (badges.isEmpty)
                      const Card(
                        child: ListTile(
                          leading: Icon(Icons.workspace_premium_outlined),
                          title: Text('Aucun badge pour le moment'),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            badges
                                .map(
                                  (b) => Chip(
                                    avatar: const Icon(
                                      Icons.workspace_premium,
                                      size: 16,
                                    ),
                                    label: Text('$b'),
                                  ),
                                )
                                .toList(),
                      ),
                  ],
                ),
              ),
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          foregroundColor: color,
          child: Icon(icon),
        ),
        title: Text(label),
        trailing: Text(value, style: Theme.of(context).textTheme.headlineSmall),
      ),
    );
  }
}
