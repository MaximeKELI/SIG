import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sig_sols_mobile/core/api/api_client.dart';
import 'package:sig_sols_mobile/features/search/search_screen.dart';
import 'package:sig_sols_mobile/services/sig_api.dart';

import '../helpers/fake_token_storage.dart';

void main() {
  testWidgets('SearchScreen affiche résultats et icônes par type', (tester) async {
    final client = ApiClient(storage: FakeTokenStorage());
    client.dio.httpClientAdapter = _SearchAdapter();
    final api = SigApi(client);

    final router = GoRouter(
      initialLocation: '/search',
      routes: [
        GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
        GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('map'))),
        GoRoute(
          path: '/community/profil/:username',
          builder: (_, state) => Scaffold(
            body: Text('profil:${state.pathParameters['username']}'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      Provider.value(
        value: api,
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.enterText(find.byType(TextField), 'sol');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Point A'), findsOneWidget);
    expect(find.text('Vidéo B'), findsOneWidget);
    expect(find.text('Agent C'), findsOneWidget);

    await tester.tap(find.text('Agent C'));
    await tester.pumpAndSettle();
    expect(find.text('profil:agentc'), findsOneWidget);
  });

  testWidgets('SearchScreen point navigue vers /?point=', (tester) async {
    final client = ApiClient(storage: FakeTokenStorage());
    client.dio.httpClientAdapter = _SearchAdapter();
    final api = SigApi(client);

    String? lastLocation;
    final router = GoRouter(
      initialLocation: '/search',
      routes: [
        GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
        GoRoute(
          path: '/',
          builder: (context, state) {
            lastLocation = state.uri.toString();
            return Scaffold(body: Text('map:${state.uri.queryParameters['point']}'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      Provider.value(
        value: api,
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.enterText(find.byType(TextField), 'sol');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Point A'));
    await tester.pumpAndSettle();

    expect(lastLocation, contains('point=7'));
    expect(find.text('map:7'), findsOneWidget);
  });
}

class _SearchAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.contains('/platform/search/') ||
        options.path.contains('search')) {
      return ResponseBody.fromString(
        '''
        {"results":[
          {"type":"point","id":7,"title":"Point A","subtitle":"pH 6"},
          {"type":"video","id":9,"title":"Vidéo B","subtitle":"agronomie"},
          {"type":"user","id":3,"title":"Agent C","username":"agentc","subtitle":"agent"}
        ]}
        ''',
        200,
        headers: {Headers.contentTypeHeader: ['application/json']},
      );
    }
    return ResponseBody.fromString('{"detail":"not found"}', 404);
  }
}
