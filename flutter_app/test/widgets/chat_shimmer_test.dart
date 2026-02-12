import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:merabriar/core/widgets/chat_shimmer.dart';

void main() {
  group('ChatShimmerLoader', () {
    testWidgets('renders 7 shimmer bubbles', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatShimmerLoader(),
          ),
        ),
      );

      // The ChatShimmerLoader has 7 _ShimmerBubble children
      // They should all be rendered as Align widgets with containers
      expect(find.byType(Align), findsNWidgets(7));
    });

    testWidgets('shimmer bubbles have correct alignment', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatShimmerLoader(),
          ),
        ),
      );

      final aligns = tester.widgetList<Align>(find.byType(Align)).toList();

      // First bubble: isMe=false -> centerLeft
      expect(aligns[0].alignment, Alignment.centerLeft);
      // Second: false -> centerLeft
      expect(aligns[1].alignment, Alignment.centerLeft);
      // Third: true -> centerRight
      expect(aligns[2].alignment, Alignment.centerRight);
    });

    testWidgets('contains animated containers', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatShimmerLoader(),
          ),
        ),
      );

      // Should have decorated Container widgets for the shimmer bubbles
      expect(find.byType(Container), findsWidgets);
    });
  });
}
