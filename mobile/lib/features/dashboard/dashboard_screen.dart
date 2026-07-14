import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../services/sig_api.dart';
import '../../shared/widgets/dusol_ui.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/external_api_cards.dart';
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

    final kpis = [
      (
        'Points validés',
        '${_stats?['validated_points'] ?? _stats?['total_points'] ?? '—'}',
        Icons.place_outlined,
      ),
      (
        'pH moyen',
        '${_stats?['avg_ph'] ?? '—'}',
        Icons.science_outlined,
      ),
      (
        'NDVI moyen',
        '${_stats?['avg_ndvi'] ?? '—'}',
        Icons.grass_outlined,
      ),
      (
        'Zones dégradées',
        '${_stats?['degraded_zones'] ?? _stats?['zones_degraded'] ?? '—'}',
        Icons.warning_amber_outlined,
      ),
    ];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          DusolHeroHeader(
            title: 'Tableau de bord',
            subtitle: 'Indicateurs sols · région Maritime',
            trailing: IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh, color: AppTheme.gold300),
            ),
          ).dusolEnter(),
          if (_dbInfo != null && _dbInfo!.isNotEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.storage_outlined),
                title: const Text('Source de données'),
                subtitle: Text(
                  '${_dbInfo!['backend'] ?? '—'} · même API que le web',
                ),
              ),
            ).dusolEnter(index: 1),
          const DusolSectionTitle('Indicateurs clés'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              for (var i = 0; i < kpis.length; i++)
                DusolKpiTile(
                  label: kpis[i].$1,
                  value: kpis[i].$2,
                  icon: kpis[i].$3,
                ).dusolEnter(index: i + 2),
            ],
          ),
          DusolKpiTile(
            label: 'Points en attente',
            value: '${_stats?['pending_points'] ?? '—'}',
            icon: Icons.hourglass_empty,
          ).dusolEnter(index: 6),
          if (fertility.isNotEmpty) ...[
            const DusolSectionTitle('Fertilité'),
            SizedBox(
              height: 200,
              child: _barChart(fertility, 'fertility_class'),
            ).dusolEnter(index: 7),
          ],
          if (soilTypes.isNotEmpty) ...[
            const DusolSectionTitle('Types de sol'),
            SizedBox(
              height: 200,
              child: _barChart(soilTypes, 'soil_type', altLabel: 'type'),
            ).dusolEnter(index: 8),
          ],
          const DusolSectionTitle('Services connectés'),
          ExternalApiCards(
            weather: _apis?['weather'],
            sentinel: _apis?['sentinel'],
            nasa: _apis?['nasa'],
            ml: _apis?['ml'],
            assistant: _apis?['assistant'],
          ).dusolEnter(index: 9),
          if (_smap != null && _smap!.isNotEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.analytics_outlined),
                title: const Text('Corrélation SMAP'),
                subtitle: Text(
                  'R² = ${_smap!['r2'] ?? _smap!['r_squared'] ?? '—'}',
                ),
              ),
            ).dusolEnter(index: 10),
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
              borderRadius: BorderRadius.circular(6),
              gradient: const LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [AppTheme.emerald600, AppTheme.gold500],
              ),
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
                    if (i < 0 || i >= rows.length) {
                      return const SizedBox.shrink();
                    }
                    final label =
                        '${rows[i][labelKey] ?? rows[i][altLabel] ?? '?'}';
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        label.length > 8 ? '${label.substring(0, 8)}…' : label,
                        style: Theme.of(context).textTheme.labelSmall,
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
}
