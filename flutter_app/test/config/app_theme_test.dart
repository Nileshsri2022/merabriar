import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:merabriar/config/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('light theme has correct brightness', () {
      final theme = AppTheme.lightTheme;
      expect(theme.brightness, Brightness.light);
    });

    test('dark theme has correct brightness', () {
      final theme = AppTheme.darkTheme;
      expect(theme.brightness, Brightness.dark);
    });

    test('light theme uses Material 3', () {
      final theme = AppTheme.lightTheme;
      expect(theme.useMaterial3, true);
    });

    test('dark theme uses Material 3', () {
      final theme = AppTheme.darkTheme;
      expect(theme.useMaterial3, true);
    });

    test('light theme has correct AppBar colors', () {
      final theme = AppTheme.lightTheme;
      expect(theme.appBarTheme.backgroundColor, AppTheme.brandGreen);
      expect(theme.appBarTheme.foregroundColor, Colors.white);
    });

    test('dark theme has correct AppBar colors', () {
      final theme = AppTheme.darkTheme;
      expect(theme.appBarTheme.backgroundColor, AppTheme.darkCard);
      expect(theme.appBarTheme.foregroundColor, Colors.white);
    });

    test('dark theme has correct scaffold color', () {
      final theme = AppTheme.darkTheme;
      expect(theme.scaffoldBackgroundColor, AppTheme.darkSurface);
    });

    test('brand colors are defined correctly', () {
      expect(AppTheme.brandGreen, const Color(0xFF2D6A4F));
      expect(AppTheme.brandDarkGreen, const Color(0xFF1B4332));
      expect(AppTheme.brandLightGreen, const Color(0xFF52B788));
      expect(AppTheme.brandAccent, const Color(0xFF95D5B2));
    });

    test('semantic colors are defined', () {
      expect(AppTheme.success, const Color(0xFF40C057));
      expect(AppTheme.warning, const Color(0xFFFFD43B));
      expect(AppTheme.danger, const Color(0xFFFF6B6B));
      expect(AppTheme.info, const Color(0xFF339AF0));
    });
  });

  group('AppGradients', () {
    test('primaryGradient uses brand colors', () {
      expect(AppGradients.primaryGradient.colors,
          [AppTheme.brandDarkGreen, AppTheme.brandGreen]);
    });

    test('accentGradient uses brand colors', () {
      expect(AppGradients.accentGradient.colors,
          [AppTheme.brandGreen, AppTheme.brandLightGreen]);
    });

    testWidgets('shimmerGradient adapts to light theme', (tester) async {
      late LinearGradient gradient;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) {
              gradient = AppGradients.shimmerGradient(context);
              return const Placeholder();
            },
          ),
        ),
      );

      // Light shimmer uses lighter grays
      expect(gradient.colors.length, 3);
      expect(gradient.colors[0], const Color(0xFFF0F0F0));
    });

    testWidgets('shimmerGradient adapts to dark theme', (tester) async {
      late LinearGradient gradient;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
            builder: (context) {
              gradient = AppGradients.shimmerGradient(context);
              return const Placeholder();
            },
          ),
        ),
      );

      // Dark shimmer uses dark card colors
      expect(gradient.colors.length, 3);
      expect(gradient.colors[0], const Color(0xFF1B2838));
    });
  });
}
