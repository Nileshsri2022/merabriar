import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:merabriar/core/di/providers.dart';
import 'package:merabriar/features/auth/screens/login_screen.dart';

import '../helpers/test_helpers.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupMockPlatformChannels();
    await initTestSupabase();
  });

  /// Build LoginScreen in a routable test tree.
  Widget buildLoginScreen({List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: [
        initializeCoreProvider.overrideWith((ref) async {}),
        ...overrides,
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/login',
          routes: [
            GoRoute(
              path: '/login',
              builder: (context, state) => const LoginScreen(),
            ),
            GoRoute(
              path: '/chats',
              builder: (context, state) => const Scaffold(body: Text('Chats')),
            ),
          ],
        ),
      ),
    );
  }

  group('LoginScreen Widget', () {
    testWidgets('renders title and subtitle', (tester) async {
      await tester.pumpWidget(buildLoginScreen());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(
        find.text('Sign in to your secure messenger'),
        findsOneWidget,
      );
    });

    testWidgets('renders email and display name input fields', (tester) async {
      await tester.pumpWidget(buildLoginScreen());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Display Name (optional)'), findsOneWidget);
    });

    testWidgets('renders Send Magic Link button', (tester) async {
      await tester.pumpWidget(buildLoginScreen());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Send Magic Link'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('renders Development Mode panel', (tester) async {
      await tester.pumpWidget(buildLoginScreen());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Development Mode'), findsOneWidget);
      expect(find.text('Nilesh'), findsOneWidget);
      expect(find.text('Vaishali'), findsOneWidget);
    });

    testWidgets('renders security note', (tester) async {
      await tester.pumpWidget(buildLoginScreen());
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.textContaining('end-to-end encrypted'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    });

    testWidgets('renders eco logo icon', (tester) async {
      await tester.pumpWidget(buildLoginScreen());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.eco), findsOneWidget);
    });

    testWidgets('shows error when sending with empty email', (tester) async {
      await tester.pumpWidget(buildLoginScreen());
      await tester.pump(const Duration(milliseconds: 100));

      // Tap send with empty email
      await tester.tap(find.text('Send Magic Link'));
      await tester.pump();

      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('shows error for invalid email (no @)', (tester) async {
      await tester.pumpWidget(buildLoginScreen());
      await tester.pump(const Duration(milliseconds: 100));

      // Enter invalid email
      await tester.enterText(
        find.widgetWithText(TextField, 'Email'),
        'notanemail',
      );
      await tester.tap(find.text('Send Magic Link'));
      await tester.pump();

      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('dev mode buttons are tappable', (tester) async {
      await tester.pumpWidget(buildLoginScreen());
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Nilesh dev button
      await tester.tap(find.text('Nilesh'));
      await tester.pumpAndSettle();

      // Should navigate to /chats
      expect(find.text('Chats'), findsOneWidget);
    });
  });
}
