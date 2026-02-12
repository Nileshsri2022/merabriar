import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:merabriar/core/widgets/connectivity_banner.dart';

void main() {
  group('ConnectivityBanner', () {
    testWidgets('shows when isOffline is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ConnectivityBanner(isOffline: true),
                Expanded(child: Placeholder()),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('No internet connection'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    });

    testWidgets('shows retry button when callback provided', (tester) async {
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ConnectivityBanner(
                  isOffline: true,
                  onRetry: () => retried = true,
                ),
                const Expanded(child: Placeholder()),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    testWidgets('does not show retry when no callback', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ConnectivityBanner(isOffline: true),
                Expanded(child: Placeholder()),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('is hidden when online', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ConnectivityBanner(isOffline: false),
                Expanded(child: Placeholder()),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      // The widget exists but is invisible (opacity = 0)
      final opacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(opacity.opacity, 0.0);
    });
  });
}
