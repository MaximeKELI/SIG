import 'package:flutter_test/flutter_test.dart';
import 'package:sig_sols_mobile/core/api/api_client.dart';
import 'package:sig_sols_mobile/services/sig_api.dart';

import '../helpers/capturing_adapter.dart';
import '../helpers/fake_token_storage.dart';

void main() {
  late ApiClient client;
  late CapturingAdapter adapter;
  late SigApi api;

  setUp(() {
    client = ApiClient(storage: FakeTokenStorage());
    adapter = CapturingAdapter(response: {'ok': true});
    client.dio.httpClientAdapter = adapter;
    api = SigApi(client);
  });

  test('confirmPasswordReset envoie new_password + confirm', () async {
    await api.confirmPasswordReset(
      token: 'tok-abc',
      password: 'Secret123!',
      passwordConfirm: 'Secret123!',
    );

    final req = adapter.last!;
    expect(req.method, 'POST');
    expect(req.path, contains('/platform/password/reset/confirm/'));
    final body = req.body as Map<String, dynamic>;
    expect(body['token'], 'tok-abc');
    expect(body['new_password'], 'Secret123!');
    expect(body['new_password_confirm'], 'Secret123!');
    expect(body.containsKey('password'), isFalse);
  });

  test('changePassword envoie new_password_confirm', () async {
    await api.changePassword(
      oldPassword: 'old',
      newPassword: 'newpass99',
      newPasswordConfirm: 'newpass99',
    );

    final body = adapter.last!.body as Map<String, dynamic>;
    expect(body['old_password'], 'old');
    expect(body['new_password'], 'newpass99');
    expect(body['new_password_confirm'], 'newpass99');
  });

  test('fetchVideo appelle /videos/posts/:id/', () async {
    adapter = CapturingAdapter(response: {
      'id': 42,
      'title': 'Demo',
      'file_url': '/media/v.mp4',
    });
    client.dio.httpClientAdapter = adapter;
    api = SigApi(client);

    final post = await api.fetchVideo(42);
    expect(adapter.last!.path, contains('/videos/posts/42/'));
    expect(post['id'], 42);
    expect(post['title'], 'Demo');
  });

  test('zoneReportUrl inclut le code zone', () {
    final url = api.zoneReportUrl('CANTON-M01');
    expect(url, contains('/platform/reports/zone/CANTON-M01/'));
    expect(url, contains('format=csv'));
  });

  test('uploadVideo envoie tags (pas hashtags) en multipart', () async {
    adapter = CapturingAdapter(response: {
      'id': 7,
      'status': 'pending',
      'title': 'Demo sols',
    });
    client.dio.httpClientAdapter = adapter;
    api = SigApi(client);

    await api.uploadVideo(
      kind: 'short',
      title: 'Demo sols',
      tags: 'sols,nasa',
      fileBytes: [0, 0, 0, 1],
      fileName: 'clip',
    );

    final req = adapter.last!;
    expect(req.method, 'POST');
    expect(req.path, contains('/videos/posts/'));
    final raw = req.rawBody ?? '';
    expect(raw.contains('name="tags"'), isTrue);
    expect(raw.contains('name="hashtags"'), isFalse);
    expect(raw.contains('sols,nasa'), isTrue);
    expect(raw.contains('clip.mp4'), isTrue);
    expect(
      (req.contentType ?? '').toLowerCase(),
      isNot(contains('application/json')),
    );
  });
}
