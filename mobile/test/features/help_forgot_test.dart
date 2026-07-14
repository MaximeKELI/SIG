import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sig_sols_mobile/core/api/api_client.dart';
import 'package:sig_sols_mobile/features/auth/forgot_password_screen.dart';
import 'package:sig_sols_mobile/features/help/help_screen.dart';
import 'package:sig_sols_mobile/services/sig_api.dart';

import '../helpers/fake_token_storage.dart';

void main() {
  testWidgets('HelpScreen affiche les sections du guide web', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: HelpScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Guide rapide SIG Sols Togo'), findsOneWidget);
    expect(find.text('Carte'), findsOneWidget);
    expect(find.text('Gestes mobile'), findsOneWidget);
    expect(find.text('DUSOL'), findsOneWidget);
    expect(find.text('SIG-SOL'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.textContaining('API'), findsWidgets);
    expect(find.textContaining('Crédit'), findsOneWidget);
  });

  testWidgets('ForgotPasswordScreen propose le lien reset-password', (tester) async {
    final api = ApiClient(storage: FakeTokenStorage());
    final router = GoRouter(
      initialLocation: '/forgot',
      routes: [
        GoRoute(
          path: '/forgot',
          builder: (_, __) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: '/reset-password',
          builder: (_, __) => const Scaffold(body: Text('reset-ok')),
        ),
      ],
    );

    await tester.pumpWidget(
      Provider.value(
        value: SigApi(api),
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    expect(find.text('Envoyer le lien'), findsOneWidget);
    await tester.tap(find.textContaining('réinitialiser'));
    await tester.pumpAndSettle();
    expect(find.text('reset-ok'), findsOneWidget);
  });
}
