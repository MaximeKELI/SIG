import 'package:flutter_test/flutter_test.dart';
import 'package:sig_sols_mobile/features/map/widgets/map_overlays.dart';

void main() {
  group('map overlays', () {
    test('creates heatmap circles from pH and coordinate points', () {
      final circles = heatmapCirclesFromApi({
        'points': [
          {'lat': 6.1, 'lon': 1.2, 'ph': 5.0},
          {'latitude': '6.2', 'longitude': '1.3', 'weight': 10},
        ],
      });

      expect(circles, hasLength(2));
      expect(circles.first.point.latitude, 6.1);
      expect(circles.last.point.longitude, 1.3);
      expect(circles.first.radius, lessThan(circles.last.radius));
    });

    test('creates one trajectory only with two valid locations', () {
      expect(
        trajectoryPolylines({
          'locations': [
            {'lat': 6.1, 'lon': 1.2},
            {'lat': 6.2, 'lon': 1.3},
          ],
        }).single.points,
        hasLength(2),
      );
      expect(
        trajectoryPolylines({
          'points': [
            {'lat': 6.1, 'lon': 1.2},
          ],
        }),
        isEmpty,
      );
    });

    test('reads GeoJSON proximity result coordinates', () {
      final circles = proximityCirclesFromApi({
        'features': [
          {
            'geometry': {
              'coordinates': [1.2, 6.1],
            },
          },
        ],
      });

      expect(circles.single.point.latitude, 6.1);
      expect(circles.single.point.longitude, 1.2);
    });
  });
}
