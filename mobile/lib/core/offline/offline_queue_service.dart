import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// File d'attente hors ligne — même format que le site web (`sig_sols_offline_queue`).
class OfflineQueueService {
  static const storageKey = 'sig_sols_offline_queue';
  static const deadLetterKey = 'sig_sols_offline_dead';
  static const maxSyncAttempts = 5;

  Future<List<QueuedSoilPoint>> readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => QueuedSoilPoint.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<QueuedSoilPoint>> readDeadLetter() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(deadLetterKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => QueuedSoilPoint.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> enqueue(Map<String, dynamic> body) async {
    final items = await readAll();
    final withId = ensureClientId(body);
    items.add(QueuedSoilPoint(
      body: withId,
      queuedAt: DateTime.now().millisecondsSinceEpoch,
      clientId: (withId['properties'] as Map)['client_id'] as String?,
    ));
    await _write(items);
  }

  Future<void> replaceAll(List<QueuedSoilPoint> items) async {
    await _write(items);
  }

  Future<void> appendDeadLetter(List<QueuedSoilPoint> items) async {
    if (items.isEmpty) return;
    final existing = await readDeadLetter();
    existing.addAll(items);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      deadLetterKey,
      jsonEncode(existing.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }

  Future<void> _write(List<QueuedSoilPoint> items) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(storageKey, encoded);
  }

  static Map<String, dynamic> ensureClientId(Map<String, dynamic> body) {
    final copy = Map<String, dynamic>.from(body);
    final props = Map<String, dynamic>.from(
      (copy['properties'] as Map?) ?? <String, dynamic>{},
    );
    props['client_id'] ??=
        'cli_${DateTime.now().millisecondsSinceEpoch}_${props.hashCode.abs()}';
    copy['properties'] = props;
    return copy;
  }

  /// Validation locale — mêmes bornes que backend validators.py
  static Map<String, String> validateLocal({
    required double lat,
    required double lon,
    required double ph,
    required double humidityPct,
  }) {
    final errors = <String, String>{};
    if (ph < 3.5 || ph > 9.5) {
      errors['ph'] = 'pH hors plage valide (3,5 – 9,5).';
    }
    if (humidityPct < 0 || humidityPct > 100) {
      errors['humidity_pct'] = 'Humidité hors plage (0 – 100 %).';
    }
    if (lon < 0.9 || lon > 1.8 || lat < 6.0 || lat > 6.8) {
      errors['location'] = 'Coordonnées hors Région Maritime (pilote).';
    }
    return errors;
  }

  /// Corps GeoJSON identique à frontend buildTerrainPointFeature.
  static Map<String, dynamic> buildPointBody({
    required double lat,
    required double lon,
    required double ph,
    required double humidityPct,
    required String soilType,
    String? clientId,
  }) {
    final today = DateTime.now().toIso8601String().split('T').first;
    return {
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [lon, lat],
      },
      'properties': {
        'ph': ph,
        'humidity_pct': humidityPct,
        'soil_type': soilType,
        'collected_at': today,
        'source': 'terrain',
        'client_id': clientId ??
            'cli_${DateTime.now().millisecondsSinceEpoch}',
      },
    };
  }
}

class QueuedSoilPoint {
  QueuedSoilPoint({
    required this.body,
    required this.queuedAt,
    this.clientId,
    this.attempts = 0,
    this.lastError,
    this.nextRetryAt,
    this.deadAt,
  });

  final Map<String, dynamic> body;
  final int queuedAt;
  final String? clientId;
  final int attempts;
  final String? lastError;
  final int? nextRetryAt;
  final int? deadAt;

  factory QueuedSoilPoint.fromJson(Map<String, dynamic> json) => QueuedSoilPoint(
        body: Map<String, dynamic>.from(json['body'] as Map),
        queuedAt: json['queued_at'] as int? ?? 0,
        clientId: json['client_id'] as String?,
        attempts: json['attempts'] as int? ?? 0,
        lastError: json['last_error'] as String?,
        nextRetryAt: json['next_retry_at'] as int?,
        deadAt: json['dead_at'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'body': body,
        'queued_at': queuedAt,
        if (clientId != null) 'client_id': clientId,
        'attempts': attempts,
        if (lastError != null) 'last_error': lastError,
        if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
        if (deadAt != null) 'dead_at': deadAt,
      };

  QueuedSoilPoint copyWith({
    int? attempts,
    String? lastError,
    int? nextRetryAt,
    int? deadAt,
  }) =>
      QueuedSoilPoint(
        body: body,
        queuedAt: queuedAt,
        clientId: clientId,
        attempts: attempts ?? this.attempts,
        lastError: lastError ?? this.lastError,
        nextRetryAt: nextRetryAt ?? this.nextRetryAt,
        deadAt: deadAt ?? this.deadAt,
      );
}
