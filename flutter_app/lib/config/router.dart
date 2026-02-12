import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/chat/screens/chat_list_screen.dart';
import '../features/chat/screens/chat_screen.dart';
import '../features/contacts/screens/contact_profile_screen.dart';
import '../features/settings/screens/settings_screen.dart';

/// Route names for type-safe navigation
abstract class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const chats = '/chats';
  static const chat = '/chats/:recipientId';
  static const contact = '/contact/:userId';
  static const settings = '/settings';
}

// ══════════════════════════════════════════════════════════════
// Custom Page Transitions
// ══════════════════════════════════════════════════════════════

const _transitionDuration = Duration(milliseconds: 300);

/// Fade transition — for root-level navigation (login ↔ chats)
CustomTransitionPage<void> _fadeTransition({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: _transitionDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

/// Slide-up transition — for push-style navigation (chat screen)
CustomTransitionPage<void> _slideUpTransition({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: _transitionDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

/// Slide-right transition — for detail screens (contact profile, settings)
CustomTransitionPage<void> _slideRightTransition({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: _transitionDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.25, 0),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

// ══════════════════════════════════════════════════════════════
// Router Configuration
// ══════════════════════════════════════════════════════════════

/// Centralized GoRouter configuration with auth guard.
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  debugLogDiagnostics: false,
  redirect: _authGuard,
  routes: [
    // ── Splash ──
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),

    // ── Auth ──
    GoRoute(
      path: AppRoutes.login,
      pageBuilder: (context, state) => _fadeTransition(
        state: state,
        child: const LoginScreen(),
      ),
    ),

    // ── Chat List (Home) ──
    GoRoute(
      path: AppRoutes.chats,
      pageBuilder: (context, state) => _fadeTransition(
        state: state,
        child: const ChatListScreen(),
      ),
      routes: [
        // ── Individual Chat ──
        GoRoute(
          path: ':recipientId',
          pageBuilder: (context, state) {
            final recipientId = state.pathParameters['recipientId']!;
            final recipientName =
                state.uri.queryParameters['name'] ?? 'Unknown';
            return _slideUpTransition(
              state: state,
              child: ChatScreen(
                recipientId: recipientId,
                recipientName: recipientName,
              ),
            );
          },
        ),
      ],
    ),

    // ── Contact Profile ──
    GoRoute(
      path: '/contact/:userId',
      pageBuilder: (context, state) {
        final userId = state.pathParameters['userId']!;
        final displayName = state.uri.queryParameters['name'] ?? 'Unknown';
        return _slideRightTransition(
          state: state,
          child: ContactProfileScreen(
            userId: userId,
            displayName: displayName,
          ),
        );
      },
    ),

    // ── Settings ──
    GoRoute(
      path: AppRoutes.settings,
      pageBuilder: (context, state) => _slideRightTransition(
        state: state,
        child: const SettingsScreen(),
      ),
    ),
  ],
);

/// Auth guard — redirects unauthenticated users to login,
/// but allows splash and login to be accessed freely.
String? _authGuard(BuildContext context, GoRouterState state) {
  final session = Supabase.instance.client.auth.currentSession;
  final isLoggedIn = session != null;

  final isOnSplash = state.matchedLocation == AppRoutes.splash;
  final isOnLogin = state.matchedLocation == AppRoutes.login;
  final isAuthRoute = isOnSplash || isOnLogin;

  // If not logged in and trying to access a protected route
  if (!isLoggedIn && !isAuthRoute) {
    return AppRoutes.login;
  }

  // Don't redirect if already on the right page
  return null;
}
