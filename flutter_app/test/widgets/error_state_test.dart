import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:merabriar/core/widgets/error_state.dart';

void main() {
  group('ErrorStateWidget', () {
    testWidgets('renders title and message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorStateWidget(
              title: 'Test Error',
              message: 'Something went wrong',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Test Error'), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('renders retry button when onRetry is provided',
        (tester) async {
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorStateWidget(
              title: 'Error',
              message: 'Failed',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Try Again'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      expect(retried, isTrue);
    });

    testWidgets('does not render retry button when onRetry is null',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorStateWidget(
              title: 'Error',
              message: 'Failed',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Try Again'), findsNothing);
    });

    testWidgets('connection factory renders correct content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorStateWidget.connection(onRetry: () {}),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Connection Error'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });

    testWidgets('loadFailed factory renders with correct "what"',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorStateWidget.loadFailed(what: 'messages'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Failed to load messages'), findsOneWidget);
    });

    testWidgets('empty factory renders with correct content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorStateWidget.empty(
              title: 'No Data',
              message: 'Nothing here yet',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No Data'), findsOneWidget);
      expect(find.text('Nothing here yet'), findsOneWidget);
    });
  });

  group('InlineErrorBanner', () {
    testWidgets('renders message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InlineErrorBanner(message: 'Send failed'),
          ),
        ),
      );

      expect(find.text('Send failed'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('renders retry and dismiss buttons', (tester) async {
      bool retried = false;
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InlineErrorBanner(
              message: 'Error',
              onRetry: () => retried = true,
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      // Tap retry
      await tester.tap(find.byIcon(Icons.refresh));
      expect(retried, isTrue);

      // Tap dismiss
      await tester.tap(find.byIcon(Icons.close));
      expect(dismissed, isTrue);
    });
  });
}
