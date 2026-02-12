import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:merabriar/features/auth/screens/splash_screen.dart';
import 'package:merabriar/core/di/providers.dart';

/// Helper to build the SplashScreen in a testable widget tree.
Widget _buildTestSplash() {
  return ProviderScope(
    overrides: [
      initializeCoreProvider.overrideWith((ref) async {}),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const SplashScreen(),
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) => const Scaffold(body: Text('Login')),
          ),
        ],
      ),
    ),
  );
}

void main() {
  group('SplashScreen Widget', () {
    testWidgets('renders app name, tagline, and indicators', (tester) async {
      await tester.pumpWidget(_buildTestSplash());

      // Pump enough frames for the splash animation but don't settle (pending timers)
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('MeraBriar'), findsOneWidget);
      expect(find.text('Secure. Private. Yours.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.eco), findsOneWidget);
      expect(find.byIcon(Icons.memory), findsOneWidget);

      // Let the 2-second _initialize() timer complete so the test doesn't leave pending timers
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets('navigates to /login after initialization', (tester) async {
      await tester.pumpWidget(_buildTestSplash());

      // SplashScreen waits 2 seconds then navigates to /login
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);
    });
  });
}
