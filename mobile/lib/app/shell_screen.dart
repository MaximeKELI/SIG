import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/activity/activity_tracker.dart';
import '../core/auth/auth_service.dart';
import '../core/i18n/locale_service.dart';
import '../core/theme/app_theme.dart';
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
import '../shared/widgets/dusol_ui.dart';
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

  /// 0 Carte · 1 Tableau · 2 Médias · 3 Communauté · 4 Plus
  int _indexFromLocation(String loc) {
    if (loc.startsWith('/dashboard')) return 1;
    if (loc.startsWith('/videos') || loc.startsWith('/shorts')) return 2;
    if (loc.startsWith('/community')) return 3;
    if (loc.startsWith('/quiz') ||
        loc.startsWith('/sheets') ||
        loc.startsWith('/assistant') ||
        loc.startsWith('/profile')) {
      return 4;
    }
    return 0;
  }

  String _titleFor(String loc, LocaleService i18n) {
    if (loc.startsWith('/dashboard')) return i18n.t('nav.dashboard');
    if (loc.startsWith('/quiz')) return i18n.t('nav.quiz');
    if (loc.startsWith('/sheets')) return i18n.t('nav.sheets');
    if (loc.startsWith('/videos')) return i18n.t('nav.videos');
    if (loc.startsWith('/shorts')) return i18n.t('nav.shorts');
    if (loc.startsWith('/community')) return i18n.t('nav.community');
    if (loc.startsWith('/assistant')) return i18n.t('nav.assistant');
    if (loc.startsWith('/profile')) return i18n.t('nav.profile');
    return i18n.t('nav.map');
  }

  void _goPrimary(int index) {
    if (index == 4) {
      _openPlusSheet();
      return;
    }
    const routes = ['/', '/dashboard', '/videos', '/community'];
    const names = ['map', 'dashboard', 'videos', 'community'];
    context.read<ActivityTracker>().trackNav(names[index]);
    context.go(routes[index]);
  }

  Future<void> _openPlusSheet() async {
    final i18n = context.read<LocaleService>();
    final loggedIn = context.read<AuthService>().isAuthenticated;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        Widget tile(IconData icon, String label, String route, String track) {
          // Routes hors Shell : push pour garder un retour arrière.
          const pushRoutes = {
            '/my-dashboard',
            '/admin',
            '/help',
            '/notifications',
            '/parcel',
            '/search',
          };
          return ListTile(
            leading: Icon(icon, color: AppTheme.gold400),
            title: Text(label),
            onTap: () {
              Navigator.pop(ctx);
              context.read<ActivityTracker>().trackNav(track);
              if (pushRoutes.contains(route)) {
                context.push(route);
              } else {
                context.go(route);
              }
            },
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Explorer',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: AppTheme.gold300,
                          ),
                    ),
                  ),
                ),
                tile(Icons.quiz_outlined, i18n.t('nav.quiz'), '/quiz', 'quiz'),
                tile(Icons.menu_book_outlined, i18n.t('nav.sheets'), '/sheets', 'sheets'),
                tile(Icons.bolt_outlined, i18n.t('nav.shorts'), '/shorts', 'shorts'),
                tile(Icons.smart_toy_outlined, i18n.t('nav.assistant'), '/assistant', 'assistant'),
                tile(Icons.person_outline, i18n.t('nav.profile'), '/profile', 'profile'),
                if (loggedIn)
                  tile(Icons.dashboard_customize_outlined, i18n.t('drawer.myspace'), '/my-dashboard', 'myspace'),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    final index = _indexFromLocation(loc);
    final user = context.watch<AuthService>().user;
    final loggedIn = context.watch<AuthService>().isAuthenticated;
    final i18n = context.watch<LocaleService>();
    final hideAppBar = loc.startsWith('/shorts');

    return Scaffold(
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      UserAvatar(
                        label: user?.displayName ?? '?',
                        photoUrl: loggedIn ? user?.profilePhotoUrl : null,
                        radius: 22,
                        onTap: () {
                          Navigator.pop(context);
                          context.go('/profile');
                        },
                      ),
                      const SizedBox(width: 12),
                      const Expanded(child: BrandTitleSpin()),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    user?.displayName ?? (loggedIn ? '' : 'Visiteur'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                  ),
                ],
              ),
            ),
            if (!loggedIn)
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Connexion'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/login');
                },
              ),
            if (loggedIn)
              ListTile(
                leading: const Icon(Icons.search),
                title: Text(i18n.t('drawer.search')),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/search');
                },
              ),
            if (loggedIn)
              ListTile(
                leading: Badge(
                  label: Text('$_unread'),
                  isLabelVisible: _unread > 0,
                  child: const Icon(Icons.notifications_outlined),
                ),
                title: Text(i18n.t('drawer.notifications')),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/notifications').then((_) => _loadUnread());
                },
              ),
            if (loggedIn)
              ListTile(
                leading: const Icon(Icons.dashboard_customize_outlined),
                title: Text(i18n.t('drawer.myspace')),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/my-dashboard');
                },
              ),
            ListTile(
              leading: const Icon(Icons.quiz_outlined),
              title: Text(i18n.t('nav.quiz')),
              onTap: () {
                Navigator.pop(context);
                context.go('/quiz');
              },
            ),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(i18n.t('nav.sheets')),
              onTap: () {
                Navigator.pop(context);
                context.go('/sheets');
              },
            ),
            ListTile(
              leading: const Icon(Icons.smart_toy_outlined),
              title: Text(i18n.t('nav.assistant')),
              onTap: () {
                Navigator.pop(context);
                context.go('/assistant');
              },
            ),
            if (user?.isAdmin == true)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: Text(i18n.t('drawer.admin')),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/admin');
                },
              ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: Text(i18n.t('drawer.help')),
              onTap: () {
                Navigator.pop(context);
                context.push('/help');
              },
            ),
            const Divider(),
            Consumer<ThemeService>(
              builder:
                  (_, theme, __) => SwitchListTile(
                    secondary: Icon(
                      theme.isDark ? Icons.dark_mode : Icons.light_mode,
                    ),
                    title: Text(i18n.t('drawer.theme')),
                    subtitle: Text(theme.isDark ? 'Sombre' : 'Clair'),
                    value: theme.isDark,
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
      appBar: hideAppBar
          ? null
          : AppBar(
              titleSpacing: 12,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandTitleSpin(),
                  Text(
                    _titleFor(loc, i18n),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              actions: [
                if (!loggedIn)
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Connexion'),
                  ),
                if (loggedIn)
                  IconButton(
                    icon: Badge(
                      label: Text('$_unread'),
                      isLabelVisible: _unread > 0,
                      child: const Icon(Icons.notifications_outlined),
                    ),
                    onPressed: () => context
                        .push('/notifications')
                        .then((_) => _loadUnread()),
                  ),
                if (loggedIn)
                  IconButton(
                    icon: const Icon(Icons.map_outlined),
                    tooltip: i18n.t('parcel.tooltip'),
                    onPressed: () => context.push('/parcel'),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 10, left: 2),
                  child: Center(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => context.go('/profile'),
                        child: Tooltip(
                          message: loggedIn ? 'Mon profil' : 'Profil / Connexion',
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.gold500,
                                width: 1.6,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.gold500.withValues(
                                    alpha: 0.35,
                                  ),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: UserAvatar(
                              label: user?.displayName ?? '?',
                              photoUrl:
                                  loggedIn ? user?.profilePhotoUrl : null,
                              radius: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
      body: Column(
        children: [const OfflineBanner(), Expanded(child: widget.child)],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index.clamp(0, 4),
        onDestinationSelected: _goPrimary,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: const Icon(Icons.map),
            label: i18n.t('nav.map'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard),
            label: i18n.t('nav.dashboard'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.video_library_outlined),
            selectedIcon: const Icon(Icons.video_library),
            label: i18n.t('nav.videos'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.people_outline),
            selectedIcon: const Icon(Icons.people),
            label: i18n.t('nav.community'),
          ),
          const NavigationDestination(
            icon: Icon(Icons.apps_outlined),
            selectedIcon: Icon(Icons.apps),
            label: 'Plus',
          ),
        ],
      ),
    );
  }
}

class ShellIndexScreen extends StatelessWidget {
  const ShellIndexScreen({
    super.key,
    required this.route,
    this.focusPointId,
  });

  final String route;
  final int? focusPointId;

  @override
  Widget build(BuildContext context) {
    switch (route) {
      case '/':
        return MapScreen(focusPointId: focusPointId);
      case '/dashboard':
        return const DashboardScreen();
      case '/quiz':
        return const QuizScreen();
      case '/sheets':
        return const SheetsScreen();
      case '/videos':
        return const _MediaShell(kind: 'video');
      case '/shorts':
        return const _MediaShell(kind: 'short');
      case '/community':
        return const CommunityScreen();
      case '/assistant':
        return const AssistantScreen();
      case '/profile':
        return const ProfileScreen();
      default:
        return MapScreen(focusPointId: focusPointId);
    }
  }
}

/// Médias : bascule Vidéos / Shorts + écran contenu.
class _MediaShell extends StatelessWidget {
  const _MediaShell({required this.kind});

  final String kind;

  @override
  Widget build(BuildContext context) {
    final isShort = kind == 'short';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'video',
                label: Text('Vidéos'),
                icon: Icon(Icons.video_library_outlined, size: 18),
              ),
              ButtonSegment(
                value: 'short',
                label: Text('Shorts'),
                icon: Icon(Icons.bolt_outlined, size: 18),
              ),
            ],
            selected: {isShort ? 'short' : 'video'},
            onSelectionChanged: (s) {
              final next = s.first;
              if (next == 'short') {
                context.go('/shorts');
              } else {
                context.go('/videos');
              }
            },
          ),
        ),
        Expanded(child: VideosScreen(kind: kind)),
      ],
    );
  }
}
