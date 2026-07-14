import 'package:dio/dio.dart';

import '../config/env.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

/// Client HTTP JWT — même logique que frontend/js/core/apiClient.js
class ApiClient {
  ApiClient({TokenStorage? storage})
      : _storage = storage ?? TokenStorage(),
        _dio = Dio(BaseOptions(
          baseUrl: Env.apiBaseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
          headers: {'Content-Type': 'application/json'},
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _getAccessToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 &&
            !_isAuthPath(error.requestOptions.path) &&
            error.requestOptions.extra['retried'] != true) {
          try {
            await refreshAccessToken();
            final opts = error.requestOptions;
            opts.extra['retried'] = true;
            final token = await _getAccessToken();
            opts.headers['Authorization'] = 'Bearer $token';
            final response = await _dio.fetch(opts);
            return handler.resolve(response);
          } catch (_) {
            await clearSession();
          }
        }
        handler.next(error);
      },
    ));
  }

  static const _tokenKey = 'sig_sols_token';
  static const _refreshKey = 'sig_sols_refresh';
  static const _userKey = 'sig_sols_user';

  final Dio _dio;
  final TokenStorage _storage;

  Dio get dio => _dio;

  bool _isAuthPath(String path) => path.contains('/auth/token/');

  Future<String?> _getAccessToken() => _storage.read(_tokenKey);

  Future<String?> getAccessToken() => _getAccessToken();
  Future<String?> _getRefreshToken() => _storage.read(_refreshKey);

  Future<void> _persistSession(Map<String, dynamic> data) async {
    if (data['access'] != null) {
      await _storage.write(_tokenKey, data['access'].toString());
    }
    if (data['refresh'] != null) {
      await _storage.write(_refreshKey, data['refresh'].toString());
    }
    if (data['user'] != null) {
      await _storage.write(_userKey, data['user'].toString());
    }
  }

  Future<void> clearSession() async {
    await _storage.delete(_tokenKey);
    await _storage.delete(_refreshKey);
    await _storage.delete(_userKey);
  }

  Future<bool> isAuthenticated() async {
    final token = await _getAccessToken();
    return token != null && token.isNotEmpty;
  }

  String _parseError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      if (data['detail'] != null) return data['detail'].toString();
      return data.entries
          .map((entry) {
            final v = entry.value;
            if (v is List) return '${entry.key}: ${v.join(', ')}';
            return '${entry.key}: $v';
          })
          .join(' · ');
    }
    return e.message ?? 'Erreur réseau';
  }

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) async {
    try {
      final res = await _dio.get(path, queryParameters: query);
      return res.data as T;
    } on DioException catch (e) {
      throw ApiException(_parseError(e), statusCode: e.response?.statusCode);
    }
  }

  Future<T> post<T>(String path, {Object? data, Map<String, dynamic>? query}) async {
    try {
      final res = await _dio.post(path, data: data, queryParameters: query);
      if (res.statusCode == 204) return null as T;
      return res.data as T;
    } on DioException catch (e) {
      throw ApiException(_parseError(e), statusCode: e.response?.statusCode);
    }
  }

  Future<T> patch<T>(String path, {Object? data}) async {
    try {
      final res = await _dio.patch(path, data: data);
      return res.data as T;
    } on DioException catch (e) {
      throw ApiException(_parseError(e), statusCode: e.response?.statusCode);
    }
  }

  Future<T> delete<T>(String path, {Object? data}) async {
    try {
      final res = await _dio.delete(path, data: data);
      if (res.statusCode == 204) return null as T;
      return res.data as T;
    } on DioException catch (e) {
      throw ApiException(_parseError(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> upload(String path, FormData formData) async {
    try {
      final res = await _dio.post(
        path,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (e) {
      throw ApiException(_parseError(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final data = await post<Map<String, dynamic>>(
      '/auth/token/',
      data: {'username': username, 'password': password},
    );
    await _persistSession(data);
    return data;
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> payload) async {
    return post<Map<String, dynamic>>('/auth/register/', data: payload);
  }

  Future<void> logout() async {
    try {
      if (await isAuthenticated()) {
        await post('/auth/logout/');
      }
    } catch (_) {}
    await clearSession();
  }

  Future<void> refreshAccessToken() async {
    final refresh = await _getRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      throw ApiException('Session expirée — reconnectez-vous.');
    }
    final res = await _dio.post('/auth/token/refresh/', data: {'refresh': refresh});
    final data = res.data as Map<String, dynamic>;
    await _storage.write(_tokenKey, data['access'].toString());
    if (data['refresh'] != null) {
      await _storage.write(_refreshKey, data['refresh'].toString());
    }
  }

  Future<Map<String, dynamic>> fetchProfile() =>
      get<Map<String, dynamic>>('/auth/profile/');

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> payload) =>
      patch<Map<String, dynamic>>('/auth/profile/', data: payload);

  Future<Map<String, dynamic>> uploadProfilePhoto(String filePath) async {
    final form = FormData.fromMap({
      'photo': await MultipartFile.fromFile(filePath),
    });
    return upload('/auth/profile/photo/', form);
  }

  Future<Map<String, dynamic>> deleteProfilePhoto() =>
      delete<Map<String, dynamic>>('/auth/profile/photo/');

  Future<String> downloadText(String path, {Map<String, dynamic>? query}) async {
    try {
      final res = await _dio.get(
        path,
        queryParameters: query,
        options: Options(responseType: ResponseType.plain),
      );
      return res.data?.toString() ?? '';
    } on DioException catch (e) {
      throw ApiException(_parseError(e), statusCode: e.response?.statusCode);
    }
  }
}
