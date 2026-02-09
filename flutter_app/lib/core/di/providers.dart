import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bridge/core_interface.dart';
import '../bridge/rust_bridge.dart';

/// Core type enum - controls which core is used
enum CoreType { rust, go, web }

/// ============================================================
/// CHANGE THIS TO SWITCH BETWEEN RUST AND GO CORES!
/// (Web will automatically use stub implementation)
/// ============================================================
const CoreType activeCore = CoreType.rust;
// const CoreType activeCore = CoreType.go;

/// Provider for the messenger core
/// This is the single source of truth for core access
final messengerCoreProvider = Provider<MessengerCore>((ref) {
  if (kIsWeb) {
    // Web doesn't support FFI, use stub implementation
    return WebMessengerCore();
  }

  switch (activeCore) {
    case CoreType.rust:
      return RustMessengerCore();
    case CoreType.go:
      // Go bridge also uses FFI, fallback to Rust or stub
      return RustMessengerCore();
    case CoreType.web:
      return WebMessengerCore();
  }
});

/// Provider to track initialization state
final coreInitializedProvider = StateProvider<bool>((ref) => false);

/// Initialize the core engine
final initializeCoreProvider = FutureProvider.autoDispose<void>((ref) async {
  final core = ref.read(messengerCoreProvider);

  // Get app documents directory for database
  // In real app, use path_provider
  const dbPath = 'merabriar.db';
  const encryptionKey = 'your-encryption-key'; // TODO: Generate securely

  await core.init(dbPath, encryptionKey);
  ref.read(coreInitializedProvider.notifier).state = true;
});

/// Get the active core type name
String get activeCoreLog {
  if (kIsWeb) return '🌐 Web (Stub)';
  return activeCore == CoreType.rust ? '🦀 Rust' : '🐹 Go';
}

/// ============================================================
/// DEV MODE: Test User Configuration
/// Change this to test with different users in multiple tabs
/// ============================================================
class DevMode {
  // Test user IDs
  static const String nileshId = '42f44396-1a00-4dd5-9998-20580cfddbc0';
  static const String vaishaliId = '2832cb69-aaba-441c-b6ce-584e7d9ed394';

  // Current active test user - change this to switch!
  static String _currentUserId = nileshId; // Default to Nilesh

  /// Get current dev user ID
  static String get currentUserId => _currentUserId;

  /// Get current dev user name
  static String get currentUserName =>
      _currentUserId == nileshId ? 'Nilesh' : 'Vaishali';

  /// Set to Nilesh
  static void useNilesh() {
    _currentUserId = nileshId;
  }

  /// Set to Vaishali
  static void useVaishali() {
    _currentUserId = vaishaliId;
  }

  /// Toggle between users
  static void toggle() {
    if (_currentUserId == nileshId) {
      useVaishali();
    } else {
      useNilesh();
    }
  }
}
