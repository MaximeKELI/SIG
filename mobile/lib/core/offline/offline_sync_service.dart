import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../services/sig_api.dart';
import '../auth/auth_service.dart';
import 'offline_queue_service.dart';

/// Synchronise la file offline vers PostGIS (même logique que `syncOfflineQueue` web).
class OfflineSyncService extends ChangeNotifier {
  OfflineSyncService({
    required SigApi api,
    required AuthService auth,
    OfflineQueueService? queue,
    Connectivity? connectivity,
  })  : _api = api,
        _auth = auth,
        _queue = queue ?? OfflineQueueService(),
        _connectivity = connectivity ?? Connectivity();

  final SigApi _api;
  final AuthService _auth;
  final OfflineQueueService _queue;
  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _online = true;
  int _pending = 0;
  int _deadLetterCount = 0;
  bool _syncing = false;
  String? _lastMessage;

  bool get isOnline => _online;
  int get pendingCount => _pending;
  int get deadLetterCount => _deadLetterCount;
  bool get isSyncing => _syncing;
  String? get lastMessage => _lastMessage;

  Future<void> init() async {
    _online = await _checkOnline();
    _pending = (await _queue.readAll()).length;
    _deadLetterCount = (await _queue.readDeadLetter()).length;
    notifyListeners();

    _sub = _connectivity.onConnectivityChanged.listen((_) async {
      final wasOffline = !_online;
      _online = await _checkOnline();
      notifyListeners();
      if (wasOffline && _online) {
        await sync();
      }
    });

    if (_online) {
      await sync();
    }
  }

  Future<void> refreshPending() async {
    _pending = (await _queue.readAll()).length;
    _deadLetterCount = (await _queue.readDeadLetter()).length;
    notifyListeners();
  }

  Future<bool> queuePoint(Map<String, dynamic> body) async {
    final coords = (body['geometry'] as Map?)?['coordinates'] as List?;
    final props = body['properties'] as Map? ?? {};
    final lon = (coords != null && coords.length >= 2) ? (coords[0] as num).toDouble() : 0.0;
    final lat = (coords != null && coords.length >= 2) ? (coords[1] as num).toDouble() : 0.0;
    final errors = OfflineQueueService.validateLocal(
      lat: lat,
      lon: lon,
      ph: (props['ph'] as num?)?.toDouble() ?? 0,
      humidityPct: (props['humidity_pct'] as num?)?.toDouble() ?? 0,
    );
    if (errors.isNotEmpty) {
      throw StateError(errors.values.join(' '));
    }
    await _queue.enqueue(body);
    await refreshPending();
    _lastMessage = 'Point en file d\'attente (hors ligne).';
    notifyListeners();
    return false;
  }

  Future<bool> submitPoint(Map<String, dynamic> body) async {
    final enriched = OfflineQueueService.ensureClientId(body);
    _online = await _checkOnline();
    if (!_online) {
      await queuePoint(enriched);
      return false;
    }
    if (!_auth.isAuthenticated) {
      throw StateError('Connexion requise pour enregistrer un point.');
    }
    try {
      await _api.createSoilPoint(enriched);
      _lastMessage = 'Point enregistré (validation en attente).';
      notifyListeners();
      return true;
    } catch (e) {
      if (!_online) {
        await queuePoint(enriched);
        return false;
      }
      rethrow;
    }
  }

  Future<int> sync() async {
    if (_syncing) return 0;
    _online = await _checkOnline();
    if (!_online || !_auth.isAuthenticated) return 0;

    _syncing = true;
    notifyListeners();

    var synced = 0;
    final remaining = <QueuedSoilPoint>[];
    final dead = <QueuedSoilPoint>[];
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      final items = await _queue.readAll();
      for (final item in items) {
        if (item.nextRetryAt != null && item.nextRetryAt! > now) {
          remaining.add(item);
          continue;
        }
        try {
          await _api.createSoilPoint(item.body);
          synced += 1;
        } catch (e) {
          final attempts = item.attempts + 1;
          final msg = e.toString();
          final permanent = _isPermanent(e);
          final updated = item.copyWith(
            attempts: attempts,
            lastError: msg,
            nextRetryAt: permanent
                ? null
                : now + _backoffMs(attempts),
            deadAt: (permanent || attempts >= OfflineQueueService.maxSyncAttempts)
                ? now
                : null,
          );
          if (permanent || attempts >= OfflineQueueService.maxSyncAttempts) {
            dead.add(updated);
          } else {
            remaining.add(updated);
          }
        }
      }
      await _queue.replaceAll(remaining);
      await _queue.appendDeadLetter(dead);
      _pending = remaining.length;
      _deadLetterCount = (await _queue.readDeadLetter()).length;
      if (synced > 0) {
        _lastMessage = '$synced point(s) synchronisé(s).';
      } else if (dead.isNotEmpty) {
        _lastMessage = '${dead.length} point(s) invalides (file morte).';
      }
    } finally {
      _syncing = false;
      notifyListeners();
    }

    return synced;
  }

  bool _isPermanent(Object e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      return code == 400 || code == 401 || code == 403 || code == 409;
    }
    final msg = e.toString();
    return msg.contains('400') ||
        msg.contains('403') ||
        msg.contains('pH hors') ||
        msg.contains('Coordonnées hors');
  }

  int _backoffMs(int attempts) {
    final ms = 2000 * (1 << (attempts - 1).clamp(0, 5));
    return ms > 60000 ? 60000 : ms;
  }

  Future<bool> _checkOnline() async {
    final results = await _connectivity.checkConnectivity();
    if (results.contains(ConnectivityResult.none)) return false;
    try {
      await _api.fetchSystemHealth();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
