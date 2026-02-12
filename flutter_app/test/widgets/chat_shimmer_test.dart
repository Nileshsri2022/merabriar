import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:merabriar/core/widgets/chat_shimmer.dart';

void main() {
  group('ChatShimmerLoader', () {
    Widget buildTestWidget() {
      return const MaterialApp(
        home: Scaffold(
          body: ChatShimmerLoader(),
        ),
      );
    }

    testWidgets('renders shimmer bubbles', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Pump enough for all Future.delayed timers (max 600ms) to fire
      await tester.pump(const Duration(milliseconds: 700));

      // Verify Opacity widgets exist (one per bubble at minimum)
      expect(find.byType(Opacity), findsWidgets);
    });

    testWidgets('shimmer bubbles have mixed alignments', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 700));

      final aligns = tester.widgetList<Align>(find.byType(Align)).toList();

      // Should have at least 7 Align widgets from the bubbles
      expect(aligns.length, greaterThanOrEqualTo(7));

      // Check that both left and right alignments are present
      final hasLeft = aligns.any((a) => a.alignment == Alignment.centerLeft);
      final hasRight = aligns.any((a) => a.alignment == Alignment.centerRight);
      expect(hasLeft, isTrue);
      expect(hasRight, isTrue);
    });

    testWidgets('contains decorated containers for bubbles', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('is wrapped in a non-scrollable ListView', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 700));

      final listView = tester.widget<ListView>(find.byType(ListView).first);
      expect(listView.physics, isA<NeverScrollableScrollPhysics>());
    });
  });
}
