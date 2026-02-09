import 'dart:typed_data';

import 'core_interface.dart';
import '../../src/rust/api.dart' as rust_api;
import '../../src/rust/frb_generated.dart';

/// Rust implementation of MessengerCore
/// Uses flutter_rust_bridge for FFI
class RustMessengerCore implements MessengerCore {
  bool _initialized = false;

  @override
  Future<void> init(String dbPath, String encryptionKey) async {
    // Initialize the Rust library
    await RustLib.init();

    // Initialize Rust core
    await rust_api.initCore(dbPath: dbPath, encryptionKey: encryptionKey);
    _initialized = true;
    print('[RustCore] Initialized with db: $dbPath');
  }

  @override
  Future<KeyBundle> generateIdentityKeys() async {
    if (!_initialized) throw Exception('Core not initialized');

    final bundle = await rust_api.generateIdentityKeys();
    return KeyBundle(
      identityPublicKey: bundle.identityPublicKey,
      signedPreKey: bundle.signedPrekey,
      signature: bundle.signature,
    );
  }

  @override
  Future<PublicKeyBundle> getPublicKeyBundle() async {
    if (!_initialized) throw Exception('Core not initialized');

    final bundle = await rust_api.getPublicKeyBundle();
    return PublicKeyBundle(
      identityPublicKey: bundle.identityPublicKey,
      signedPreKey: bundle.signedPrekey,
      signature: bundle.signature,
      oneTimePreKey: bundle.oneTimePrekey,
    );
  }

  @override
  Future<void> initSession(
    String recipientId,
    PublicKeyBundle recipientKeys,
  ) async {
    if (!_initialized) throw Exception('Core not initialized');

    await rust_api.initSession(
      recipientId: recipientId,
      identityPublicKey: recipientKeys.identityPublicKey.toList(),
      signedPrekey: recipientKeys.signedPreKey.toList(),
      signature: recipientKeys.signature.toList(),
      oneTimePrekey: recipientKeys.oneTimePreKey,
    );
    print('[RustCore] Session initialized with: $recipientId');
  }

  @override
  Future<bool> hasSession(String recipientId) async {
    if (!_initialized) throw Exception('Core not initialized');

    return await rust_api.hasSession(recipientId: recipientId);
  }

  @override
  Future<Uint8List> encryptMessage(String recipientId, String plaintext) async {
    if (!_initialized) throw Exception('Core not initialized');

    final ciphertext = await rust_api.encryptMessage(
      recipientId: recipientId,
      plaintext: plaintext,
    );
    return ciphertext;
  }

  @override
  Future<String> decryptMessage(String senderId, Uint8List ciphertext) async {
    if (!_initialized) throw Exception('Core not initialized');

    return await rust_api.decryptMessage(
      senderId: senderId,
      ciphertext: ciphertext.toList(),
    );
  }

  @override
  Future<void> queueMessage(QueuedMessage message) async {
    if (!_initialized) throw Exception('Core not initialized');
    // Queue functions are not yet exposed via FFI
    print('[RustCore] Queuing message: ${message.id}');
  }

  @override
  Future<List<QueuedMessage>> getQueuedMessages() async {
    if (!_initialized) throw Exception('Core not initialized');
    // Queue functions are not yet exposed via FFI
    print('[RustCore] Getting queued messages...');
    return [];
  }

  @override
  Future<void> clearQueue(List<String> messageIds) async {
    if (!_initialized) throw Exception('Core not initialized');
    // Queue functions are not yet exposed via FFI
    print('[RustCore] Clearing queue: $messageIds');
  }
}

/// Web implementation of MessengerCore (stub for browser)
/// No FFI on web, so this uses pure Dart implementations
class WebMessengerCore implements MessengerCore {
  bool _initialized = false;

  @override
  Future<void> init(String dbPath, String encryptionKey) async {
    _initialized = true;
    print('[WebCore] Initialized (stub mode)');
  }

  @override
  Future<KeyBundle> generateIdentityKeys() async {
    if (!_initialized) throw Exception('Core not initialized');
    print('[WebCore] Generating identity keys (stub)...');
    return KeyBundle(
      identityPublicKey: Uint8List(32),
      signedPreKey: Uint8List(32),
      signature: Uint8List(64),
    );
  }

  @override
  Future<PublicKeyBundle> getPublicKeyBundle() async {
    if (!_initialized) throw Exception('Core not initialized');
    return PublicKeyBundle(
      identityPublicKey: Uint8List(32),
      signedPreKey: Uint8List(32),
      signature: Uint8List(64),
    );
  }

  @override
  Future<void> initSession(
      String recipientId, PublicKeyBundle recipientKeys) async {
    if (!_initialized) throw Exception('Core not initialized');
    print('[WebCore] Session initialized with: $recipientId');
  }

  @override
  Future<bool> hasSession(String recipientId) async {
    if (!_initialized) throw Exception('Core not initialized');
    return false;
  }

  @override
  Future<Uint8List> encryptMessage(String recipientId, String plaintext) async {
    if (!_initialized) throw Exception('Core not initialized');
    // Web stub: just encode as bytes (no real encryption)
    return Uint8List.fromList(plaintext.codeUnits);
  }

  @override
  Future<String> decryptMessage(String senderId, Uint8List ciphertext) async {
    if (!_initialized) throw Exception('Core not initialized');
    // Web stub: just decode bytes
    return String.fromCharCodes(ciphertext);
  }

  @override
  Future<void> queueMessage(QueuedMessage message) async {
    if (!_initialized) throw Exception('Core not initialized');
    print('[WebCore] Queuing message: ${message.id}');
  }

  @override
  Future<List<QueuedMessage>> getQueuedMessages() async {
    if (!_initialized) throw Exception('Core not initialized');
    return [];
  }

  @override
  Future<void> clearQueue(List<String> messageIds) async {
    if (!_initialized) throw Exception('Core not initialized');
    print('[WebCore] Clearing queue: $messageIds');
  }
}
