import 'dart:convert';

import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../storage/token_storage.dart';
import '../../models/user.dart';

class AuthService extends ChangeNotifier {
  AuthService(this._api);

  final ApiClient _api;
  final TokenStorage _storage = TokenStorage();

  static const _userKey = 'sig_sols_user_json';

  AppUser? _user;
  bool _loading = false;

  AppUser? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get loading => _loading;

  Future<void> init() async {
    _loading = true;
    notifyListeners();
    try {
      final raw = await _storage.read(_userKey);
      if (raw != null && await _api.isAuthenticated()) {
        _user = AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        try {
          final profile = await _api.fetchProfile();
          _user = AppUser.fromJson(profile);
          await _saveUser(_user!);
        } catch (_) {}
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _saveUser(AppUser user) async {
    await _storage.write(
      _userKey,
      jsonEncode({
        'id': user.id,
        'username': user.username,
        'email': user.email,
        'first_name': user.firstName,
        'last_name': user.lastName,
        'role': user.role,
        'organization': user.organization,
        'phone': user.phone,
        'pseudonym': user.pseudonym,
        'city': user.city,
        'region': user.region,
        'profession': user.profession,
        'bio': user.bio,
        'profile_photo_url': user.profilePhotoUrl,
        'profile_stats': user.profileStats,
        'consent_analytics': user.consentAnalytics,
      }),
    );
  }

  Future<AppUser> login(String username, String password) async {
    final data = await _api.login(username, password);
    _user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
    await _saveUser(_user!);
    notifyListeners();
    return _user!;
  }

  Future<void> register(Map<String, dynamic> payload) async {
    await _api.register(payload);
  }

  Future<void> logout() async {
    await _api.logout();
    await _storage.delete(_userKey);
    _user = null;
    notifyListeners();
  }

  Future<void> refreshFromJson(Map<String, dynamic> json) async {
    _user = AppUser.fromJson(json);
    await _saveUser(_user!);
    notifyListeners();
  }
}
