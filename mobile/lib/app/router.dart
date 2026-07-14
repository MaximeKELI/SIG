import 'package:go_router/go_router.dart';

import '../core/auth/auth_service.dart';
import '../features/admin/admin_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/reset_password_screen.dart';
import '../features/community/public_profile_screen.dart';
import '../features/help/help_screen.dart';
import '../features/my_dashboard/my_dashboard_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/parcel/parcel_screen.dart';
import '../features/search/search_screen.dart';
import 'shell_screen.dart';

GoRouter createRouter(AuthService auth) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: auth,
    redirect: (context, state) {
      final loggedIn = auth.isAuthenticated;
      final loc = state.matchedLocation;
      final onAuth =
          loc == '/login' ||
          loc == '/register' ||
          loc == '/forgot-password' ||
          loc == '/reset-password';
      // Parité web : navigation publique (carte, dashboard, fiches, médias…)
      final guestOk =
          loc == '/' ||
          loc.startsWith('/dashboard') ||
          loc.startsWith('/sheets') ||
          loc.startsWith('/videos') ||
          loc.startsWith('/shorts') ||
          loc.startsWith('/community') ||
          loc.startsWith('/help') ||
          loc.startsWith('/quiz');
      final needsAuth =
          loc.startsWith('/admin') ||
          loc.startsWith('/profile') ||
          loc.startsWith('/my-dashboard') ||
          loc.startsWith('/notifications') ||
          loc.startsWith('/assistant') ||
          loc.startsWith('/parcel') ||
          loc.startsWith('/search');
      if (!loggedIn && needsAuth) return '/login';
      if (!loggedIn && !onAuth && !guestOk && !needsAuth) return '/login';
      if (loggedIn && loc == '/login') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder:
            (_, state) => ResetPasswordScreen(
              initialToken: state.uri.queryParameters['token'],
            ),
      ),
      GoRoute(
        path: '/community/profil/:username',
        builder:
            (_, state) => PublicProfileScreen(
              username: state.pathParameters['username']!,
            ),
      ),
      GoRoute(path: '/parcel', builder: (_, __) => const ParcelScreen()),
      GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/my-dashboard',
        builder: (_, __) => const MyDashboardScreen(),
      ),
      GoRoute(path: '/admin', builder: (_, __) => const AdminScreen()),
      GoRoute(path: '/help', builder: (_, __) => const HelpScreen()),
      ShellRoute(
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, state) {
              final raw = state.uri.queryParameters['point'];
              return ShellIndexScreen(
                route: '/',
                focusPointId: raw != null ? int.tryParse(raw) : null,
              );
            },
          ),
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => const ShellIndexScreen(route: '/dashboard'),
          ),
          GoRoute(
            path: '/quiz',
            builder: (_, __) => const ShellIndexScreen(route: '/quiz'),
          ),
          GoRoute(
            path: '/sheets',
            builder: (_, __) => const ShellIndexScreen(route: '/sheets'),
          ),
          GoRoute(
            path: '/videos',
            builder: (_, __) => const ShellIndexScreen(route: '/videos'),
          ),
          GoRoute(
            path: '/shorts',
            builder: (_, __) => const ShellIndexScreen(route: '/shorts'),
          ),
          GoRoute(
            path: '/community',
            builder: (_, __) => const ShellIndexScreen(route: '/community'),
          ),
          GoRoute(
            path: '/assistant',
            builder: (_, __) => const ShellIndexScreen(route: '/assistant'),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const ShellIndexScreen(route: '/profile'),
          ),
        ],
      ),
    ],
  );
}
