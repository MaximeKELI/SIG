import 'package:latlong2/latlong.dart';

/// Parse GeoJSON FeatureCollection → polygones pour flutter_map.
class GeoJsonZone {
  GeoJsonZone({
    required this.code,
    required this.name,
    required this.zoneType,
    required this.rings,
  });

  final String code;
  final String name;
  final String zoneType;
  final List<List<LatLng>> rings;
}

List<GeoJsonZone> parseZonesGeoJson(Map<String, dynamic> geojson) {
  final features = geojson['features'] as List? ?? [];
  final zones = <GeoJsonZone>[];
  for (final f in features) {
    final feature = Map<String, dynamic>.from(f as Map);
    final props = Map<String, dynamic>.from(feature['properties'] as Map? ?? {});
    final geom = Map<String, dynamic>.from(feature['geometry'] as Map? ?? {});
    final rings = _ringsFromGeometry(geom);
    if (rings.isEmpty) continue;
    zones.add(GeoJsonZone(
      code: props['code']?.toString() ?? '',
      name: props['name']?.toString() ?? props['code']?.toString() ?? 'Zone',
      zoneType: props['zone_type']?.toString() ?? 'canton',
      rings: rings,
    ));
  }
  return zones;
}

List<List<LatLng>> _ringsFromGeometry(Map<String, dynamic> geom) {
  final type = geom['type']?.toString();
  final coords = geom['coordinates'];
  if (coords == null) return [];

  // Polygon: [ ring, hole… ] where ring = [[lon, lat], …]
  if (type == 'Polygon') {
    return (coords as List)
        .map((ring) => _ringFromCoords(ring as List))
        .where((ring) => ring.isNotEmpty)
        .toList();
  }
  // MultiPolygon: [ polygon, … ] where polygon = [ ring, … ]
  if (type == 'MultiPolygon') {
    final rings = <List<LatLng>>[];
    for (final poly in coords as List) {
      for (final ring in poly as List) {
        final parsed = _ringFromCoords(ring as List);
        if (parsed.isNotEmpty) rings.add(parsed);
      }
    }
    return rings;
  }
  return [];
}

List<LatLng> _ringFromCoords(List ring) {
  return ring
      .map((c) {
        final pair = c as List;
        final lon = (pair[0] as num).toDouble();
        final lat = (pair[1] as num).toDouble();
        return LatLng(lat, lon);
      })
      .toList();
}
