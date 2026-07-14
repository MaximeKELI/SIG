import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/env.dart';

double? _number(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value');

LatLng? _latLng(dynamic value) {
  if (value is List && value.length >= 2) {
    final first = _number(value[0]);
    final second = _number(value[1]);
    return first == null || second == null ? null : LatLng(second, first);
  }
  if (value is! Map) return null;
  final data = Map<String, dynamic>.from(value);
  final lat = _number(data['lat'] ?? data['latitude']);
  final lon = _number(data['lon'] ?? data['lng'] ?? data['longitude']);
  return lat == null || lon == null ? null : LatLng(lat, lon);
}

List<dynamic> _items(Map data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is List) return value;
    if (value is Map && value['features'] is List) {
      return value['features'] as List;
    }
  }
  return const [];
}

/// Converts API heatmap points (lat/lon + weight or pH) into map circles.
List<CircleMarker> heatmapCirclesFromApi(Map heatmap) {
  final points = _items(heatmap, const ['points', 'cells', 'features']);
  final values =
      points
          .whereType<Map>()
          .map((raw) => Map<String, dynamic>.from(raw))
          .map(
            (p) =>
                _number(p['weight'] ?? p['ph'] ?? p['value'] ?? p['intensity']),
          )
          .whereType<double>()
          .toList();
  final min = values.isEmpty ? 0.0 : values.reduce((a, b) => a < b ? a : b);
  final max = values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);

  return points
      .whereType<Map>()
      .map((raw) {
        final point = Map<String, dynamic>.from(raw);
        final geometry = point['geometry'];
        final location =
            _latLng(point) ??
            (geometry is Map ? _latLng(geometry['coordinates']) : null);
        if (location == null) return null;
        final value =
            _number(
              point['weight'] ??
                  point['ph'] ??
                  point['value'] ??
                  point['intensity'],
            ) ??
            min;
        final intensity =
            max == min ? 0.65 : ((value - min) / (max - min)).clamp(0.0, 1.0);
        final color = Color.lerp(Colors.blue, Colors.red, intensity)!;
        return CircleMarker(
          point: location,
          radius: 18 + intensity * 24,
          color: color.withValues(alpha: 0.20 + intensity * 0.50),
          borderColor: color.withValues(alpha: 0.85),
          borderStrokeWidth: 1.5,
        );
      })
      .whereType<CircleMarker>()
      .toList();
}

/// Converts trajectory locations or points into a line.
List<Polyline> trajectoryPolylines(Map trajectory) {
  final rawPoints = _items(trajectory, const [
    'locations',
    'points',
    'path',
    'coordinates',
  ]);
  final points = rawPoints.map(_latLng).whereType<LatLng>().toList();
  if (points.length < 2) return const [];
  return [
    Polyline(
      points: points,
      color: const Color(0xFFC9A962),
      strokeWidth: 4,
      borderColor: Colors.white.withValues(alpha: 0.8),
      borderStrokeWidth: 1,
    ),
  ];
}

/// Displays proximity API results as distinct teal circles.
List<CircleMarker> proximityCirclesFromApi(Map proximity) {
  final points = _items(proximity, const ['points', 'results', 'features']);
  return points
      .whereType<Map>()
      .map((raw) {
        final point = Map<String, dynamic>.from(raw);
        final geometry = point['geometry'];
        final location =
            _latLng(point) ??
            (geometry is Map ? _latLng(geometry['coordinates']) : null);
        if (location == null) return null;
        return CircleMarker(
          point: location,
          radius: 10,
          color: Colors.teal.withValues(alpha: 0.45),
          borderColor: Colors.teal.shade900,
          borderStrokeWidth: 2,
        );
      })
      .whereType<CircleMarker>()
      .toList();
}

TileLayer nasaLayer(String product) => TileLayer(
  urlTemplate: Env.nasaTileUrl(product),
  userAgentPackageName: 'tg.dusol.sig_sols_mobile',
);

TileLayer sentinelLayer() => TileLayer(
  urlTemplate: Env.sentinelTileUrl('ndvi'),
  userAgentPackageName: 'tg.dusol.sig_sols_mobile',
);
