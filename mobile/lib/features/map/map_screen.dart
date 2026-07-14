import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/auth/auth_service.dart';
import '../../core/i18n/locale_service.dart';
import '../../core/live/live_location_service.dart';
import '../../core/map/basemap_config.dart';
import '../../core/map/geojson_parser.dart';
import '../../core/offline/offline_sync_service.dart';
import '../../models/parcel_analysis.dart';
import 'widgets/map_overlays.dart';
import '../../shared/widgets/external_api_cards.dart';
import '../../models/live_peer.dart';
import '../../models/soil_point.dart';
import '../../services/sig_api.dart';
import '../../shared/widgets/add_soil_point_dialog.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.focusPointId});

  final int? focusPointId;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _togoCenter = LatLng(6.4, 1.35);
  final _mapController = MapController();

  List<SoilPoint> _points = [];
  Map<String, dynamic>? _apiStatus;
  bool _showSentinelNdvi = false;
  bool _showNasaNdvi = false;
  List<CircleMarker> _heatmapCircles = [];
  List<Polyline> _trajectoryLines = [];
  List<CircleMarker> _proximityMarkers = [];
  bool _showHeatmap = false;
  double _sentinelOpacity = 0.55;
  String _nasaProduct = 'MOD13Q1';
  String? _weatherBadge;
  bool _addPointMode = false;
  bool _drawParcelMode = false;
  List<LatLng> _drawnParcelPoints = [];
  String _validationMode = 'validated';
  bool _showParcels = true;
  String _parcelFilter = 'all';
  BasemapType _basemap = BasemapType.osm;
  List<GeoJsonZone> _zones = [];
  String? _selectedParcelCode;
  bool _loading = true;
  String? _error;
  LatLng? _myPosition;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _loadParcels() async {
    try {
      final data = await context.read<SigApi>().parcelZonesGeoJson();
      if (!mounted) return;
      setState(() {
        _zones = parseZonesGeoJson(Map<String, dynamic>.from(data as Map));
        if (_selectedParcelCode == null && _zones.isNotEmpty) {
          _selectedParcelCode = _zones.first.code;
        }
      });
    } catch (_) {}
  }

  List<GeoJsonZone> get _filteredZones {
    if (_parcelFilter == 'canton') {
      return _zones.where((z) => z.zoneType == 'canton').toList();
    }
    if (_parcelFilter == 'degraded') {
      return _zones.where((z) => z.zoneType == 'degraded').toList();
    }
    return _zones;
  }

  Color _zoneColor(GeoJsonZone z, {required bool selected}) {
    if (selected) return const Color(0xFFC9A962);
    return z.zoneType == 'degraded'
        ? Colors.orange.shade700
        : Colors.teal.shade600;
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<SigApi>();
      final results = await Future.wait([
        api.fetchSoilPoints(validationMode: _validationMode),
        api.fetchExternalApiStatus().catchError(
          (_) => <String, Map<String, dynamic>>{},
        ),
      ]);
      if (!mounted) return;
      LatLng? pos;
      try {
        final perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          await Geolocator.requestPermission();
        }
        final loc = await Geolocator.getCurrentPosition();
        pos = LatLng(loc.latitude, loc.longitude);
        await api.updateLocation(loc.latitude, loc.longitude);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _points = results[0] as List<SoilPoint>;
        _apiStatus = results[1] as Map<String, Map<String, dynamic>>;
        _myPosition = pos;
        _loading = false;
      });
      await _loadParcels();
      await _focusPointIfNeeded();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _focusPointIfNeeded() async {
    final id = widget.focusPointId;
    if (id == null || !mounted) return;
    SoilPoint? match;
    for (final p in _points) {
      if (p.id == id) {
        match = p;
        break;
      }
    }
    if (match == null) {
      try {
        final data = await context.read<SigApi>().fetchPoint(id);
        if (!mounted) return;
        match = SoilPoint.fromJson(Map<String, dynamic>.from(data));
        setState(() {
          if (!_points.any((p) => p.id == id)) {
            _points = [..._points, match!];
          }
        });
      } catch (_) {
        return;
      }
    }
    if (!mounted) return;
    final focused = match!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(LatLng(focused.lat, focused.lon), 15);
      _showPointSheet(focused);
    });
  }

  Color _phColor(SoilPoint p) {
    final ph = p.ph;
    if (ph == null) return Colors.grey;
    if (ph < 5.5) return Colors.red;
    if (ph < 6.5) return Colors.orange;
    if (ph < 7.5) return Colors.green;
    return Colors.blue;
  }

  Color _peerColor(LivePeer p) =>
      p.role == 'admin' ? Colors.orange : Colors.teal;

  @override
  Widget build(BuildContext context) {
    final i18n = context.watch<LocaleService>();
    final live = context.watch<LiveLocationService>();

    if (_loading) return LoadingView(message: i18n.t('map.loading'));
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    final basemap = _basemap;
    final layers = <Widget>[
      TileLayer(
        urlTemplate: basemap.urlTemplate,
        subdomains: basemap.subdomains ?? const ['a', 'b', 'c'],
        userAgentPackageName: 'tg.dusol.sig_sols_mobile',
      ),
      if (_showParcels && _filteredZones.isNotEmpty)
        PolygonLayer(
          polygons:
              _filteredZones.expand((z) {
                final selected = z.code == _selectedParcelCode;
                return z.rings.map(
                  (ring) => Polygon(
                    points: ring,
                    color: _zoneColor(
                      z,
                      selected: selected,
                    ).withValues(alpha: selected ? 0.35 : 0.18),
                    borderColor: _zoneColor(z, selected: selected),
                    borderStrokeWidth: selected ? 3 : 1.5,
                    label: z.name,
                    labelStyle: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                    ),
                  ),
                );
              }).toList(),
        ),
      if (_showSentinelNdvi)
        Opacity(opacity: _sentinelOpacity, child: sentinelLayer()),
      if (_showNasaNdvi) Opacity(opacity: 0.5, child: nasaLayer(_nasaProduct)),
      if (_showHeatmap && _heatmapCircles.isNotEmpty)
        CircleLayer(circles: _heatmapCircles),
      if (_proximityMarkers.isNotEmpty) CircleLayer(circles: _proximityMarkers),
      if (_trajectoryLines.isNotEmpty)
        PolylineLayer(polylines: _trajectoryLines),
      if (_drawnParcelPoints.isNotEmpty)
        PolygonLayer(
          polygons: [
            Polygon(
              points: _drawnParcelPoints,
              color: Colors.amber.withValues(alpha: 0.20),
              borderColor: Colors.amber.shade900,
              borderStrokeWidth: 3,
            ),
          ],
        ),
      MarkerLayer(
        markers: [
          ..._points.map(
            (p) => Marker(
              point: LatLng(p.lat, p.lon),
              width: 28,
              height: 28,
              child: GestureDetector(
                onTap: () => _showPointSheet(p),
                child: Icon(Icons.circle, color: _phColor(p), size: 14),
              ),
            ),
          ),
          if (_myPosition != null)
            Marker(
              point: _myPosition!,
              width: 36,
              height: 36,
              child: const Icon(Icons.my_location, color: Colors.cyanAccent),
            ),
          ...live.peers.map(
            (p) => Marker(
              point: LatLng(p.lat, p.lon),
              width: 32,
              height: 32,
              child: Tooltip(
                message: p.label,
                child: Icon(
                  Icons.person_pin_circle,
                  color: _peerColor(p),
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    ];

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _myPosition ?? _togoCenter,
            initialZoom: 9,
            onTap: (tapPos, point) {
              if (_addPointMode) {
                _openAddPointForm(point);
                return;
              }
              if (_drawParcelMode) {
                setState(
                  () => _drawnParcelPoints = [..._drawnParcelPoints, point],
                );
                return;
              }
              final hit = _zoneAt(point);
              if (hit != null) {
                setState(() => _selectedParcelCode = hit.code);
                _showParcelSheet(hit);
                return;
              }
              _showProbeMenu(context, point);
            },
          ),
          children: layers,
        ),
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(i18n.t('map.points', vars: {'n': '${_points.length}'})),
                  Text(
                    'OW: ${_statusMsg('weather')} · Sentinel: ${_statusMsg('sentinel')} · NASA: ${_statusMsg('nasa')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_weatherBadge != null)
                    Chip(
                      avatar: const Icon(Icons.wb_sunny_outlined, size: 16),
                      label: Text(_weatherBadge!),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (live.peers.isNotEmpty)
                    Text(
                      i18n.t(
                        'map.livePeers',
                        vars: {'n': '${live.peers.length}'},
                      ),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.tealAccent),
                    ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<BasemapType>(
                    value: _basemap,
                    decoration: InputDecoration(
                      labelText: i18n.t('map.basemap'),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                    items:
                        BasemapType.values
                            .map(
                              (b) => DropdownMenuItem(
                                value: b,
                                child: Text(b.label),
                              ),
                            )
                            .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _basemap = v);
                    },
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: FilterChip(
                          label: Text(i18n.t('map.parcels.show')),
                          selected: _showParcels,
                          onSelected: (v) => setState(() => _showParcels = v),
                        ),
                      ),
                    ],
                  ),
                  if (_showParcels && _zones.isNotEmpty) ...[
                    Wrap(
                      spacing: 4,
                      children: [
                        ChoiceChip(
                          label: Text(i18n.t('map.parcels.all')),
                          selected: _parcelFilter == 'all',
                          onSelected:
                              (_) => setState(() => _parcelFilter = 'all'),
                        ),
                        ChoiceChip(
                          label: Text(i18n.t('map.parcels.canton')),
                          selected: _parcelFilter == 'canton',
                          onSelected:
                              (_) => setState(() => _parcelFilter = 'canton'),
                        ),
                        ChoiceChip(
                          label: Text(i18n.t('map.parcels.degraded')),
                          selected: _parcelFilter == 'degraded',
                          onSelected:
                              (_) => setState(() => _parcelFilter = 'degraded'),
                        ),
                      ],
                    ),
                    DropdownButtonFormField<String>(
                      value:
                          _filteredZones.any(
                                (z) => z.code == _selectedParcelCode,
                              )
                              ? _selectedParcelCode
                              : (_filteredZones.isNotEmpty
                                  ? _filteredZones.first.code
                                  : null),
                      decoration: InputDecoration(
                        labelText: i18n.t('map.parcels'),
                        isDense: true,
                      ),
                      items:
                          _filteredZones
                              .map(
                                (z) => DropdownMenuItem(
                                  value: z.code,
                                  child: Text(z.name),
                                ),
                              )
                              .toList(),
                      onChanged: (code) {
                        if (code == null) return;
                        setState(() => _selectedParcelCode = code);
                        final z = _filteredZones.firstWhere(
                          (x) => x.code == code,
                        );
                        if (z.rings.isNotEmpty) {
                          _mapController.fitCamera(
                            CameraFit.coordinates(
                              coordinates: z.rings.first,
                              padding: const EdgeInsets.all(40),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      FilterChip(
                        label: Text(i18n.t('map.ndviSentinel')),
                        selected: _showSentinelNdvi,
                        onSelected:
                            (v) => setState(() => _showSentinelNdvi = v),
                      ),
                      FilterChip(
                        label: Text(i18n.t('map.ndviNasa')),
                        selected: _showNasaNdvi,
                        onSelected: (v) => setState(() => _showNasaNdvi = v),
                      ),
                      FilterChip(
                        label: const Text('Dessiner parcelle'),
                        selected: _drawParcelMode,
                        avatar: const Icon(Icons.draw, size: 18),
                        onSelected:
                            (v) => setState(() {
                              _drawParcelMode = v;
                              if (!v) _drawnParcelPoints = [];
                            }),
                      ),
                      FilterChip(
                        label: Text(i18n.t('map.addPoint')),
                        selected: _addPointMode,
                        avatar: Icon(
                          _addPointMode
                              ? Icons.add_location_alt
                              : Icons.add_location,
                          size: 18,
                        ),
                        onSelected: (v) => setState(() => _addPointMode = v),
                      ),
                      FilterChip(
                        label: Text(
                          live.isSharing
                              ? i18n.t('map.liveActive')
                              : i18n.t('map.liveShare'),
                        ),
                        selected: live.isSharing,
                        avatar: Icon(
                          live.isSharing
                              ? Icons.location_on
                              : Icons.location_searching,
                          size: 18,
                          color: live.isSharing ? Colors.greenAccent : null,
                        ),
                        onSelected: (_) => live.toggleSharing(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_addPointMode)
          Positioned(
            bottom: 80,
            left: 16,
            right: 16,
            child: Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(i18n.t('map.addMode')),
              ),
            ),
          ),
        if (_drawParcelMode)
          Positioned(
            bottom: 80,
            left: 16,
            right: 16,
            child: Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Touchez la carte : ${_drawnParcelPoints.length} sommet(s)',
                      ),
                    ),
                    TextButton(
                      onPressed:
                          _drawnParcelPoints.length >= 3
                              ? _analyzeDrawnParcel
                              : null,
                      child: const Text('Analyser'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'tools',
                onPressed: () => _showMapTools(context),
                child: const Icon(Icons.build),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'layers',
                onPressed: _showLayerPanel,
                child: const Icon(Icons.layers),
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                heroTag: 'loc',
                onPressed: () {
                  if (_myPosition != null)
                    _mapController.move(_myPosition!, 12);
                },
                child: const Icon(Icons.gps_fixed),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showExportDialog(BuildContext context, String label, String text) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text('Export $label'),
            content: SizedBox(
              width: double.maxFinite,
              height: 240,
              child: SingleChildScrollView(child: SelectableText(text)),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: text));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copié dans le presse-papiers'),
                    ),
                  );
                },
                child: const Text('Copier'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          ),
    );
  }

  String _statusMsg(String key) {
    final s = _apiStatus?[key];
    if (s == null) return '—';
    if (s['ok'] == true || s['configured'] == true || s['available'] == true)
      return 'OK';
    return s['message']?.toString() ?? '—';
  }

  GeoJsonZone? _zoneAt(LatLng point) {
    for (final z in _filteredZones) {
      for (final ring in z.rings) {
        if (_pointInPolygon(point, ring)) return z;
      }
    }
    return null;
  }

  bool _pointInPolygon(LatLng p, List<LatLng> ring) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final xi = ring[i].longitude, yi = ring[i].latitude;
      final xj = ring[j].longitude, yj = ring[j].latitude;
      final intersect =
          ((yi > p.latitude) != (yj > p.latitude)) &&
          (p.longitude <
              (xj - xi) * (p.latitude - yi) / (yj - yi + 1e-12) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  Future<void> _showParcelSheet(GeoJsonZone zone) async {
    final i18n = context.read<LocaleService>();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(zone.name, style: Theme.of(ctx).textTheme.titleLarge),
                  Text('${zone.zoneType} · ${zone.code}'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _analyzeParcel(zone.code);
                    },
                    icon: const Icon(Icons.analytics),
                    label: Text(i18n.t('map.parcels.analyze')),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _analyzeParcel(String code) async {
    final api = context.read<SigApi>();
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final result = await api.analyzeParcelByZone(code);
      if (!mounted) return;
      Navigator.pop(context);
      _showParcelResult(result);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _showParcelResult(ParcelAnalysis r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (ctx) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.55,
            maxChildSize: 0.9,
            builder:
                (_, scroll) => ListView(
                  controller: scroll,
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      r.parcelName,
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    Text(
                      '${r.areaHa?.toStringAsFixed(1) ?? '—'} ha · ${r.soilPointsCount ?? 0} points',
                    ),
                    const SizedBox(height: 12),
                    ExternalApiCards(
                      weather: r.weather,
                      sentinel: r.sentinel,
                      nasa: r.nasa,
                      ml: r.mlPrediction,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: () => _exportParcelJson(r),
                      icon: const Icon(Icons.ios_share),
                      label: const Text('Exporter JSON'),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _exportParcelJson(ParcelAnalysis r) async {
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

  void _showPointSheet(SoilPoint p) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _PointSheet(point: p),
    );
  }

  Future<void> _showLayerPanel() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (sheetContext) => StatefulBuilder(
            builder:
                (sheetContext, setSheetState) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Couches cartographiques',
                          style: Theme.of(sheetContext).textTheme.titleLarge,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('NASA'),
                          value: _showNasaNdvi,
                          onChanged: (value) {
                            setState(() => _showNasaNdvi = value);
                            setSheetState(() {});
                          },
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: _nasaProduct,
                          decoration: const InputDecoration(
                            labelText: 'Produit NASA',
                          ),
                          items:
                              const ['MOD13Q1', 'NDVI', 'MOD11A2', 'SMAP']
                                  .map(
                                    (product) => DropdownMenuItem(
                                      value: product,
                                      child: Text(product),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (product) {
                            if (product == null) {
                              return;
                            }
                            setState(() => _nasaProduct = product);
                            setSheetState(() {});
                          },
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Sentinel NDVI'),
                          value: _showSentinelNdvi,
                          onChanged: (value) {
                            setState(() => _showSentinelNdvi = value);
                            setSheetState(() {});
                          },
                        ),
                        Text(
                          'Opacité Sentinel : ${(_sentinelOpacity * 100).round()} %',
                        ),
                        Slider(
                          value: _sentinelOpacity,
                          min: 0,
                          max: 1,
                          divisions: 20,
                          onChanged: (value) {
                            setState(() => _sentinelOpacity = value);
                            setSheetState(() {});
                          },
                        ),
                        FilledButton.icon(
                          onPressed: _refreshWeatherBadge,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Actualiser la météo au centre'),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  Future<void> _refreshWeatherBadge() async {
    try {
      final center = _mapController.camera.center;
      final weather = await context.read<SigApi>().weatherCurrent(
        center.latitude,
        center.longitude,
      );
      final current =
          weather['current'] is Map
              ? Map<String, dynamic>.from(weather['current'] as Map)
              : weather;
      if (!mounted) return;
      setState(() {
        _weatherBadge =
            '${current['description'] ?? 'Météo'} · ${current['temp_c'] ?? current['temp'] ?? '—'}°C';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Météo actualisée sur la carte')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _analyzeDrawnParcel() async {
    if (_drawnParcelPoints.length < 3) {
      return;
    }
    final ring = [
      ..._drawnParcelPoints.map((point) => [point.longitude, point.latitude]),
      [_drawnParcelPoints.first.longitude, _drawnParcelPoints.first.latitude],
    ];
    final api = context.read<SigApi>();
    try {
      final result = await api.analyzeParcelLive(
        geometry: {
          'type': 'Polygon',
          'coordinates': [ring],
        },
      );
      if (!mounted) return;
      setState(() {
        _drawParcelMode = false;
        _drawnParcelPoints = [];
      });
      _showParcelResult(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _showMapTools(BuildContext context) async {
    final isAgent = context.read<AuthService>().user?.isAgent == true;
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder:
          (sheetCtx) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const Icon(Icons.near_me),
                  title: const Text('Près de moi (5 km)'),
                  onTap: () => Navigator.pop(sheetCtx, 'proximity'),
                ),
                ListTile(
                  leading: const Icon(Icons.grid_on),
                  title: const Text('Heatmap pH'),
                  onTap: () => Navigator.pop(sheetCtx, 'heatmap'),
                ),
                ListTile(
                  leading: const Icon(Icons.warning),
                  title: const Text('Alertes sécheresse'),
                  onTap: () => Navigator.pop(sheetCtx, 'alerts'),
                ),
                ListTile(
                  leading: const Icon(Icons.compare),
                  title: const Text('Comparer 2 points'),
                  onTap: () => Navigator.pop(sheetCtx, 'compare'),
                ),
                ListTile(
                  leading: const Icon(Icons.filter_list),
                  title: const Text('Filtres pH / type'),
                  onTap: () => Navigator.pop(sheetCtx, 'filters'),
                ),
                ListTile(
                  leading: const Icon(Icons.timeline),
                  title: const Text('Ma trajectoire 24h'),
                  onTap: () => Navigator.pop(sheetCtx, 'trajectory'),
                ),
                ListTile(
                  leading: const Icon(Icons.cloud),
                  title: const Text('Prévisions météo'),
                  onTap: () => Navigator.pop(sheetCtx, 'forecast'),
                ),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Export GeoJSON'),
                  onTap: () => Navigator.pop(sheetCtx, 'export_geojson'),
                ),
                ListTile(
                  leading: const Icon(Icons.table_chart),
                  title: const Text('Export CSV'),
                  onTap: () => Navigator.pop(sheetCtx, 'export_csv'),
                ),
                if (isAgent)
                  ListTile(
                    leading: const Icon(Icons.upload_file),
                    title: const Text('Import GeoJSON / CSV'),
                    onTap: () => Navigator.pop(sheetCtx, 'import'),
                  ),
              ],
            ),
          ),
    );
    if (!context.mounted || action == null) return;
    final api = context.read<SigApi>();
    try {
      if (action == 'proximity' && _myPosition != null) {
        final r = await api.proximity(
          lat: _myPosition!.latitude,
          lon: _myPosition!.longitude,
        );
        if (!context.mounted) return;
        final markers = proximityCirclesFromApi(r);
        setState(() => _proximityMarkers = markers);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${markers.length} point(s) à proximité affiché(s)'),
          ),
        );
      } else if (action == 'heatmap') {
        final r = await api.fetchHeatmap();
        if (!context.mounted) return;
        final circles = heatmapCirclesFromApi(r);
        setState(() {
          _heatmapCircles = circles;
          _showHeatmap = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${circles.length} cellule(s) pH affichée(s)'),
          ),
        );
      } else if (action == 'alerts') {
        final alerts = await api.droughtAlerts();
        if (!context.mounted) return;
        showDialog(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text('Alertes sécheresse'),
                content: Text('${alerts.length} alerte(s)'),
              ),
        );
      } else if (action == 'compare') {
        final aCtrl = TextEditingController();
        final bCtrl = TextEditingController();
        if (!context.mounted) return;
        final ok = await showDialog<bool>(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text('Comparer points'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: aCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ID point A',
                      ),
                    ),
                    TextField(
                      controller: bCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ID point B',
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Annuler'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Comparer'),
                  ),
                ],
              ),
        );
        if (ok == true) {
          final r = await api.comparePoints(
            int.parse(aCtrl.text),
            int.parse(bCtrl.text),
          );
          if (context.mounted) {
            showDialog(
              context: context,
              builder:
                  (_) => AlertDialog(
                    title: const Text('Comparaison'),
                    content: Text(r.toString()),
                  ),
            );
          }
        }
      } else if (action == 'filters') {
        await _loadWithFilters(context);
      } else if (action == 'trajectory') {
        final r = await api.fetchTrajectory();
        if (!context.mounted) return;
        final lines = trajectoryPolylines(r);
        setState(() => _trajectoryLines = lines);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lines.isEmpty
                  ? 'Aucune trajectoire à afficher'
                  : 'Trajectoire 24h affichée',
            ),
          ),
        );
      } else if (action == 'forecast' && _myPosition != null) {
        final w = await api.weatherForecast(
          _myPosition!.latitude,
          _myPosition!.longitude,
        );
        if (!context.mounted) return;
        showDialog(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text('Prévisions météo'),
                content: Text(w.toString()),
              ),
        );
      } else if (action == 'export_geojson') {
        final text = await api.exportPointsGeoJson();
        if (!context.mounted) return;
        _showExportDialog(context, 'GeoJSON', text);
      } else if (action == 'export_csv') {
        final text = await api.exportPointsCsv();
        if (!context.mounted) return;
        _showExportDialog(context, 'CSV', text);
      } else if (action == 'import') {
        final pick = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['geojson', 'json', 'csv'],
        );
        final path = pick?.files.single.path;
        if (path == null) return;
        final r = await api.importSoilFile(path);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${r['created'] ?? 0} point(s) importé(s)')),
        );
        await _load();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _loadWithFilters(BuildContext context) async {
    final soilCtrl = TextEditingController();
    final phMin = TextEditingController(text: '5');
    final phMax = TextEditingController(text: '8');
    var mode = _validationMode;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setLocal) => AlertDialog(
                  title: const Text('Filtres carte'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: mode,
                        decoration: const InputDecoration(
                          labelText: 'Validation',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'validated',
                            child: Text('Validés'),
                          ),
                          DropdownMenuItem(
                            value: 'pending',
                            child: Text('En attente'),
                          ),
                          DropdownMenuItem(
                            value: 'rejected',
                            child: Text('Rejetés'),
                          ),
                          DropdownMenuItem(value: 'all', child: Text('Tous')),
                        ],
                        onChanged:
                            (v) => setLocal(() => mode = v ?? 'validated'),
                      ),
                      TextField(
                        controller: soilCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Type sol',
                        ),
                      ),
                      TextField(
                        controller: phMin,
                        decoration: const InputDecoration(labelText: 'pH min'),
                      ),
                      TextField(
                        controller: phMax,
                        decoration: const InputDecoration(labelText: 'pH max'),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Annuler'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Appliquer'),
                    ),
                  ],
                ),
          ),
    );
    if (ok != true) return;
    try {
      final points = await context.read<SigApi>().fetchSoilPoints(
        validationMode: mode,
        soilType: soilCtrl.text.trim().isEmpty ? null : soilCtrl.text.trim(),
        phMin: double.tryParse(phMin.text),
        phMax: double.tryParse(phMax.text),
      );
      setState(() {
        _validationMode = mode;
        _points = points;
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openAddPointForm(LatLng coords) async {
    final body = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AddSoilPointDialog(coords: coords),
    );
    if (body == null || !mounted) return;

    final sync = context.read<OfflineSyncService>();
    try {
      final saved = await sync.submitPoint(body);
      if (!mounted) return;
      setState(() => _addPointMode = false);
      final msg =
          sync.lastMessage ??
          (saved ? 'Point enregistré.' : 'Point en file d\'attente.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      if (saved) await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _showProbeMenu(BuildContext context, LatLng point) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder:
          (sheetCtx) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const Icon(Icons.wb_sunny),
                  title: const Text('Météo OpenWeather'),
                  onTap: () => Navigator.pop(sheetCtx, 'weather'),
                ),
                ListTile(
                  leading: const Icon(Icons.satellite_alt),
                  title: const Text('NDVI Sentinel (zone)'),
                  onTap: () => Navigator.pop(sheetCtx, 'sentinel'),
                ),
                ListTile(
                  leading: const Icon(Icons.psychology),
                  title: const Text('ML fertilité'),
                  onTap: () => Navigator.pop(sheetCtx, 'ml'),
                ),
              ],
            ),
          ),
    );
    if (!context.mounted || action == null) return;
    final api = context.read<SigApi>();
    try {
      if (action == 'weather') {
        final w = await api.weatherCurrent(point.latitude, point.longitude);
        final cur = w['current'] as Map<String, dynamic>? ?? w;
        if (!context.mounted) return;
        showDialog(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text('OpenWeather'),
                content: Text(
                  '${cur['description'] ?? ''}\n'
                  'Temp: ${cur['temp_c'] ?? '—'}°C · Humidité: ${cur['humidity_pct'] ?? '—'}%',
                ),
              ),
        );
      } else if (action == 'sentinel') {
        final bbox = _bboxAround(point, 0.02);
        final s = await api.sentinelAnalyze(
          minLon: bbox[0],
          minLat: bbox[1],
          maxLon: bbox[2],
          maxLat: bbox[3],
        );
        if (!context.mounted) return;
        showDialog(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text('Sentinel Hub NDVI'),
                content: Text(
                  'NDVI moyen: ${s['ndvi_mean'] ?? s['error'] ?? '—'}',
                ),
              ),
        );
      } else if (action == 'ml') {
        final m = await api.predictFertility(
          lat: point.latitude,
          lon: point.longitude,
        );
        if (!context.mounted) return;
        showDialog(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text('ML Fertilité'),
                content: Text(
                  'Classe: ${m['fertility_class'] ?? m['prediction'] ?? '—'}',
                ),
              ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  List<double> _bboxAround(LatLng p, double d) => [
    p.longitude - d,
    p.latitude - d,
    p.longitude + d,
    p.latitude + d,
  ];
}

class _PointSheet extends StatelessWidget {
  const _PointSheet({required this.point});

  final SoilPoint point;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Point sol #${point.id}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text('pH: ${point.ph?.toStringAsFixed(1) ?? '—'}'),
          Text('Type: ${point.soilType ?? '—'}'),
          Text('Fertilité: ${point.fertilityClass ?? '—'}'),
          Text('NDVI: ${point.ndvi3mAvg?.toStringAsFixed(2) ?? '—'}'),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: () async {
                  try {
                    final ts = await context.read<SigApi>().ndviTimeseries(
                      point.id,
                    );
                    if (!context.mounted) return;
                    showDialog(
                      context: context,
                      builder:
                          (_) => AlertDialog(
                            title: const Text('NDVI time series'),
                            content: Text(ts.toString()),
                          ),
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                },
                icon: const Icon(Icons.timeline),
                label: const Text('Série NDVI'),
              ),
              TextButton.icon(
                onPressed: () async {
                  try {
                    final m = await context.read<SigApi>().predictFertility(
                      lat: point.lat,
                      lon: point.lon,
                      pointId: point.id,
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('ML: ${m['fertility_class'] ?? '—'}'),
                      ),
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                },
                icon: const Icon(Icons.psychology),
                label: const Text('ML'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
