import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_service.dart';
import '../../services/sig_api.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Map<String, dynamic>? _dash;
  List<dynamic> _pending = [];
  List<dynamic> _pendingVideos = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
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
        api.pendingValidation(),
        api.pendingVideos(),
      ]);
      setState(() {
        _dash = Map<String, dynamic>.from(results[0] as Map);
        _pending = results[1] as List<dynamic>;
        _pendingVideos = results[2] as List<dynamic>;
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administration'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'KPIs'),
            Tab(text: 'Points'),
            Tab(text: 'Vidéos'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              final api = context.read<SigApi>();
              try {
                if (v == 'ml') await api.trainMl();
                if (v == 'nasa') await api.nasaIngest();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$v lancé')));
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'ml', child: Text('Réentraîner ML')),
              PopupMenuItem(value: 'nasa', child: Text('Ingestion NASA')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : TabBarView(
                  controller: _tabs,
                  children: [
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        ...?_dash?.entries.map(
                          (e) => ListTile(
                            title: Text(e.key),
                            trailing: Text('${e.value}'),
                          ),
                        ),
                        const Divider(),
                        const ListTile(title: Text('Exports CSV')),
                        ListTile(
                          leading: const Icon(Icons.download),
                          title: const Text('Utilisateurs'),
                          onTap: () => _exportCsv(context, 'utilisateurs', () => context.read<SigApi>().adminExportUsers()),
                        ),
                        ListTile(
                          leading: const Icon(Icons.download),
                          title: const Text('Activité (30 j.)'),
                          onTap: () => _exportCsv(context, 'activité', () => context.read<SigApi>().adminExportActivity()),
                        ),
                      ],
                    ),
                    _pendingList(_pending, isPoint: true),
                    _pendingList(_pendingVideos, isPoint: false),
                  ],
                ),
    );
  }

  Future<void> _exportCsv(
    BuildContext context,
    String label,
    Future<String> Function() fetch,
  ) async {
    try {
      final text = await fetch();
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Export $label'),
          content: SizedBox(
            width: double.maxFinite,
            height: 200,
            child: SingleChildScrollView(child: SelectableText(text)),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: text));
                Navigator.pop(context);
              },
              child: const Text('Copier'),
            ),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Widget _pendingList(List<dynamic> items, {required bool isPoint}) {
    if (items.isEmpty) return const Center(child: Text('Rien en attente'));
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = Map<String, dynamic>.from(items[i] as Map);
        final id = item['id'] as int;
        return ListTile(
          title: Text(isPoint ? 'Point #$id' : item['title']?.toString() ?? 'Vidéo #$id'),
          subtitle: Text(item['soil_type']?.toString() ?? item['author_username']?.toString() ?? ''),
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
