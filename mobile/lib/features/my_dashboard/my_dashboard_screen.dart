import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon espace')),
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
                      icon: Icons.quiz_outlined,
                      label: 'Score quiz',
                      value: _value([
                        'quiz_score',
                        'quiz_average',
                        'quiz_stats.score',
                        'quiz.score',
                      ], fallback: 'Aucun quiz'),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    _summaryCard(
                      icon: Icons.add_location_alt_outlined,
                      label: 'Points créés',
                      value: _value([
                        'points_created',
                        'points_count',
                        'soil_points_count',
                        'stats.points_created',
                      ], fallback: '0'),
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    _summaryCard(
                      icon: Icons.bookmark_outline,
                      label: 'Favoris',
                      value: _value([
                        'favorites_count',
                        'favorites',
                        'stats.favorites_count',
                      ], fallback: '0'),
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Activité récente',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _recentActivity(),
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

  Widget _recentActivity() {
    final raw =
        _data?['recent_activity'] ??
        _data?['activity'] ??
        _data?['recent_events'];
    final activities = raw is List ? raw : const <dynamic>[];
    if (activities.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.history),
          title: Text('Aucune activité récente'),
          subtitle: Text('Vos prochaines actions apparaîtront ici.'),
        ),
      );
    }
    return Card(
      child: Column(
        children:
            activities.take(5).map((entry) {
              final event =
                  entry is Map
                      ? Map<String, dynamic>.from(entry)
                      : <String, dynamic>{};
              final title =
                  event['title'] ??
                  event['action'] ??
                  event['type'] ??
                  'Activité';
              final date = event['created_at'] ?? event['date'] ?? '';
              return ListTile(
                leading: const Icon(Icons.history),
                title: Text('$title'),
                subtitle: date.toString().isEmpty ? null : Text('$date'),
              );
            }).toList(),
      ),
    );
  }

  String _value(List<String> keys, {required String fallback}) {
    for (final key in keys) {
      dynamic value = _data;
      for (final part in key.split('.')) {
        if (value is Map) {
          value = value[part];
        } else {
          value = null;
          break;
        }
      }
      if (value != null && value is! Map && value is! List) return '$value';
    }
    return fallback;
  }
}
