import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:merabriar/config/router.dart';

void main() {
  // ══════════════════════════════════════════════════════════════
  // AppRoutes constants
  // ══════════════════════════════════════════════════════════════

  group('AppRoutes', () {
    test('splash route is /', () {
      expect(AppRoutes.splash, '/');
    });

    test('login route is /login', () {
      expect(AppRoutes.login, '/login');
    });

    test('chats route is /chats', () {
      expect(AppRoutes.chats, '/chats');
    });

    test('chat route pattern includes recipientId param', () {
      expect(AppRoutes.chat, '/chats/:recipientId');
    });

    test('contact route pattern includes userId param', () {
      expect(AppRoutes.contact, '/contact/:userId');
    });

    test('settings route is /settings', () {
      expect(AppRoutes.settings, '/settings');
    });
  });

  // ══════════════════════════════════════════════════════════════
  // AppRouter configuration
  // ══════════════════════════════════════════════════════════════

  group('appRouter', () {
    test('has all expected route paths', () {
      final routes = _extractRoutePaths(appRouter.configuration.routes);

      expect(routes, contains('/'));
      expect(routes, contains('/login'));
      expect(routes, contains('/chats'));
      expect(routes, contains(':recipientId')); // sub-route
      expect(routes, contains('/contact/:userId'));
      expect(routes, contains('/settings'));
    });
  });
}

/// Recursively extract paths from route configuration
List<String> _extractRoutePaths(List<RouteBase> routes) {
  final paths = <String>[];
  for (final route in routes) {
    if (route is GoRoute) {
      paths.add(route.path);
      paths.addAll(_extractRoutePaths(route.routes));
    }
  }
  return paths;
}
