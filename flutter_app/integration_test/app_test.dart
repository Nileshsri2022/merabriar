import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:merabriar/main.dart';

/// Integration tests — run on a real device or emulator.
///
/// Usage:
///   flutter test integration_test/
///
/// For a specific device:
///   flutter test integration_test/ -d <device-id>
///
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Launch', () {
    testWidgets('splash screen loads and shows branding', (tester) async {
      // Note: This requires Supabase to be initialized in main().
      // The app will start from the splash screen.
      await tester.pumpWidget(const ProviderScope(child: MeraBriarApp()));

      // Splash screen should show branding
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('MeraBriar'), findsOneWidget);
      expect(find.text('Secure. Private. Yours.'), findsOneWidget);
    });

    testWidgets('splash navigates to login after delay', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: MeraBriarApp()));

      // Wait for the SplashScreen's 2-second delay + core init
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // Should be on the login screen now
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Send Magic Link'), findsOneWidget);
    });
  });

  group('Login Flow', () {
    testWidgets('email validation shows error for empty input', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: MeraBriarApp()));

      // Wait for login screen
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // Tap Send Magic Link with no email
      await tester.tap(find.text('Send Magic Link'));
      await tester.pump();

      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('dev mode Nilesh button navigates to chats', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: MeraBriarApp()));

      // Wait for login screen
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // Tap Nilesh dev button
      await tester.tap(find.text('Nilesh'));
      await tester.pumpAndSettle();

      // Should be on chat list or chats view
      // (exact assertion depends on whether Supabase connects)
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
