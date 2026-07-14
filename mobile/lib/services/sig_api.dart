import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/config/env.dart';
import '../models/parcel_analysis.dart';
import '../models/soil_point.dart';

/// Façade API — parité complète avec le site web (frontend/js/).
class SigApi {
  SigApi(this._client);

  final ApiClient _client;

  // --- Sols / dashboard ---
  Future<Map<String, dynamic>> createSoilPoint(Map<String, dynamic> geoJsonBody) =>
      _client.post('/points/', data: geoJsonBody);

  Future<Map<String, dynamic>> importSoilFile(String filePath) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    return _client.upload('/points/import_data/', form);
  }

  Future<String> exportPointsGeoJson() => _client.downloadText('/points/geojson/');

  Future<String> exportPointsCsv() => _client.downloadText('/points/export-csv/');

  Future<String> adminExportUsers() => _client.downloadText('/platform/admin/export/users.csv');

  Future<String> adminExportActivity({int days = 30}) =>
      _client.downloadText('/platform/admin/export/activity.csv', query: {'days': days});

  Future<List<SoilPoint>> fetchSoilPoints({
    bool light = true,
    String? soilType,
    double? phMin,
    double? phMax,
    bool? validated,
    String? validationMode,
    String? bbox,
  }) async {
    // validationMode: validated | pending | rejected | all
    // bbox: min_lon,min_lat,max_lon,max_lat
    final mode = validationMode ??
        (validated == true
            ? 'validated'
            : validated == false
                ? 'all'
                : 'validated');
    final query = <String, dynamic>{
      'light': light ? '1' : '0',
      if (mode == 'validated') 'is_validated': 'true',
      if (mode == 'pending') 'validation_status': 'pending',
      if (mode == 'rejected') 'validation_status': 'rejected',
      if (soilType != null && soilType.isNotEmpty) 'soil_type': soilType,
      if (phMin != null) 'ph_min': phMin,
      if (phMax != null) 'ph_max': phMax,
      if (bbox != null && bbox.isNotEmpty) 'bbox': bbox,
    };
    final data = await _client.get<dynamic>('/points/', query: query);
    final list = data is Map
        ? (data['results'] as List? ?? data['features'] as List? ?? [])
        : data as List;
    return list
        .map((e) => SoilPoint.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> fetchPoint(int id) =>
      _client.get('/points/$id/');

  Future<Map<String, dynamic>> comparePoints(int a, int b) =>
      _client.get('/points/compare/', query: {'a': a, 'b': b});

  Future<Map<String, dynamic>> fetchHeatmap({String field = 'ph'}) =>
      _client.get('/heatmap/', query: {'field': field});

  Future<Map<String, dynamic>> fetchDashboardStats() =>
      _client.get('/dashboard/stats/');

  Future<Map<String, dynamic>> fetchSystemHealth() async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
    ));
    final res = await dio.get<Map<String, dynamic>>(Env.healthUrl);
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> fetchMlMetrics() => _client.get('/ml/metrics/');

  Future<Map<String, dynamic>> predictFertility({
    required double lat,
    required double lon,
    int? pointId,
  }) =>
      _client.post('/ml/predict/', data: {
        if (pointId != null) 'point_id': pointId,
        'lat': lat,
        'lon': lon,
      });

  Future<Map<String, dynamic>> trainMl() => _client.post('/ml/train/');

  // --- NASA ---
  Future<Map<String, dynamic>> nasaCatalogSummary() =>
      _client.get('/nasa/catalog/summary/');

  Future<List<dynamic>> nasaLayers() async {
    final data = await _client.get<dynamic>('/nasa/layers/');
    if (data is List) return data;
    return (data as Map)['results'] as List? ?? [];
  }

  Future<Map<String, dynamic>> nasaIngest() => _client.post('/nasa/ingest/');

  // --- Sentinel ---
  Future<Map<String, dynamic>> sentinelStatus() =>
      _client.get('/sentinel/status/');

  Future<Map<String, dynamic>> sentinelLayers() =>
      _client.get('/sentinel/layers/');

  Future<Map<String, dynamic>> sentinelAnalyze({
    required double minLon,
    required double minLat,
    required double maxLon,
    required double maxLat,
  }) =>
      _client.post('/sentinel/analyze/', data: {
        'bbox': [minLon, minLat, maxLon, maxLat],
      });

  // --- OpenWeather ---
  Future<Map<String, dynamic>> weatherStatus() =>
      _client.get('/weather/status/');

  Future<Map<String, dynamic>> weatherCurrent(double lat, double lon) =>
      _client.get('/weather/current/', query: {'lat': lat, 'lon': lon});

  Future<Map<String, dynamic>> weatherForecast(double lat, double lon) =>
      _client.get('/weather/forecast/', query: {'lat': lat, 'lon': lon});

  // --- Gemini ---
  Future<Map<String, dynamic>> assistantStatus() =>
      _client.get('/assistant/status/');

  Future<Map<String, dynamic>> assistantChat({
    required String message,
    List<Map<String, String>> history = const [],
    Map<String, dynamic>? context,
  }) =>
      _client.post('/assistant/chat/', data: {
        'message': message,
        'history': history,
        'context': context ?? {},
      });

  // --- Spatial / parcelle ---
  Future<List<dynamic>> parcelZones({String? zoneType}) async {
    final data = await _client.get<dynamic>(
      '/spatial/parcel/zones/',
      query: zoneType != null ? {'zone_type': zoneType} : null,
    );
    if (data is List) return data;
    return (data as Map)['results'] as List? ?? data['zones'] as List? ?? [];
  }

  Future<Map<String, dynamic>> parcelZonesGeoJson({String types = 'canton,degraded'}) =>
      _client.get('/spatial/parcel/zones/geojson/', query: {'types': types});

  Future<ParcelAnalysis> analyzeParcelLive({
    required Map<String, dynamic> geometry,
    bool useSentinel = true,
    bool useWeather = true,
    bool useMl = true,
    String? zoneCode,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/spatial/parcel/live/',
      data: {
        'geometry': geometry,
        'use_sentinel': useSentinel,
        'use_weather': useWeather,
        'use_ml': useMl,
        if (zoneCode != null) 'zone_code': zoneCode,
      },
    );
    return ParcelAnalysis.fromJson(data);
  }

  Future<ParcelAnalysis> analyzeParcelByZone(String zoneCode, {
    bool useSentinel = true,
    bool useWeather = true,
    bool useMl = true,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/spatial/parcel/live/',
      data: {
        'zone_code': zoneCode,
        'use_sentinel': useSentinel,
        'use_weather': useWeather,
        'use_ml': useMl,
      },
    );
    return ParcelAnalysis.fromJson(data);
  }

  Future<Map<String, dynamic>> ndviTimeseries(int pointId) =>
      _client.get('/spatial/ndvi-timeseries/$pointId/');

  Future<Map<String, dynamic>> proximity({
    required double lat,
    required double lon,
    int radiusM = 5000,
  }) =>
      _client.get('/spatial/proximity/', query: {
        'lat': lat,
        'lon': lon,
        'radius_m': radiusM,
      });

  Future<Map<String, dynamic>> smapCorrelation() =>
      _client.get('/spatial/smap-correlation/');

  // --- Éducation / quiz ---
  Future<Map<String, dynamic>> quizStats() =>
      _client.get('/education/quiz/stats/');

  Future<Map<String, dynamic>> startQuiz({
    String difficulty = 'facile',
    int count = 10,
    bool examMode = false,
  }) =>
      _client.post('/education/quiz/start/', data: {
        'difficulty': difficulty,
        'count': count,
        'exam_mode': examMode,
      });

  Future<Map<String, dynamic>> submitQuizAnswer(
    int sessionId, {
    required int questionId,
    required int selectedIndex,
  }) =>
      _client.post('/education/quiz/$sessionId/answer/', data: {
        'question_id': questionId,
        'selected_index': selectedIndex,
      });

  Future<Map<String, dynamic>> finishQuiz(int sessionId) =>
      _client.post('/education/quiz/$sessionId/finish/');

  Future<dynamic> quizLeaderboard() =>
      _client.get('/education/quiz/leaderboard/');

  Future<List<dynamic>> quizBadges() async {
    final data = await _client.get<dynamic>('/education/quiz/badges/');
    if (data is List) return data;
    return (data as Map)['badges'] as List? ?? [];
  }

  Future<Map<String, dynamic>> quizLearningPath() =>
      _client.get('/education/quiz/learning-path/');

  Future<Map<String, dynamic>> quizWeeklyChallenge() =>
      _client.get('/education/quiz/weekly-challenge/');

  String quizCertificateUrl(int sessionId) =>
      '${Env.origin}/api/v1/education/quiz/$sessionId/certificate/';

  Future<List<dynamic>> fetchSheets() async {
    final data = await _client.get<dynamic>('/education/sheets/');
    if (data is List) return data;
    return (data as Map)['results'] as List? ?? [];
  }

  String sheetPdfUrl(int id) => '${Env.origin}/api/v1/education/sheets/$id/pdf/';

  // --- Vidéos ---
  Future<Map<String, dynamic>> fetchVideo(int id) =>
      _client.get('/videos/posts/$id/');

  Future<List<dynamic>> fetchVideos({String kind = 'video', String? category}) async {
    final data = await _client.get<dynamic>(
      '/videos/posts/',
      query: {'kind': kind, if (category != null) 'category': category},
    );
    if (data is List) return data;
    return (data as Map)['results'] as List? ?? [];
  }

  Future<Map<String, dynamic>> toggleVideoLike(int postId) =>
      _client.post('/videos/posts/$postId/toggle_like/');

  Future<List<dynamic>> fetchVideoComments(int postId) async {
    final data = await _client.get<dynamic>('/videos/posts/$postId/comments/');
    if (data is List) return data;
    return (data as Map)['results'] as List? ?? [];
  }

  Future<Map<String, dynamic>> postVideoComment(int postId, String text, {int? parentId}) =>
      _client.post('/videos/posts/$postId/comments/', data: {
        'text': text,
        if (parentId != null) 'parent': parentId,
      });

  Future<Map<String, dynamic>> uploadVideo({
    required String filePath,
    required String kind,
    required String title,
    String description = '',
    String category = 'sols',
    String hashtags = '',
    int? durationSeconds,
    String? thumbnailPath,
  }) async {
    final form = FormData.fromMap({
      'kind': kind,
      'title': title,
      'description': description,
      'category': category,
      if (hashtags.isNotEmpty) 'hashtags': hashtags,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      'file': await MultipartFile.fromFile(filePath),
      if (thumbnailPath != null && thumbnailPath.isNotEmpty)
        'thumbnail': await MultipartFile.fromFile(thumbnailPath),
    });
    return _client.upload('/videos/posts/', form);
  }

  Future<List<dynamic>> fetchStories() async {
    final data = await _client.get<dynamic>('/videos/stories/');
    if (data is List) return data;
    return (data as Map)['results'] as List? ?? [];
  }

  Future<Map<String, dynamic>> uploadStory({
    required String filePath,
    String caption = '',
  }) async {
    final form = FormData.fromMap({
      'caption': caption,
      'media': await MultipartFile.fromFile(filePath),
    });
    return _client.upload('/videos/stories/', form);
  }

  Future<List<dynamic>> pendingVideos() async {
    final data = await _client.get<dynamic>('/videos/posts/pending/');
    if (data is List) return data;
    return (data as Map)['results'] as List? ?? [];
  }

  Future<void> approveVideo(int id) => _client.post('/videos/posts/$id/approve/');

  Future<void> rejectVideo(int id, {String reason = ''}) =>
      _client.post('/videos/posts/$id/reject/', data: {'reason': reason});

  // --- Communauté / auth social ---
  Future<List<dynamic>> fetchFeed() async {
    final data = await _client.get<dynamic>('/auth/feed/');
    if (data is List) return data;
    return (data as Map)['results'] as List? ?? [];
  }

  Future<List<dynamic>> searchUsers(String query) async {
    final data = await _client.get<dynamic>(
      '/auth/users/search/',
      query: {'q': query},
    );
    if (data is List) return data;
    return (data as Map)['results'] as List? ?? [];
  }

  Future<Map<String, dynamic>> publicProfile(String username) =>
      _client.get('/auth/users/$username/public/');

  Future<void> followUser(String username) =>
      _client.post('/auth/users/$username/follow/');

  Future<void> unfollowUser(String username) =>
      _client.delete('/auth/users/$username/follow/');

  Future<List<dynamic>> fetchFavorites() async {
    final data = await _client.get<dynamic>('/auth/favorites/');
    if (data is List) return data;
    return (data as Map)['results'] as List? ?? [];
  }

  Future<void> addFavorite({required String targetType, required int targetId}) =>
      _client.post('/auth/favorites/', data: {
        'target_type': targetType,
        'target_id': targetId,
      });

  Future<void> removeFavorite({required String targetType, required int targetId}) =>
      _client.delete('/auth/favorites/', data: {
        'target_type': targetType,
        'target_id': targetId,
      });

  Future<List<dynamic>> fetchMessages({String? withUser}) async {
    final data = await _client.get<dynamic>(
      '/auth/messages/',
      query: withUser != null ? {'with': withUser} : null,
    );
    if (data is List) return data;
    return (data as Map)['results'] as List? ?? data['messages'] as List? ?? [];
  }

  Future<Map<String, dynamic>> sendMessage({
    required String recipientUsername,
    required String body,
  }) =>
      _client.post('/auth/messages/', data: {
        'recipient_username': recipientUsername,
        'body': body,
      });

  Future<Map<String, dynamic>> fetchTrajectory({int? userId, int hours = 24}) {
    final path = userId != null ? '/auth/trajectory/$userId/' : '/auth/trajectory/';
    return _client.get(path, query: {'hours': hours});
  }

  Future<void> updateLocation(
    double lat,
    double lon, {
    double? accuracyM,
    double? heading,
    bool isSharing = true,
  }) =>
      _client.post('/auth/location/', data: {
        'lat': lat,
        'lon': lon,
        if (accuracyM != null) 'accuracy_m': accuracyM,
        if (heading != null) 'heading': heading,
        'is_sharing': isSharing,
      });

  Future<void> clearLocation() => _client.delete('/auth/location/');

  Future<Map<String, dynamic>> fetchLiveLocations({bool includeSelf = false}) =>
      _client.get('/auth/locations/live/', query: includeSelf ? {'include_self': '1'} : null);

  // --- Platform ---
  Future<List<dynamic>> fetchNotifications() async {
    final data = await _client.get<dynamic>('/platform/notifications/');
    if (data is List) return data;
    return (data as Map)['results'] as List? ?? [];
  }

  Future<int> unreadNotifications() async {
    final data =
        await _client.get<Map<String, dynamic>>('/platform/notifications/unread-count/');
    return data['unread_count'] as int? ?? data['count'] as int? ?? 0;
  }

  Future<void> markNotificationRead(int id) =>
      _client.post('/platform/notifications/$id/read/');

  Future<void> markAllNotificationsRead() =>
      _client.post('/platform/notifications/mark-all-read/');

  Future<List<dynamic>> globalSearch(String q) async {
    final data = await _client.get<dynamic>('/platform/search/', query: {'q': q});
    if (data is List) return data;
    return (data as Map)['results'] as List? ?? [];
  }

  Future<Map<String, dynamic>> personalDashboard() =>
      _client.get('/platform/me/dashboard/');

  Future<List<dynamic>> droughtAlerts() async {
    final data = await _client.get<dynamic>('/platform/alerts/drought/');
    if (data is List) return data;
    return (data as Map)['alerts'] as List? ?? data['results'] as List? ?? [];
  }

  Future<List<dynamic>> alertsNear(double lat, double lon, {int radiusKm = 30}) async {
    final data = await _client.get<dynamic>(
      '/platform/alerts/near/',
      query: {'lat': lat, 'lon': lon, 'radius_km': radiusKm},
    );
    if (data is List) return data;
    return (data as Map)['alerts'] as List? ?? [];
  }

  Future<void> requestPasswordReset(String email) =>
      _client.post('/platform/password/reset/', data: {'email': email});

  Future<void> confirmPasswordReset({
    required String token,
    required String password,
    String? passwordConfirm,
  }) =>
      _client.post('/platform/password/reset/confirm/', data: {
        'token': token,
        'new_password': password,
        'new_password_confirm': passwordConfirm ?? password,
      });

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
    String? newPasswordConfirm,
  }) =>
      _client.post('/auth/password/change/', data: {
        'old_password': oldPassword,
        'new_password': newPassword,
        'new_password_confirm': newPasswordConfirm ?? newPassword,
      });

  Future<void> postActivity({
    required String sessionId,
    required List<Map<String, dynamic>> events,
  }) =>
      _client.post('/platform/activity/', data: {
        'session_id': sessionId,
        'events': events,
      });

  // --- Admin ---
  Future<Map<String, dynamic>> adminDashboard() =>
      _client.get('/platform/admin/dashboard/');

  Future<Map<String, dynamic>> adminAnalytics({int days = 30}) =>
      _client.get('/platform/admin/analytics/', query: {'days': days});

  Future<List<dynamic>> pendingValidation() async {
    final data = await _client.get<dynamic>('/validation/pending/');
    if (data is Map) return data['results'] as List? ?? [];
    return data as List? ?? [];
  }

  Future<Map<String, dynamic>> validatePoint(int id, {String action = 'validate'}) =>
      _client.post('/points/$id/validate_point/', data: {'action': action});

  Future<Map<String, dynamic>> deleteProfilePhoto() =>
      _client.deleteProfilePhoto();

  Future<Map<String, dynamic>> toggleCommentLike(int commentId) =>
      _client.post('/videos/comments/$commentId/toggle_like/');

  Future<List<dynamic>> commentsModeration() async {
    final data = await _client.get<dynamic>('/videos/comments/moderation/');
    if (data is List) return data;
    return (data as Map)['results'] as List? ?? [];
  }

  Future<void> hideComment(int commentId) =>
      _client.post('/videos/comments/$commentId/hide/');

  Future<Map<String, dynamic>> aiCheckComment(int commentId) =>
      _client.post('/videos/comments/$commentId/ai-check/');

  Future<List<dynamic>> moderationJournal() async {
    final data = await _client.get<dynamic>('/platform/moderation/journal/');
    if (data is List) return data;
    return (data as Map)['results'] as List? ?? data['entries'] as List? ?? [];
  }

  Future<List<dynamic>> adminActivity({int days = 30}) async {
    final data = await _client.get<dynamic>(
      '/platform/admin/activity/',
      query: {'days': days},
    );
    if (data is List) return data;
    return (data as Map)['results'] as List? ?? data['events'] as List? ?? [];
  }

  Future<Map<String, dynamic>> adminUserActivity(int userId, {int days = 30}) =>
      _client.get('/platform/admin/activity/users/$userId/', query: {'days': days});

  Future<Map<String, dynamic>> importUsersCsv(String filePath) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    return _client.upload('/platform/admin/import/users/', form);
  }

  String ministryReportUrl({String format = 'csv'}) =>
      '${Env.origin}/api/v1/platform/reports/ministry/?format=$format';

  String zoneReportUrl(String zoneCode, {String format = 'csv'}) =>
      '${Env.origin}/api/v1/platform/reports/zone/$zoneCode/?format=$format';

  Future<String> downloadMinistryReport({String format = 'csv'}) =>
      _client.downloadText('/platform/reports/ministry/', query: {'format': format});

  Future<String> downloadZoneReport(String zoneCode, {String format = 'csv'}) =>
      _client.downloadText('/platform/reports/zone/$zoneCode/', query: {'format': format});

  Future<Map<String, Map<String, dynamic>>> fetchExternalApiStatus() async {
    final results = await Future.wait([
      weatherStatus(),
      sentinelStatus(),
      assistantStatus(),
      nasaCatalogSummary(),
      fetchMlMetrics(),
    ]);
    return {
      'weather': Map<String, dynamic>.from(results[0] as Map),
      'sentinel': Map<String, dynamic>.from(results[1] as Map),
      'assistant': Map<String, dynamic>.from(results[2] as Map),
      'nasa': Map<String, dynamic>.from(results[3] as Map),
      'ml': Map<String, dynamic>.from(results[4] as Map),
    };
  }
}
