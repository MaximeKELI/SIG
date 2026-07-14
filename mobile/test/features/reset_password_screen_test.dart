import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sig_sols_mobile/core/api/api_client.dart';
import 'package:sig_sols_mobile/features/auth/reset_password_screen.dart';
import 'package:sig_sols_mobile/services/sig_api.dart';

import '../helpers/fake_token_storage.dart';

void main() {
  testWidgets('ResetPasswordScreen affiche les champs de réinitialisation', (
    tester,
  ) async {
    final api = ApiClient(storage: FakeTokenStorage());
    await tester.pumpWidget(
      Provider(
        create: (_) => SigApi(api),
        child: const MaterialApp(home: ResetPasswordScreen()),
      ),
    );

    expect(find.text('Code de réinitialisation'), findsOneWidget);
    expect(find.text('Confirmer le mot de passe'), findsOneWidget);
    expect(find.text('Réinitialiser le mot de passe'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(3));
  });
}
