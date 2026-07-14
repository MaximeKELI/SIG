import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/parcel_analysis.dart';
import '../../services/sig_api.dart';
import '../../shared/widgets/external_api_cards.dart';
import '../../shared/widgets/loading_view.dart';

class ParcelScreen extends StatefulWidget {
  const ParcelScreen({super.key});

  @override
  State<ParcelScreen> createState() => _ParcelScreenState();
}

class _ParcelScreenState extends State<ParcelScreen> {
  ParcelAnalysis? _result;
  List<Map<String, dynamic>> _zones = [];
  String? _selectedZone;
  bool _useSentinel = true;
  bool _useWeather = true;
  bool _useMl = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  Future<void> _loadZones() async {
    try {
      final zones = await context.read<SigApi>().parcelZones(zoneType: 'canton');
      if (mounted) {
        setState(() {
          _zones = zones
              .map((z) => Map<String, dynamic>.from(z as Map))
              .toList();
          if (_zones.isNotEmpty) {
            _selectedZone = _zones.first['code']?.toString();
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _analyzeZone() async {
    final code = _selectedZone;
    if (code == null || code.isEmpty) return;
    final api = context.read<SigApi>();
    setState(() => _loading = true);
    try {
      final result = await api.analyzeParcelByZone(
        code,
        useSentinel: _useSentinel,
        useWeather: _useWeather,
        useMl: _useMl,
      );
      setState(() => _result = result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _analyzeHere() async {
    final api = context.read<SigApi>();
    setState(() => _loading = true);
    try {
      final pos = await Geolocator.getCurrentPosition();
      final result = await api.analyzeParcelLive(
        geometry: {
          'type': 'Polygon',
          'coordinates': [
            [
              [pos.longitude - 0.01, pos.latitude - 0.01],
              [pos.longitude + 0.01, pos.latitude - 0.01],
              [pos.longitude + 0.01, pos.latitude + 0.01],
              [pos.longitude - 0.01, pos.latitude + 0.01],
              [pos.longitude - 0.01, pos.latitude - 0.01],
            ],
          ],
        },
        useSentinel: _useSentinel,
        useWeather: _useWeather,
        useMl: _useMl,
      );
      setState(() => _result = result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analyse parcelle')),
      body: _loading
          ? const LoadingView(message: 'Analyse NASA · Sentinel · Météo · ML…')
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Même API que le site : /spatial/parcel/live/ avec Sentinel, OpenWeather, NASA et ML.',
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Sentinel Hub (NDVI)'),
                  value: _useSentinel,
                  onChanged: (v) => setState(() => _useSentinel = v),
                ),
                SwitchListTile(
                  title: const Text('OpenWeather'),
                  value: _useWeather,
                  onChanged: (v) => setState(() => _useWeather = v),
                ),
                SwitchListTile(
                  title: const Text('ML fertilité'),
                  value: _useMl,
                  onChanged: (v) => setState(() => _useMl = v),
                ),
                if (_zones.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    value: _selectedZone,
                    decoration: const InputDecoration(
                      labelText: 'Zone canton',
                      border: OutlineInputBorder(),
                    ),
                    items: _zones
                        .map(
                          (z) => DropdownMenuItem(
                            value: z['code']?.toString(),
                            child: Text(z['name']?.toString() ?? z['code']?.toString() ?? '—'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedZone = v),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _analyzeZone,
                    icon: const Icon(Icons.map),
                    label: const Text('Analyser la zone'),
                  ),
                  const SizedBox(height: 8),
                ],
                FilledButton.icon(
                  onPressed: _analyzeHere,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Analyser ici (GPS)'),
                ),
                if (_result != null) ...[
                  const SizedBox(height: 20),
                  _buildResult(_result!),
                ],
              ],
            ),
    );
  }

  Widget _buildResult(ParcelAnalysis r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: ListTile(
            title: Text(r.parcelName),
            subtitle: Text(
              '${r.areaHa?.toStringAsFixed(1) ?? '—'} ha · '
              '${r.soilPointsCount ?? 0} points sol · '
              'Santé: ${r.healthIndex?.toStringAsFixed(2) ?? '—'}',
            ),
          ),
        ),
        ExternalApiCards(
          weather: r.weather,
          sentinel: r.sentinel,
          nasa: r.nasa,
          ml: r.mlPrediction,
        ),
        if (r.recommendations.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Recommandations', style: Theme.of(context).textTheme.titleMedium),
          ...r.recommendations.map(
            (rec) => ListTile(
              dense: true,
              leading: const Icon(Icons.lightbulb_outline),
              title: Text(rec),
            ),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: () => _exportJson(r),
          icon: const Icon(Icons.ios_share),
          label: const Text('Exporter JSON'),
        ),
      ],
    );
  }

  Future<void> _exportJson(ParcelAnalysis r) async {
    final payload = r.raw ?? {
      'parcel_name': r.parcelName,
      'area_ha': r.areaHa,
      'soil_points_count': r.soilPointsCount,
      'health_index': r.healthIndex,
      'recommendations': r.recommendations,
    };
    final text = const JsonEncoder.withIndent('  ').convert(payload);
    await Share.share(text, subject: 'SIG Sols Togo — parcelle ${r.parcelName}');
  }
}
