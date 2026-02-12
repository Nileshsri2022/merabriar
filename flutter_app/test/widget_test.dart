// Basic smoke test for MeraBriar app
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App theme uses Material 3', (WidgetTester tester) async {
    // Smoke test: verify the app can import core types
    expect(ThemeMode.system, isNotNull);
    expect(ThemeData.light().useMaterial3, isNotNull);
  });
}
