import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sig_sols_mobile/core/offline/offline_queue_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('buildPointBody format GeoJSON + client_id', () {
    final body = OfflineQueueService.buildPointBody(
      lat: 6.4,
      lon: 1.35,
      ph: 6.2,
      humidityPct: 35,
      soilType: 'limoneux',
      clientId: 'fixed',
    );
    expect(body['type'], 'Feature');
    expect(body['geometry']['type'], 'Point');
    expect(body['geometry']['coordinates'], [1.35, 6.4]);
    expect(body['properties']['ph'], 6.2);
    expect(body['properties']['client_id'], 'fixed');
    expect(body['properties']['source'], 'terrain');
  });

  test('validateLocal rejette bbox hors Maritime', () {
    final err = OfflineQueueService.validateLocal(
      lat: 5.0,
      lon: 5.0,
      ph: 6.2,
      humidityPct: 35,
    );
    expect(err.containsKey('location'), isTrue);
  });

  test('enqueue et readAll persistent la file', () async {
    final queue = OfflineQueueService();
    final body = OfflineQueueService.buildPointBody(
      lat: 6.3, lon: 1.2, ph: 7, humidityPct: 40, soilType: 'argileux',
    );
    await queue.enqueue(body);
    final items = await queue.readAll();
    expect(items.length, 1);
    expect(items.first.body['properties']['soil_type'], 'argileux');
    expect(items.first.queuedAt, greaterThan(0));
    expect(items.first.body['properties']['client_id'], isNotEmpty);
  });

  test('replaceAll met à jour la file', () async {
    final queue = OfflineQueueService();
    await queue.enqueue({'type': 'Feature', 'properties': {}});
    await queue.replaceAll([]);
    expect(await queue.readAll(), isEmpty);
  });

  test('QueuedSoilPoint round-trip JSON', () {
    final item = QueuedSoilPoint(
      body: {'type': 'Feature'},
      queuedAt: 12345,
      attempts: 2,
      lastError: 'network',
    );
    final restored = QueuedSoilPoint.fromJson(item.toJson());
    expect(restored.body['type'], 'Feature');
    expect(restored.queuedAt, 12345);
    expect(restored.attempts, 2);
    expect(restored.lastError, 'network');
  });

  test('appendDeadLetter conserve les échecs permanents', () async {
    final queue = OfflineQueueService();
    await queue.appendDeadLetter([
      QueuedSoilPoint(body: {'id': 1}, queuedAt: 1, deadAt: 99),
    ]);
    final dead = await queue.readDeadLetter();
    expect(dead.length, 1);
    expect(dead.first.deadAt, 99);
  });
}
