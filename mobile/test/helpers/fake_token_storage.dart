import 'package:sig_sols_mobile/core/storage/token_storage.dart';

/// Stockage mémoire pour les tests unitaires.
class FakeTokenStorage extends TokenStorage {
  FakeTokenStorage()
      : _data = {},
        super(enableSecure: false);

  final Map<String, String> _data;

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _data.remove('sig_sols_token');
    _data.remove('sig_sols_refresh');
    _data.remove('sig_sols_user');
    _data.remove('sig_sols_user_json');
  }
}
