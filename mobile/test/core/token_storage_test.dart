import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sig_sols_mobile/core/storage/token_storage.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('write read delete', () async {
    final storage = TokenStorage(enableSecure: false);
    await storage.write('sig_sols_token', 'abc123');
    expect(await storage.read('sig_sols_token'), 'abc123');
    await storage.delete('sig_sols_token');
    expect(await storage.read('sig_sols_token'), isNull);
  });

  test('deleteAll supprime les clés session', () async {
    final storage = TokenStorage(enableSecure: false);
    await storage.write('sig_sols_token', 't');
    await storage.write('sig_sols_refresh', 'r');
    await storage.write('sig_sols_user', '{}');
    await storage.write('sig_sols_user_json', '{}');
    await storage.deleteAll();
    expect(await storage.read('sig_sols_token'), isNull);
    expect(await storage.read('sig_sols_refresh'), isNull);
    expect(await storage.read('sig_sols_user'), isNull);
    expect(await storage.read('sig_sols_user_json'), isNull);
  });
}
