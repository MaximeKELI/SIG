import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sig_sols_mobile/services/sig_api.dart';
import 'package:sig_sols_mobile/core/api/api_client.dart';
import 'package:sig_sols_mobile/features/my_dashboard/my_dashboard_screen.dart';

class _DashApi extends SigApi {
  _DashApi() : super(ApiClient());

  @override
  Future<Map<String, dynamic>> personalDashboard() async => {
    'display_name': 'Agent Maritime',
    'username': 'agent',
    'soil_points_submitted': 12,
    'videos': {'published': 3},
    'quiz': {
      'sessions_completed': 5,
      'best_score': 28,
      'badges': ['Premier pas', 'Expert sols'],
    },
    'social': {'followers': 4, 'following': 2},
  };
}

void main() {
  testWidgets('Mon espace maps API fields like web', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      Provider<SigApi>.value(
        value: _DashApi(),
        child: const MaterialApp(home: MyDashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Agent Maritime'), findsOneWidget);
    expect(find.text('Points sol'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Vidéos publiées'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Meilleur score'), findsOneWidget);
    expect(find.text('28'), findsOneWidget);
    expect(find.text('Premier pas'), findsOneWidget);
  });
}
