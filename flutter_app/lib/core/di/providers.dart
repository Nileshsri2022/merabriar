import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bridge/core_interface.dart';
import '../bridge/rust_bridge.dart';
import '../bridge/go_bridge.dart';
import '../../services/encryption_service.dart';
import '../../services/message_service.dart';
import '../../services/user_service.dart';

/// Core type enum — controls which core is used
enum CoreType { rust, go, web }

/// ============================================================
/// CHANGE THIS TO SWITCH BETWEEN RUST AND GO CORES!
/// (Web will automatically use stub implementation)
/// ============================================================
const CoreType activeCore = CoreType.go;

/// Provider for the messenger core
final messengerCoreProvider = Provider<MessengerCore>((ref) {
  if (kIsWeb) {
    return WebMessengerCore();
  }

  switch (activeCore) {
    case CoreType.rust:
      return RustMessengerCore();
    case CoreType.go:
      return GoMessengerCore();
    case CoreType.web:
      return WebMessengerCore();
  }
});

/// Provider for the encryption service
final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  final core = ref.read(messengerCoreProvider);
  return EncryptionService(core);
});

/// Provider for the message service (wired)
final messageServiceProvider = Provider<MessageService>((ref) {
  final encryption = ref.read(encryptionServiceProvider);
  final svc = messageService; // global instance
  svc.setEncryptionService(encryption);
  return svc;
});

/// Provider for the user service (wired)
final userServiceProvider = Provider<UserService>((ref) {
  final encryption = ref.read(encryptionServiceProvider);
  final svc = userService; // global instance
  svc.setEncryptionService(encryption);
  return svc;
});

/// Provider to track initialization state
final coreInitializedProvider = StateProvider<bool>((ref) => false);

/// Initialize the core engine and wire up services
final initializeCoreProvider = FutureProvider.autoDispose<void>((ref) async {
  final core = ref.read(messengerCoreProvider);

  // Get app documents directory for database
  // In production, use path_provider
  const dbPath = 'merabriar.db';
  const encryptionKey = 'your-encryption-key'; // TODO: Generate securely

  await core.init(dbPath, encryptionKey);

  // Wire encryption into services
  final encryption = ref.read(encryptionServiceProvider);
  messageService.setEncryptionService(encryption);
  userService.setEncryptionService(encryption);

  // Upload keys if user has placeholder keys
  await userService.uploadKeysIfNeeded();

  // Flush any queued messages from previous offline session
  final flushed = await messageService.flushRetryQueue();
  if (flushed > 0) {
    print('[Init] Flushed $flushed queued messages');
  }

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

  // Current active test user
  static String _currentUserId = nileshId;

  static String get currentUserId => _currentUserId;

  static String get currentUserName =>
      _currentUserId == nileshId ? 'Nilesh' : 'Vaishali';

  static void useNilesh() {
    _currentUserId = nileshId;
  }

  static void useVaishali() {
    _currentUserId = vaishaliId;
  }

  static void toggle() {
    if (_currentUserId == nileshId) {
      useVaishali();
    } else {
      useNilesh();
    }
  }
}
