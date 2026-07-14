import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/activity/activity_tracker.dart';
import '../core/api/api_client.dart';
import '../core/auth/auth_service.dart';
import '../core/i18n/locale_service.dart';
import '../core/live/live_location_service.dart';
import '../core/offline/offline_sync_service.dart';
import '../core/theme/theme_service.dart';
import '../services/sig_api.dart';
import 'router.dart';

class SigSolsApp extends StatefulWidget {
  const SigSolsApp({super.key});

  @override
  State<SigSolsApp> createState() => _SigSolsAppState();
}

class _SigSolsAppState extends State<SigSolsApp> {
  late final ApiClient _apiClient;
  late final AuthService _authService;
  late final SigApi _sigApi;
  late final OfflineSyncService _offlineSync;
  late final ThemeService _themeService;
  late final LocaleService _localeService;
  late final ActivityTracker _activity;
  late final LiveLocationService _liveLocation;
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    _authService = AuthService(_apiClient);
    _sigApi = SigApi(_apiClient);
    _offlineSync = OfflineSyncService(api: _sigApi, auth: _authService);
    _themeService = ThemeService();
    _localeService = LocaleService();
    _activity = ActivityTracker(_sigApi);
    _liveLocation = LiveLocationService(api: _sigApi, client: _apiClient);
    Future.wait([_authService.init(), _themeService.init(), _localeService.init()]).then((_) async {
      await _offlineSync.init();
      _authService.addListener(_onAuthChanged);
      _activity.init();
      if (mounted) setState(() => _router = createRouter(_authService));
    });
  }

  void _onAuthChanged() {
    if (_authService.isAuthenticated) {
      _offlineSync.sync();
      _activity.track('auth', detail: {'action': 'session'}, category: 'auth');
    } else {
      _activity.flush();
      _liveLocation.stopSharing();
      _liveLocation.disconnectWebSocket();
    }
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthChanged);
    _offlineSync.dispose();
    _activity.dispose();
    _liveLocation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_router == null) {
      return MaterialApp(
        theme: _themeService.theme,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/logo-dusol.png',
                  height: 72,
                  errorBuilder: (_, __, ___) => const Icon(Icons.landscape, size: 72),
                ),
                const SizedBox(height: 20),
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                const Text('SIG Sols Togo'),
              ],
            ),
          ),
        ),
      );
    }

    return MultiProvider(
      providers: [
        Provider.value(value: _apiClient),
        ChangeNotifierProvider.value(value: _authService),
        Provider.value(value: _sigApi),
        Provider.value(value: _activity),
        ChangeNotifierProvider.value(value: _themeService),
        ChangeNotifierProvider.value(value: _localeService),
        ChangeNotifierProvider.value(value: _liveLocation),
        ChangeNotifierProvider.value(value: _offlineSync),
      ],
      child: Consumer2<ThemeService, LocaleService>(
        builder: (_, theme, locale, __) => MaterialApp.router(
          title: locale.t('app.title'),
          theme: theme.theme,
          locale: Locale(locale.lang),
          routerConfig: _router!,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
