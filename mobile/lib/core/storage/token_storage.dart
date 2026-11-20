import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stockage session : tokens JWT en stockage sécurisé (Keystore/Keychain),
/// préférences non sensibles en SharedPreferences.
class TokenStorage {
  TokenStorage({
    FlutterSecureStorage? secure,
    SharedPreferences? prefs,
    bool enableSecure = true,
  })  : _secure = enableSecure
            ? (secure ??
                const FlutterSecureStorage(
                  aOptions: AndroidOptions(encryptedSharedPreferences: true),
                ))
            : null,
        _prefs = prefs;

  static const _sensitiveKeys = {
    'sig_sols_token',
    'sig_sols_refresh',
  };

  final FlutterSecureStorage? _secure;
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _shared async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<void> write(String key, String value) async {
    if (_sensitiveKeys.contains(key) && _secure != null) {
      await _secure.write(key: key, value: value);
      final p = await _shared;
      await p.remove(key);
      return;
    }
    final p = await _shared;
    await p.setString(key, value);
  }

  Future<String?> read(String key) async {
    if (_sensitiveKeys.contains(key) && _secure != null) {
      final secureVal = await _secure.read(key: key);
      if (secureVal != null && secureVal.isNotEmpty) return secureVal;
      final p = await _shared;
      final legacy = p.getString(key);
      if (legacy != null && legacy.isNotEmpty) {
        await _secure.write(key: key, value: legacy);
        await p.remove(key);
        return legacy;
      }
      return null;
    }
    final p = await _shared;
    return p.getString(key);
  }

  Future<void> delete(String key) async {
    if (_secure != null && _sensitiveKeys.contains(key)) {
      await _secure.delete(key: key);
    }
    final p = await _shared;
    await p.remove(key);
  }

  Future<void> deleteAll() async {
    if (_secure != null) {
      for (final k in _sensitiveKeys) {
        await _secure.delete(key: k);
      }
    }
    final p = await _shared;
    await p.remove('sig_sols_token');
    await p.remove('sig_sols_refresh');
    await p.remove('sig_sols_user');
    await p.remove('sig_sols_user_json');
  }
}
