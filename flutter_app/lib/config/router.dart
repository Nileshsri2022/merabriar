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
      builder: (context, state) => const LoginScreen(),
    ),

    // ── Chat List (Home) ──
    GoRoute(
      path: AppRoutes.chats,
      builder: (context, state) => const ChatListScreen(),
      routes: [
        // ── Individual Chat ──
        GoRoute(
          path: ':recipientId',
          builder: (context, state) {
            final recipientId = state.pathParameters['recipientId']!;
            final recipientName =
                state.uri.queryParameters['name'] ?? 'Unknown';
            return ChatScreen(
              recipientId: recipientId,
              recipientName: recipientName,
            );
          },
        ),
      ],
    ),

    // ── Contact Profile ──
    GoRoute(
      path: '/contact/:userId',
      builder: (context, state) {
        final userId = state.pathParameters['userId']!;
        final displayName = state.uri.queryParameters['name'] ?? 'Unknown';
        return ContactProfileScreen(
          userId: userId,
          displayName: displayName,
        );
      },
    ),

    // ── Settings ──
    GoRoute(
      path: AppRoutes.settings,
      builder: (context, state) => const SettingsScreen(),
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
