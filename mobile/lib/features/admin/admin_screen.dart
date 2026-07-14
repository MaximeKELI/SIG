import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_service.dart';
import '../../services/sig_api.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  Map<String, dynamic>? _dash;
  Map<String, dynamic>? _analytics;
  List<dynamic> _pending = [];
  List<dynamic> _pendingVideos = [];
  List<dynamic> _activity = [];
  List<dynamic> _comments = [];
  List<dynamic> _journal = [];
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
      final api = context.read<SigApi>();
      final results = await Future.wait([
        api.adminDashboard(),
        api.adminAnalytics(days: 30),
        api.pendingValidation(),
        api.pendingVideos(),
        api.adminActivity(),
        api.commentsModeration(),
        api.moderationJournal(),
      ]);
      setState(() {
        _dash = Map<String, dynamic>.from(results[0] as Map);
        _analytics = Map<String, dynamic>.from(results[1] as Map);
        _pending = results[2] as List<dynamic>;
        _pendingVideos = results[3] as List<dynamic>;
        _activity = results[4] as List<dynamic>;
        _comments = results[5] as List<dynamic>;
        _journal = results[6] as List<dynamic>;
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
    final user = context.watch<AuthService>().user;
    if (user == null || !user.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Administration')),
        body: const Center(child: Text('Accès réservé aux administrateurs')),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Administration'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Validation'),
              Tab(text: 'Analyses'),
              Tab(text: 'Modération'),
              Tab(text: 'Opérations'),
            ],
          ),
        ),
        body:
            _loading
                ? const LoadingView()
                : _error != null
                ? ErrorView(message: _error!, onRetry: _load)
                : TabBarView(
                  children: [
                    _validationTab(),
                    _analyticsTab(),
                    _moderationTab(),
                    _opsTab(),
                  ],
                ),
      ),
    );
  }

  Widget _validationTab() => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          'Points de sol en attente',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        _pendingList(_pending, isPoint: true, shrinkWrap: true),
        const SizedBox(height: 20),
        Text(
          'Vidéos en attente',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        _pendingList(_pendingVideos, isPoint: false, shrinkWrap: true),
      ],
    ),
  );

  Widget _analyticsTab() {
    final metrics =
        <MapEntry<String, dynamic>>[...?_dash?.entries, ...?_analytics?.entries]
            .where(
              (entry) =>
                  entry.value is num ||
                  entry.value is String ||
                  entry.value is bool,
            )
            .toList();
    final chartValues =
        metrics
            .where((entry) => entry.value is num)
            .take(6)
            .map((entry) => (entry.value as num).toDouble())
            .toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            'Indicateurs — 30 derniers jours',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                metrics
                    .take(8)
                    .map(
                      (entry) => SizedBox(
                        width: 160,
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _label(entry.key),
                                  style:
                                      Theme.of(context).textTheme.labelMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${entry.value}',
                                  style:
                                      Theme.of(context).textTheme.headlineSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
          if (chartValues.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Aperçu des indicateurs',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 220, child: _metricChart(chartValues)),
          ],
          const SizedBox(height: 20),
          Text(
            'Activité récente',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Card(
            child:
                _activity.isEmpty
                    ? const ListTile(title: Text('Aucune activité récente.'))
                    : Column(
                      children:
                          _activity.take(10).map((item) {
                            final event = Map<String, dynamic>.from(
                              item as Map,
                            );
                            return ListTile(
                              leading: const Icon(Icons.history_outlined),
                              title: Text(
                                '${event['action'] ?? event['type'] ?? event['title'] ?? 'Activité'}',
                              ),
                              subtitle: Text(
                                '${event['created_at'] ?? event['date'] ?? ''}',
                              ),
                            );
                          }).toList(),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _metricChart(List<double> values) => BarChart(
    BarChartData(
      borderData: FlBorderData(show: false),
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      barGroups: List.generate(
        values.length,
        (index) => BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: values[index],
              color: Theme.of(context).colorScheme.primary,
              width: 18,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _moderationTab() => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          'Commentaires à examiner',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Card(
          child:
              _comments.isEmpty
                  ? const ListTile(title: Text('Aucun commentaire à modérer.'))
                  : Column(
                    children:
                        _comments.take(20).map((item) {
                          final comment = Map<String, dynamic>.from(
                            item as Map,
                          );
                          final id = comment['id'] as int?;
                          return ListTile(
                            title: Text(
                              '${comment['text'] ?? comment['body'] ?? 'Commentaire'}',
                            ),
                            subtitle: Text(
                              '${comment['author_username'] ?? comment['author'] ?? ''}',
                            ),
                            trailing:
                                id == null
                                    ? null
                                    : Wrap(
                                      children: [
                                        IconButton(
                                          tooltip: 'Analyser par IA',
                                          icon: const Icon(
                                            Icons.auto_awesome_outlined,
                                          ),
                                          onPressed: () => _checkComment(id),
                                        ),
                                        IconButton(
                                          tooltip: 'Masquer',
                                          icon: const Icon(
                                            Icons.visibility_off_outlined,
                                          ),
                                          onPressed: () => _hideComment(id),
                                        ),
                                      ],
                                    ),
                          );
                        }).toList(),
                  ),
        ),
        const SizedBox(height: 20),
        Text(
          'Journal de modération',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Card(
          child:
              _journal.isEmpty
                  ? const ListTile(title: Text('Aucune action enregistrée.'))
                  : Column(
                    children:
                        _journal.take(15).map((item) {
                          final entry = Map<String, dynamic>.from(item as Map);
                          return ListTile(
                            leading: const Icon(Icons.fact_check_outlined),
                            title: Text(
                              '${entry['action'] ?? entry['message'] ?? 'Action de modération'}',
                            ),
                            subtitle: Text(
                              '${entry['created_at'] ?? entry['date'] ?? ''}',
                            ),
                          );
                        }).toList(),
                  ),
        ),
      ],
    ),
  );

  Widget _opsTab() => ListView(
    padding: const EdgeInsets.all(12),
    children: [
      Text(
        'Opérations système',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.model_training_outlined),
              title: const Text('Réentraîner le modèle ML'),
              onTap:
                  () => _runOperation(
                    'Réentraînement ML',
                    () => context.read<SigApi>().trainMl(),
                  ),
            ),
            ListTile(
              leading: const Icon(Icons.satellite_alt_outlined),
              title: const Text('Lancer l’ingestion NASA'),
              onTap:
                  () => _runOperation(
                    'Ingestion NASA',
                    () => context.read<SigApi>().nasaIngest(),
                  ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Text(
        'Données et rapports',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Exporter les utilisateurs (CSV)'),
              onTap:
                  () => _exportCsv(
                    'utilisateurs',
                    () => context.read<SigApi>().adminExportUsers(),
                  ),
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Exporter l’activité (CSV)'),
              onTap:
                  () => _exportCsv(
                    'activité',
                    () => context.read<SigApi>().adminExportActivity(),
                  ),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Importer les utilisateurs (CSV)'),
              onTap: _importUsers,
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new_outlined),
              title: const Text('Ouvrir le rapport ministère'),
              onTap: _openMinistryReport,
            ),
          ],
        ),
      ),
    ],
  );

  Future<void> _runOperation(
    String label,
    Future<dynamic> Function() operation,
  ) async {
    try {
      await operation();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$label lancé.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _exportCsv(String label, Future<String> Function() fetch) async {
    try {
      final text = await fetch();
      await Share.share(text, subject: 'SIG Sols Togo — export $label');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export $label prêt (${text.length} caractères).'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _importUsers() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    final path = result?.files.single.path;
    if (path == null) {
      return;
    }
    await _runOperation(
      'Import des utilisateurs',
      () => context.read<SigApi>().importUsersCsv(path),
    );
  }

  Future<void> _openMinistryReport() async {
    final url = Uri.parse(context.read<SigApi>().ministryReportUrl());
    if (!await launchUrl(url, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir le rapport.')),
      );
    }
  }

  Future<void> _hideComment(int id) async {
    await _runOperation(
      'Commentaire masqué',
      () => context.read<SigApi>().hideComment(id),
    );
    await _load();
  }

  Future<void> _checkComment(int id) async {
    try {
      final result = await context.read<SigApi>().aiCheckComment(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Analyse IA : ${result['decision'] ?? result['status'] ?? 'terminée'}',
            ),
          ),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Widget _pendingList(
    List<dynamic> items, {
    required bool isPoint,
    bool shrinkWrap = false,
  }) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('Rien en attente')),
      );
    }
    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = Map<String, dynamic>.from(items[i] as Map);
        final id = item['id'] as int;
        return ListTile(
          title: Text(
            isPoint ? 'Point #$id' : item['title']?.toString() ?? 'Vidéo #$id',
          ),
          subtitle: Text(
            item['soil_type']?.toString() ??
                item['author_username']?.toString() ??
                '',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.check, color: Colors.green),
                tooltip: 'Valider',
                onPressed: () async {
                  final api = context.read<SigApi>();
                  if (isPoint) {
                    await api.validatePoint(id);
                  } else {
                    await api.approveVideo(id);
                  }
                  _load();
                },
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                tooltip: 'Rejeter',
                onPressed: () async {
                  final api = context.read<SigApi>();
                  if (isPoint) {
                    await api.validatePoint(id, action: 'reject');
                  } else {
                    await api.rejectVideo(id);
                  }
                  _load();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _label(String key) => key.replaceAll('_', ' ');
}
