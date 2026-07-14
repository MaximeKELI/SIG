import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/sig_api.dart';
import '../../shared/widgets/external_api_cards.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _stats;
  Map<String, Map<String, dynamic>>? _apis;
  Map<String, dynamic>? _smap;
  Map<String, dynamic>? _dbInfo;
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
        api.fetchDashboardStats(),
        api.fetchExternalApiStatus(),
        api.smapCorrelation().catchError((_) => <String, dynamic>{}),
        api.fetchSystemHealth().catchError((_) => <String, dynamic>{}),
      ]);
      final health = Map<String, dynamic>.from(results[3] as Map);
      final checks = health['checks'] as Map<String, dynamic>?;
      setState(() {
        _stats = Map<String, dynamic>.from(results[0] as Map);
        _apis = results[1] as Map<String, Map<String, dynamic>>;
        _smap = Map<String, dynamic>.from(results[2] as Map);
        _dbInfo =
            checks?['database_info'] != null
                ? Map<String, dynamic>.from(checks!['database_info'] as Map)
                : null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _rows(String key) {
    final raw = _stats?[key];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView(message: 'Tableau de bord…');
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    final fertility = _rows('fertility_distribution');
    final soilTypes =
        _rows('soil_type_distribution').isNotEmpty
            ? _rows('soil_type_distribution')
            : _rows('soil_types');

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_dbInfo != null && _dbInfo!.isNotEmpty)
            Card(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.35),
              child: ListTile(
                leading: const Icon(Icons.storage),
                title: const Text('Base de données partagée'),
                subtitle: Text(
                  '${_dbInfo!['backend'] ?? '—'} · ${_dbInfo!['name'] ?? '—'} · '
                  '${_dbInfo!['host'] ?? '—'}\n'
                  'Même source que le site web (API Django).',
                ),
                isThreeLine: true,
              ),
            ),
          Text('KPIs sols', style: Theme.of(context).textTheme.titleMedium),
          _kpiCard(
            'Points validés',
            '${_stats?['validated_points'] ?? _stats?['total_points'] ?? '—'}',
          ),
          _kpiCard('pH moyen', '${_stats?['avg_ph'] ?? '—'}'),
          _kpiCard('NDVI moyen', '${_stats?['avg_ndvi'] ?? '—'}'),
          _kpiCard(
            'Zones dégradées',
            '${_stats?['degraded_zones'] ?? _stats?['zones_degraded'] ?? '—'}',
          ),
          _kpiCard(
            'Points en attente',
            '${_stats?['pending_points'] ?? '—'}',
          ),
          if (fertility.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Fertilité (distribution)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 180, child: _barChart(fertility, 'fertility_class')),
          ],
          if (soilTypes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Types de sol',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(
              height: 180,
              child: _barChart(soilTypes, 'soil_type', altLabel: 'type'),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'APIs externes (via backend)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ExternalApiCards(
            weather: _apis?['weather'],
            sentinel: _apis?['sentinel'],
            nasa: _apis?['nasa'],
            ml: _apis?['ml'],
            assistant: _apis?['assistant'],
          ),
          if (_smap != null && _smap!.isNotEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.analytics_outlined),
                title: const Text('Corrélation SMAP'),
                subtitle: Text('R² = ${_smap!['r2'] ?? _smap!['r_squared'] ?? '—'}'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _barChart(
    List<Map<String, dynamic>> rows,
    String labelKey, {
    String? altLabel,
  }) {
    final bars = <BarChartGroupData>[];
    for (var i = 0; i < rows.length; i++) {
      final count =
          (rows[i]['count'] as num?)?.toDouble() ??
          double.tryParse('${rows[i]['count']}') ??
          0;
      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: count,
              width: 16,
              borderRadius: BorderRadius.circular(4),
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        child: BarChart(
          BarChartData(
            barGroups: bars,
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 28),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= rows.length) return const SizedBox.shrink();
                    final label =
                        '${rows[i][labelKey] ?? rows[i][altLabel] ?? '?'}';
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        label.length > 8 ? '${label.substring(0, 8)}…' : label,
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  },
                ),
              ),
              rightTitles: const AxisTitles(),
              topTitles: const AxisTitles(),
            ),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
          ),
        ),
      ),
    );
  }

  Widget _kpiCard(String label, String value) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text(value, style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}
