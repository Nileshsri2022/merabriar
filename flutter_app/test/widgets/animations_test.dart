import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:merabriar/core/widgets/animations.dart';

void main() {
  // ── StaggerSlideIn ──
  group('StaggerSlideIn', () {
    testWidgets('renders child widget after animation', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StaggerSlideIn(
              index: 0,
              child: Text('Test Item'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Test Item'), findsOneWidget);
    });

    testWidgets('renders multiple staggered items', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: List.generate(
                3,
                (i) => StaggerSlideIn(
                  index: i,
                  child: Text('Item $i'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
    });

    testWidgets('widget tree includes StaggerSlideIn', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StaggerSlideIn(
              index: 0,
              child: Text('Animated'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(StaggerSlideIn), findsOneWidget);
      expect(find.text('Animated'), findsOneWidget);
    });
  });

  // ── MessageSendAnimation ──
  group('MessageSendAnimation', () {
    testWidgets('renders child when animate is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessageSendAnimation(
              animate: false,
              child: Text('Message'),
            ),
          ),
        ),
      );

      expect(find.text('Message'), findsOneWidget);
    });

    testWidgets('renders child when animate is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessageSendAnimation(
              animate: true,
              child: Text('New Message'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('New Message'), findsOneWidget);
    });
  });

  // ── TypingIndicator ──
  group('TypingIndicator', () {
    testWidgets('renders 3 dots', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TypingIndicator(),
          ),
        ),
      );

      // Pump a frame so dots render
      await tester.pump(const Duration(milliseconds: 600));

      // Should find 3 circular dot containers
      final dots = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final dec = widget.decoration as BoxDecoration;
          return dec.shape == BoxShape.circle;
        }
        return false;
      });

      expect(dots, findsNWidgets(3));
    });
  });

  // ── PulseAnimation ──
  group('PulseAnimation', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PulseAnimation(
              child: Icon(Icons.circle, size: 12),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.circle), findsOneWidget);
    });
  });
}
