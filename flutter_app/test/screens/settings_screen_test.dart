import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:merabriar/core/di/providers.dart';
import 'package:merabriar/features/chat/providers/chat_providers.dart';
import 'package:merabriar/features/settings/screens/settings_screen.dart';
import 'package:merabriar/services/user_service.dart';

import '../helpers/test_helpers.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupMockPlatformChannels();
    await initTestSupabase();
  });

  /// A mock UserProfile for tests.
  final mockProfile = UserProfile(
    id: 'test-user-123',
    displayName: 'TestUser',
    isOnline: true,
  );

  /// Build SettingsScreen with mocked providers and GoRouter context.
  Widget buildSettingsScreen({UserProfile? profile}) {
    return ProviderScope(
      overrides: [
        initializeCoreProvider.overrideWith((ref) async {}),
        currentUserProvider.overrideWith(
          (ref) async => profile ?? mockProfile,
        ),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/settings',
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
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

  group('SettingsScreen Widget', () {
    testWidgets('renders Settings title in app bar', (tester) async {
      await tester.pumpWidget(buildSettingsScreen());
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('shows user display name in header', (tester) async {
      await tester.pumpWidget(buildSettingsScreen());
      await tester.pumpAndSettle();

      expect(find.text('TestUser'), findsWidgets); // header + tile
    });

    testWidgets('shows avatar initial from display name', (tester) async {
      await tester.pumpWidget(buildSettingsScreen());
      await tester.pumpAndSettle();

      expect(find.text('T'), findsOneWidget); // First letter of 'TestUser'
    });

    // Use a tall surface so the CustomScrollView renders everything visible
    testWidgets('renders all sections with tall viewport', (tester) async {
      // Enlarge the test viewport so all sliver content is laid out
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildSettingsScreen());
      await tester.pumpAndSettle();

      // ── Account ──
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('Display Name'), findsOneWidget);
      expect(find.text('User ID'), findsOneWidget);

      // ── Security ──
      expect(find.text('SECURITY'), findsOneWidget);
      expect(find.text('Encryption'), findsOneWidget);
      expect(find.text('AES-256-GCM end-to-end'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Key Management'), findsOneWidget);
      expect(find.text('Protocol'), findsOneWidget);
      expect(find.text('Signal-like Double Ratchet'), findsOneWidget);

      // ── Core Engine ──
      expect(find.text('CORE ENGINE'), findsOneWidget);
      expect(find.text('Active Core'), findsOneWidget);
      expect(find.text('Local Storage'), findsOneWidget);
      expect(find.text('SQLCipher encrypted database'), findsOneWidget);
    });

    testWidgets('renders loading state when profile is slow', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            initializeCoreProvider.overrideWith((ref) async {}),
            // Simulate a slow-loading profile
            currentUserProvider.overrideWith((ref) async {
              await Future.delayed(const Duration(seconds: 5));
              return mockProfile;
            }),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/settings',
              routes: [
                GoRoute(
                  path: '/settings',
                  builder: (context, state) => const SettingsScreen(),
                ),
              ],
            ),
          ),
        ),
      );

      // Don't settle — the provider is still "loading"
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Loading...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Clean up the pending timer
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });

    testWidgets('shows ? avatar when display name is null', (tester) async {
      final noNameProfile = UserProfile(id: 'no-name-user');
      await tester.pumpWidget(buildSettingsScreen(profile: noNameProfile));
      await tester.pumpAndSettle();

      expect(find.text('?'), findsOneWidget);
    });
  });
}
