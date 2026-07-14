import 'package:flutter_test/flutter_test.dart';
import 'package:sig_sols_mobile/core/i18n/app_strings.dart';
import 'package:sig_sols_mobile/models/live_peer.dart';

void main() {
  test('AppStrings FR et EN', () {
    expect(AppStrings.t('fr', 'nav.map'), 'Carte');
    expect(AppStrings.t('en', 'nav.map'), 'Map');
    expect(
      AppStrings.t('en', 'map.points', vars: {'n': '12'}),
      '12 soil points',
    );
    expect(AppStrings.langToggleLabel('fr'), 'EN');
    expect(AppStrings.langToggleLabel('en'), 'EE');
    expect(AppStrings.langToggleLabel('ee'), 'KAB');
    expect(AppStrings.langToggleLabel('kab'), 'FR');
  });

  test('LivePeer fromJson', () {
    final p = LivePeer.fromJson({
      'user_id': 3,
      'username': 'agent1',
      'display_name': 'Agent Un',
      'role': 'agent',
      'lat': 6.4,
      'lon': 1.35,
      'accuracy_m': 12.5,
    });
    expect(p.userId, 3);
    expect(p.label, 'Agent Un');
    expect(p.lat, 6.4);
  });
}
