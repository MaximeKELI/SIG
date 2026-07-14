import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sig_sols_mobile/core/map/geojson_parser.dart';
import 'package:sig_sols_mobile/models/parcel_analysis.dart';

void main() {
  test('parseZonesGeoJson MultiPolygon produit plusieurs anneaux', () {
    final zones = parseZonesGeoJson({
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': {
            'code': 'DEG-01',
            'name': 'Dégradée',
            'zone_type': 'degraded',
          },
          'geometry': {
            'type': 'MultiPolygon',
            'coordinates': [
              [
                [
                  [1.0, 6.0],
                  [1.1, 6.0],
                  [1.1, 6.1],
                  [1.0, 6.1],
                  [1.0, 6.0],
                ],
              ],
              [
                [
                  [1.2, 6.2],
                  [1.3, 6.2],
                  [1.3, 6.3],
                  [1.2, 6.3],
                  [1.2, 6.2],
                ],
              ],
            ],
          },
        },
      ],
    });

    expect(zones.length, 1);
    expect(zones.first.rings.length, 2);
    expect(zones.first.rings.first.first.latitude, 6.0);
    expect(zones.first.rings.first.first.longitude, 1.0);
  });

  test('ParcelAnalysis.raw permet un export JSON stable', () {
    final analysis = ParcelAnalysis.fromJson({
      'parcel_name': 'Canton Test',
      'area': {'area_ha': 12.5},
      'soil_points': {'count': 3},
      'health_index': 0.82,
      'recommendations': ['Chauler', 'Couvert végétal'],
      'weather': {'temp': 29},
    });

    expect(analysis.raw, isNotNull);
    final export = const JsonEncoder.withIndent('  ').convert(analysis.raw);
    final decoded = jsonDecode(export) as Map<String, dynamic>;
    expect(decoded['parcel_name'], 'Canton Test');
    expect(decoded['recommendations'], ['Chauler', 'Couvert végétal']);
    expect(analysis.areaHa, 12.5);
    expect(analysis.soilPointsCount, 3);
  });
}
