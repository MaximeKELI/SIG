import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/io.dart';

import '../../models/live_peer.dart';
import '../../services/sig_api.dart';
import '../api/api_client.dart';
import '../config/env.dart';

/// Positions live — polling + WebSocket (comme frontend/js/map.js + features.js).
class LiveLocationService extends ChangeNotifier {
  LiveLocationService({required SigApi api, required ApiClient client})
      : _api = api,
        _client = client;

  final SigApi _api;
  final ApiClient _client;

  final Map<int, LivePeer> _peers = {};
  bool _sharing = false;
  bool _wsConnected = false;
  bool _disposed = false;
  int _wsFailures = 0;
  String? _status;
  String? _lastSentKey;
  StreamSubscription<dynamic>? _wsSub;
  StreamSubscription<Position>? _positionSub;
  Timer? _pollTimer;
  Timer? _reconnectTimer;
  IOWebSocketChannel? _ws;

  bool get isSharing => _sharing;
  bool get wsConnected => _wsConnected;
  String? get status => _status;
  List<LivePeer> get peers => _peers.values.toList();

  Future<void> connectWebSocket() async {
    if (_disposed || _wsFailures >= 5) return;
    final token = await _client.getAccessToken();
    if (token == null || token.isEmpty) return;
    if (_ws != null) return;

    try {
      final uri = Uri.parse(Env.wsBaseUrl).replace(queryParameters: {'token': token});
      _ws = IOWebSocketChannel.connect(uri);
      _wsConnected = true;
      _wsFailures = 0;
      _status = 'WebSocket connecté';
      notifyListeners();

      _wsSub = _ws!.stream.listen(
        (raw) {
          try {
            final msg = jsonDecode(raw as String) as Map<String, dynamic>;
            if (msg['type'] == 'location') {
              _upsertPeer(LivePeer.fromJson(msg));
            }
          } catch (_) {}
        },
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect,
        cancelOnError: true,
      );
    } catch (e) {
      _wsFailures++;
      _wsConnected = false;
      _ws = null;
      _status = 'WebSocket indisponible (polling actif)';
      if (kDebugMode) debugPrint('WS connect: $e');
      notifyListeners();
      if (_wsFailures < 5) _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _wsConnected = false;
    _wsSub?.cancel();
    _wsSub = null;
    _ws = null;
    notifyListeners();
    _reconnectTimer?.cancel();
    if (_wsFailures < 5) {
      _reconnectTimer = Timer(const Duration(seconds: 15), connectWebSocket);
    }
  }

  Future<void> disconnectWebSocket() async {
    _reconnectTimer?.cancel();
    _wsSub?.cancel();
    _wsSub = null;
    try {
      await _ws?.sink.close();
    } catch (_) {}
    _ws = null;
    _wsConnected = false;
    if (!_disposed) notifyListeners();
  }

  Future<void> startSharing() async {
    if (_sharing || _disposed) return;
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      _status = 'GPS désactivé';
      notifyListeners();
      return;
    }

    _sharing = true;
    _status = 'Position partagée en direct';
    notifyListeners();

    await connectWebSocket();
    await _pollPeers();

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) => _pollPeers());

    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(_onPosition, onError: (e) {
      if (_disposed) return;
      _status = '$e';
      notifyListeners();
    });
  }

  Future<void> stopSharing() async {
    _sharing = false;
    _positionSub?.cancel();
    _positionSub = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _lastSentKey = null;
    _peers.clear();
    _status = 'Localisation désactivée';
    if (!_disposed) notifyListeners();
    try {
      await _api.clearLocation();
    } catch (_) {}
  }

  Future<void> toggleSharing() async {
    if (_sharing) {
      await stopSharing();
    } else {
      await startSharing();
    }
  }

  Future<void> _onPosition(Position pos) async {
    if (!_sharing || _disposed) return;
    final key = '${pos.latitude.toStringAsFixed(5)},${pos.longitude.toStringAsFixed(5)}';
    if (_lastSentKey == key) return;
    _lastSentKey = key;
    try {
      await _api.updateLocation(
        pos.latitude,
        pos.longitude,
        accuracyM: pos.accuracy,
        heading: pos.heading,
        isSharing: true,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Live location send: $e');
    }
  }

  Future<void> _pollPeers() async {
    if (_disposed) return;
    try {
      final data = await _api.fetchLiveLocations();
      final users = data['users'] as List? ?? [];
      _peers.clear();
      for (final u in users) {
        _upsertPeer(LivePeer.fromJson(Map<String, dynamic>.from(u as Map)));
      }
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('Live poll: $e');
    }
  }

  void _upsertPeer(LivePeer peer) {
    if (_disposed) return;
    _peers[peer.userId] = peer;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _positionSub?.cancel();
    _positionSub = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _sharing = false;
    disconnectWebSocket();
    // No network clearLocation() here: dispose must stay sync for Flutter tests.
    super.dispose();
  }
}
