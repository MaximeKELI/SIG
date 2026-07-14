import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_service.dart';
import '../../core/config/env.dart';
import '../../core/theme/app_theme.dart';
import '../../services/sig_api.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';

/// Cockpit admin — vision globale alignée sur le web (`/platform/admin/cockpit/`).
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  Map<String, dynamic>? _cockpit;
  List<dynamic> _journal = [];
  List<dynamic> _usersList = [];
  Map<String, dynamic>? _userActivity;
  Map<String, dynamic>? _health;
  final _userActivityCtrl = TextEditingController();
  final _zoneCodeCtrl = TextEditingController();
  final _usersSearchCtrl = TextEditingController();
  bool _loading = true;
  bool _usersLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _userActivityCtrl.dispose();
    _zoneCodeCtrl.dispose();
    _usersSearchCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _overview =>
      Map<String, dynamic>.from(_cockpit?['overview'] as Map? ?? {});

  Map<String, dynamic> get _soilStats =>
      Map<String, dynamic>.from(_cockpit?['soil_stats'] as Map? ?? {});

  Map<String, dynamic> get _queues =>
      Map<String, dynamic>.from(_cockpit?['queues'] as Map? ?? {});

  Map<String, dynamic> get _usersBlock =>
      Map<String, dynamic>.from(_cockpit?['users'] as Map? ?? {});

  Map<String, dynamic> get _analytics =>
      Map<String, dynamic>.from(_cockpit?['analytics'] as Map? ?? {});

  Map<String, dynamic> get _terrain =>
      Map<String, dynamic>.from(_cockpit?['terrain'] as Map? ?? {});

  List<dynamic> get _audit => _cockpit?['audit'] as List? ?? const [];

  List<dynamic> get _activity =>
      _cockpit?['activity_recent'] as List? ?? const [];

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<SigApi>();
      final results = await Future.wait([
        api.adminCockpit(days: 30),
        api.moderationJournal(),
      ]);
      if (!mounted) return;
      setState(() {
        _cockpit = Map<String, dynamic>.from(results[0] as Map);
        _journal = results[1] as List<dynamic>;
        _loading = false;
      });
      unawaited(_loadUsersList());
      unawaited(_loadHealth());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadUsersList() async {
    setState(() => _usersLoading = true);
    try {
      final q = _usersSearchCtrl.text.trim();
      final api = context.read<SigApi>();
      final list =
          q.isEmpty
              ? await api.listUsers()
              : await api.searchUsers(q);
      if (!mounted) return;
      setState(() {
        _usersList = list;
        _usersLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _usersLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _loadHealth() async {
    try {
      final data = await context.read<SigApi>().fetchSystemHealth();
      if (mounted) setState(() => _health = data);
    } catch (_) {
      if (mounted) setState(() => _health = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    if (user == null || !user.isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Administration'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          ),
        ),
        body: const Center(child: Text('Accès réservé aux administrateurs')),
      );
    }

    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cockpit admin'),
          leading: IconButton(
            tooltip: 'Retour',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          ),
          actions: [
            IconButton(
              tooltip: 'Actualiser',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Vue'),
              Tab(text: 'Validation'),
              Tab(text: 'Modération'),
              Tab(text: 'Users'),
              Tab(text: 'Stats'),
              Tab(text: 'Terrain'),
              Tab(text: 'Ops'),
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
                    _overviewTab(),
                    _validationTab(),
                    _moderationTab(),
                    _usersTab(),
                    _statsTab(),
                    _terrainTab(),
                    _opsTab(),
                  ],
                ),
      ),
    );
  }

  Widget _kpi(String label, Object? value) {
    return SizedBox(
      width: 152,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 6),
              Text(
                '${value ?? '—'}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.gold300,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _overviewTab() {
    final o = _overview;
    final soil = _soilStats;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            'Vue d’ensemble (web + mobile)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _kpi('Utilisateurs', o['users_total']),
              _kpi('Actifs', o['users_active']),
              _kpi('Points sol', o['soil_points']),
              _kpi('En attente sol', o['pending_validation']),
              _kpi('Vidéos publiées', o['videos_published']),
              _kpi('Quiz 30 j.', o['quizzes_completed_period']),
              _kpi('Agents live', o['live_agents']),
              _kpi('Alertes', o['active_alerts']),
              _kpi('Événements 30 j.', o['events_total']),
              _kpi('Aujourd’hui', o['events_today']),
            ],
          ),
          const SizedBox(height: 16),
          Text('Sols validés', style: Theme.of(context).textTheme.titleMedium),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Points validés'),
                  trailing: Text('${soil['total_points'] ?? '—'}'),
                ),
                ListTile(
                  title: const Text('pH moyen'),
                  trailing: Text('${soil['avg_ph'] ?? '—'}'),
                ),
                ListTile(
                  title: const Text('Humidité moy.'),
                  trailing: Text('${soil['avg_humidity'] ?? '—'} %'),
                ),
                ListTile(
                  title: const Text('NDVI moy.'),
                  trailing: Text('${soil['avg_ndvi'] ?? '—'}'),
                ),
                ListTile(
                  title: const Text('Zones dégradées'),
                  trailing: Text('${soil['degraded_zones_count'] ?? '—'}'),
                ),
              ],
            ),
          ),
          if (o['ml_model'] is Map) ...[
            const SizedBox(height: 12),
            Text('Modèle IA', style: Theme.of(context).textTheme.titleMedium),
            Card(
              child: ListTile(
                leading: const Icon(Icons.psychology_outlined),
                title: Text('${(o['ml_model'] as Map)['algorithm'] ?? '—'}'),
                subtitle: Text(
                  'F1 ${(o['ml_model'] as Map)['f1_macro'] ?? '—'} · '
                  '${_shortDate((o['ml_model'] as Map)['trained_at'])}',
                ),
              ),
            ),
          ],
        ],
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
        _pendingList(
          _queues['pending_soils'] as List? ?? const [],
          isPoint: true,
          shrinkWrap: true,
        ),
        const SizedBox(height: 20),
        Text(
          'Vidéos en attente',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        _pendingList(
          _queues['pending_videos'] as List? ?? const [],
          isPoint: false,
          shrinkWrap: true,
        ),
      ],
    ),
  );

  Widget _moderationTab() {
    final comments = _queues['comments'] as List? ?? const [];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            'Commentaires récents',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Card(
            child:
                comments.isEmpty
                    ? const ListTile(title: Text('Aucun commentaire.'))
                    : Column(
                      children:
                          comments.take(25).map((item) {
                            final comment = Map<String, dynamic>.from(
                              item as Map,
                            );
                            final id = comment['id'] as int?;
                            return ListTile(
                              title: Text(
                                '${comment['text'] ?? 'Commentaire'}',
                              ),
                              subtitle: Text(
                                '${comment['author_display'] ?? comment['author_username'] ?? ''}',
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
                    ? const ListTile(title: Text('Journal vide.'))
                    : Column(
                      children:
                          _journal.take(20).map((item) {
                            final entry = Map<String, dynamic>.from(
                              item as Map,
                            );
                            return ListTile(
                              leading: const Icon(Icons.fact_check_outlined),
                              title: Text(
                                '[${entry['kind'] ?? '?'}] ${entry['title'] ?? entry['text'] ?? 'Action'}',
                              ),
                              subtitle: Text(
                                '${entry['author'] ?? ''} · ${entry['created_at'] ?? ''}',
                              ),
                            );
                          }).toList(),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _usersTab() {
    final byRole = _usersBlock['by_role'] as List? ?? const [];
    final rows =
        _usersList.isNotEmpty
            ? _usersList
            : (_usersBlock['recent'] as List? ?? const []);
    return RefreshIndicator(
      onRefresh: () async {
        await _loadUsersList();
      },
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            'Répartition par rôle',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                byRole.map((raw) {
                  final row = Map<String, dynamic>.from(raw as Map);
                  return Chip(
                    label: Text('${row['role']} · ${row['count']}'),
                  );
                }).toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _usersSearchCtrl,
            decoration: InputDecoration(
              labelText: 'Recherche utilisateur',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: _loadUsersList,
              ),
            ),
            onSubmitted: (_) => _loadUsersList(),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _usersLoading ? null : _loadUsersList,
              child: Text(_usersLoading ? 'Chargement…' : 'Actualiser la liste'),
            ),
          ),
          Text(
            'Utilisateurs (${rows.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Card(
            child: Column(
              children:
                  rows.take(50).map((raw) {
                    final u = Map<String, dynamic>.from(raw as Map);
                    final id = u['id'] is int
                        ? u['id'] as int
                        : int.tryParse('${u['id']}');
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          (u['username']?.toString() ?? '?')[0].toUpperCase(),
                        ),
                      ),
                      title: Text('${u['username']}'),
                      subtitle: Text(
                        '${u['role']} · ${u['region'] ?? '—'} · ${_shortDate(u['date_joined'], len: 10)}',
                      ),
                      trailing: id == null
                          ? Text('#${u['id']}')
                          : TextButton(
                            onPressed: () {
                              _userActivityCtrl.text = '$id';
                              DefaultTabController.of(context).animateTo(4);
                              _loadUserActivity();
                            },
                            child: const Text('Activité'),
                          ),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsTab() {
    final an = _analytics;
    final byDay = an['by_day'] as List? ?? const [];
    final chartValues =
        byDay
            .map((e) => ((e as Map)['count'] as num?)?.toDouble() ?? 0)
            .toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            'Statistiques 30 j. (web + mobile)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _kpi('Événements', an['events_total']),
              _kpi('Aujourd’hui', an['events_today']),
              _kpi('Zooms', an['map_zoom_total']),
              _kpi('Pans', an['map_pan_total']),
            ],
          ),
          if (chartValues.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Événements / jour',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 220, child: _metricChart(chartValues)),
          ],
          const SizedBox(height: 16),
          Text(
            'Activité récente',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Card(
            child: Column(
              children:
                  _activity.take(15).map((item) {
                    final e = Map<String, dynamic>.from(item as Map);
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.history),
                      title: Text(
                        '${e['event_type'] ?? e['action'] ?? 'event'}',
                      ),
                      subtitle: Text(
                        '${e['username'] ?? ''} · ${e['created_at'] ?? ''}',
                      ),
                    );
                  }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Activité par utilisateur',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    controller: _userActivityCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'ID utilisateur',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: _loadUserActivity,
                      child: const Text('Charger'),
                    ),
                  ),
                  if (_userActivity != null) ...[
                    const Divider(),
                    Text(
                      '${_userActivity!['events_total'] ?? 0} événements',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _terrainTab() {
    final agents = _terrain['live_agents'] as List? ?? const [];
    final alerts = _terrain['drought_alerts'] as List? ?? const [];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            'Agents live (5 min)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Card(
            child:
                agents.isEmpty
                    ? const ListTile(title: Text('Aucun agent live.'))
                    : Column(
                      children:
                          agents.map((raw) {
                            final a = Map<String, dynamic>.from(raw as Map);
                            return ListTile(
                              leading: const Icon(Icons.person_pin_circle),
                              title: Text(
                                '${a['display_name'] ?? a['username']}',
                              ),
                              subtitle: Text(
                                '${a['role']} · ${a['lat']} , ${a['lon']}',
                              ),
                            );
                          }).toList(),
                    ),
          ),
          const SizedBox(height: 16),
          Text(
            'Alertes sécheresse',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Card(
            child:
                alerts.isEmpty
                    ? const ListTile(title: Text('Aucune alerte active.'))
                    : Column(
                      children:
                          alerts.map((raw) {
                            final a = Map<String, dynamic>.from(raw as Map);
                            return ListTile(
                              leading: const Icon(
                                Icons.warning_amber_outlined,
                                color: Colors.orange,
                              ),
                              title: Text(
                                '${a['title'] ?? a['level'] ?? 'Alerte'}',
                              ),
                              subtitle: Text(
                                '${a['message'] ?? a['zone_name'] ?? ''}',
                              ),
                            );
                          }).toList(),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _opsTab() => ListView(
    padding: const EdgeInsets.all(12),
    children: [
      Text('Santé système', style: Theme.of(context).textTheme.titleMedium),
      Card(
        child: ListTile(
          leading: Icon(
            _health == null
                ? Icons.monitor_heart_outlined
                : Icons.favorite,
            color: _health != null ? Colors.greenAccent : null,
          ),
          title: Text(
            _health == null
                ? 'Indisponible'
                : 'Statut ${_health!['status'] ?? 'ok'}',
          ),
          subtitle: Text(
            _health == null
                ? Env.healthUrl
                : (_health!['checks'] is Map
                    ? (_health!['checks'] as Map).entries
                        .take(4)
                        .map((e) => '${e.key}: ${e.value}')
                        .join(' · ')
                    : Env.healthUrl),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHealth,
          ),
          onTap: () => launchUrl(
            Uri.parse(Env.healthUrl),
            mode: LaunchMode.externalApplication,
          ),
        ),
      ),
      const SizedBox(height: 16),
      Text('Journal d’audit', style: Theme.of(context).textTheme.titleMedium),
      Card(
        child: Column(
          children:
              _audit.take(25).map((raw) {
                final a = Map<String, dynamic>.from(raw as Map);
                return ListTile(
                  dense: true,
                  title: Text('${a['action']} ${a['resource']}'),
                  subtitle: Text(
                    '${a['username'] ?? '?'} · ${a['created_at'] ?? ''}',
                  ),
                );
              }).toList(),
        ),
      ),
      const SizedBox(height: 16),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                controller: _zoneCodeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Code zone (rapport)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('Rapport zone'),
              onTap: _exportZoneReport,
            ),
          ],
        ),
      ),
    ],
  );

  Future<void> _loadUserActivity() async {
    final id = int.tryParse(_userActivityCtrl.text.trim());
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID utilisateur invalide.')),
      );
      return;
    }
    try {
      final data = await context.read<SigApi>().adminUserActivity(id);
      if (mounted) setState(() => _userActivity = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
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
              width: 14,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _exportZoneReport() async {
    final code = _zoneCodeCtrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saisissez un code zone.')),
      );
      return;
    }
    await _exportCsv(
      'zone $code',
      () => context.read<SigApi>().downloadZoneReport(code),
    );
  }

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
      await _load();
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
    if (path == null) return;
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
  }

  Future<void> _checkComment(int id) async {
    try {
      final result = await context.read<SigApi>().aiCheckComment(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Analyse IA : ${result['suggested_hide'] == true ? 'à masquer' : 'ok'} · flags ${result['flags'] ?? []}',
            ),
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

  String _shortDate(Object? value, {int len = 16}) {
    final s = '${value ?? ''}';
    if (s.isEmpty) return '—';
    return s.substring(0, s.length < len ? s.length : len);
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
}
