import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:merabriar/core/di/providers.dart';

/// Set up mock platform channels needed by Supabase (SharedPreferences).
/// Call this once in setUpAll() before [initTestSupabase].
void setupMockPlatformChannels() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/shared_preferences'),
    (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'getAll':
          return <String, dynamic>{};
        case 'setBool':
        case 'setInt':
        case 'setDouble':
        case 'setString':
        case 'setStringList':
          return true;
        case 'remove':
        case 'clear':
          return true;
        default:
          return null;
      }
    },
  );

  // Also mock shared_preferences_async if needed
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/shared_preferences_async'),
    (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'getAll':
          return <String, dynamic>{};
        case 'getPreferences':
          return <String, dynamic>{};
        default:
          return null;
      }
    },
  );
}

/// Initialize Supabase with a local/test configuration.
/// Call this once in setUpAll() after [setupMockPlatformChannels].
Future<void> initTestSupabase() async {
  try {
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRlc3QiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTcwMDAwMDAwMCwiZXhwIjoyMDAwMDAwMDAwfQ.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
    );
  } catch (_) {
    // Already initialized (subsequent tests in same process)
  }
}

/// Wraps a widget in the minimal tree needed for screen-level widget tests.
///
/// Provides:
/// - ProviderScope with overrides (initializeCoreProvider mocked)
/// - MaterialApp with theme
/// - Any additional provider overrides
Widget buildTestableWidget(
  Widget child, {
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      initializeCoreProvider.overrideWith((ref) async {}),
      ...overrides,
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}
