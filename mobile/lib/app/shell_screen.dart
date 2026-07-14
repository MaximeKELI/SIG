import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/activity/activity_tracker.dart';
import '../core/auth/auth_service.dart';
import '../core/i18n/locale_service.dart';
import '../core/theme/theme_service.dart';
import '../features/assistant/assistant_screen.dart';
import '../features/community/community_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/map/map_screen.dart';
import '../features/onboarding/onboarding_sheet.dart';
import '../features/profile/profile_screen.dart';
import '../features/quiz/quiz_screen.dart';
import '../features/sheets/sheets_screen.dart';
import '../features/videos/videos_screen.dart';
import '../services/sig_api.dart';
import '../shared/widgets/offline_banner.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key, required this.child});

  final Widget child;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _loadUnread();
    _showOnboardingIfNeeded();
  }

  Future<void> _loadUnread() async {
    try {
      final n = await context.read<SigApi>().unreadNotifications();
      if (mounted) setState(() => _unread = n);
    } catch (_) {}
  }

  Future<void> _showOnboardingIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(OnboardingSheet.preferenceKey) == true || !mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true,
        builder: (_) => const OnboardingSheet(),
      );
    });
  }

  int _indexFromLocation(String loc) {
    if (loc.startsWith('/dashboard')) return 1;
    if (loc.startsWith('/quiz')) return 2;
    if (loc.startsWith('/sheets')) return 3;
    if (loc.startsWith('/videos')) return 4;
    if (loc.startsWith('/shorts')) return 5;
    if (loc.startsWith('/community')) return 6;
    if (loc.startsWith('/assistant')) return 7;
    if (loc.startsWith('/profile')) return 8;
    return 0;
  }

  void _go(int index) {
    const routes = [
      '/',
      '/dashboard',
      '/quiz',
      '/sheets',
      '/videos',
      '/shorts',
      '/community',
      '/assistant',
      '/profile',
    ];
    const names = [
      'map',
      'dashboard',
      'quiz',
      'sheets',
      'videos',
      'shorts',
      'community',
      'assistant',
      'profile',
    ];
    context.read<ActivityTracker>().trackNav(names[index]);
    context.go(routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    final index = _indexFromLocation(loc);
    final user = context.watch<AuthService>().user;
    final i18n = context.watch<LocaleService>();

    return Scaffold(
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Text(
                '${i18n.t('app.title')}\n${user?.displayName ?? ''}',
                style: const TextStyle(fontSize: 18),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: Text(i18n.t('drawer.search')),
              onTap: () {
                Navigator.pop(context);
                context.push('/search');
              },
            ),
            ListTile(
              leading: Badge(
                label: Text('$_unread'),
                isLabelVisible: _unread > 0,
                child: const Icon(Icons.notifications),
              ),
              title: Text(i18n.t('drawer.notifications')),
              onTap: () {
                Navigator.pop(context);
                context.push('/notifications').then((_) => _loadUnread());
              },
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_customize),
              title: Text(i18n.t('drawer.myspace')),
              onTap: () {
                Navigator.pop(context);
                context.push('/my-dashboard');
              },
            ),
            if (user?.isAdmin == true)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: Text(i18n.t('drawer.admin')),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/admin');
                },
              ),
            ListTile(
              leading: const Icon(Icons.help),
              title: Text(i18n.t('drawer.help')),
              onTap: () {
                Navigator.pop(context);
                context.push('/help');
              },
            ),
            Consumer<ThemeService>(
              builder:
                  (_, theme, __) => SwitchListTile(
                    secondary: Icon(
                      theme.isDark ? Icons.dark_mode : Icons.light_mode,
                    ),
                    title: Text(i18n.t('drawer.theme')),
                    value: !theme.isDark,
                    onChanged: (_) => theme.toggle(),
                  ),
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(i18n.t('drawer.lang')),
              trailing: Text(
                i18n.langToggleLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () => context.read<LocaleService>().toggle(),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: Text(i18n.t('app.title')),
        actions: [
          IconButton(
            icon: Badge(
              label: Text('$_unread'),
              isLabelVisible: _unread > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed:
                () => context.push('/notifications').then((_) => _loadUnread()),
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: i18n.t('parcel.tooltip'),
            onPressed: () => context.push('/parcel'),
          ),
        ],
      ),
      body: Column(
        children: [const OfflineBanner(), Expanded(child: widget.child)],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index.clamp(0, 8),
        onDestinationSelected: _go,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.map),
            label: i18n.t('nav.map'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.dashboard),
            label: i18n.t('nav.dashboard'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.quiz),
            label: i18n.t('nav.quiz'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book),
            label: i18n.t('nav.sheets'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.video_library),
            label: i18n.t('nav.videos'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.play_circle),
            label: i18n.t('nav.shorts'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.people),
            label: i18n.t('nav.community'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.smart_toy),
            label: i18n.t('nav.assistant'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person),
            label: i18n.t('nav.profile'),
          ),
        ],
      ),
    );
  }
}

class ShellIndexScreen extends StatelessWidget {
  const ShellIndexScreen({super.key, required this.route});

  final String route;

  @override
  Widget build(BuildContext context) {
    switch (route) {
      case '/':
        return const MapScreen();
      case '/dashboard':
        return const DashboardScreen();
      case '/quiz':
        return const QuizScreen();
      case '/sheets':
        return const SheetsScreen();
      case '/videos':
        return const VideosScreen(kind: 'video');
      case '/shorts':
        return const VideosScreen(kind: 'short');
      case '/community':
        return const CommunityScreen();
      case '/assistant':
        return const AssistantScreen();
      case '/profile':
        return const ProfileScreen();
      default:
        return const MapScreen();
    }
  }
}
