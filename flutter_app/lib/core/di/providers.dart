import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bridge/core_interface.dart';
import '../bridge/rust_bridge.dart';
import '../bridge/go_bridge.dart';

/// Core type enum - controls which core is used
enum CoreType { rust, go }

/// ============================================================
/// CHANGE THIS TO SWITCH BETWEEN RUST AND GO CORES!
/// ============================================================
const CoreType activeCore = CoreType.rust;
// const CoreType activeCore = CoreType.go;

/// Provider for the messenger core
/// This is the single source of truth for core access
final messengerCoreProvider = Provider<MessengerCore>((ref) {
  switch (activeCore) {
    case CoreType.rust:
      return RustMessengerCore();
    case CoreType.go:
      return GoMessengerCore();
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
String get activeCoreLog => activeCore == CoreType.rust ? '🦀 Rust' : '🐹 Go';
