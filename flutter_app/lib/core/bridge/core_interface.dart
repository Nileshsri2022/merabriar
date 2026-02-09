import 'dart:typed_data';

/// Key bundle returned from core
class KeyBundle {
  final Uint8List identityPublicKey;
  final Uint8List signedPreKey;
  final Uint8List signature;

  KeyBundle({
    required this.identityPublicKey,
    required this.signedPreKey,
    required this.signature,
  });

  Map<String, dynamic> toJson() => {
    'identity_public_key': identityPublicKey,
    'signed_prekey': signedPreKey,
    'signature': signature,
  };
}

/// Public key bundle (received from server)
class PublicKeyBundle {
  final Uint8List identityPublicKey;
  final Uint8List signedPreKey;
  final Uint8List signature;
  final Uint8List? oneTimePreKey;

  PublicKeyBundle({
    required this.identityPublicKey,
    required this.signedPreKey,
    required this.signature,
    this.oneTimePreKey,
  });

  factory PublicKeyBundle.fromJson(Map<String, dynamic> json) {
    return PublicKeyBundle(
      identityPublicKey: Uint8List.fromList(json['identity_public_key']),
      signedPreKey: Uint8List.fromList(json['signed_prekey']),
      signature: Uint8List.fromList(json['signature']),
      oneTimePreKey: json['one_time_prekey'] != null
          ? Uint8List.fromList(json['one_time_prekey'])
          : null,
    );
  }
}

/// Queued message for offline support
class QueuedMessage {
  final String id;
  final String recipientId;
  final Uint8List encryptedContent;
  final int createdAt;
  final int attempts;

  QueuedMessage({
    required this.id,
    required this.recipientId,
    required this.encryptedContent,
    required this.createdAt,
    this.attempts = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'recipient_id': recipientId,
    'encrypted_content': encryptedContent,
    'created_at': createdAt,
    'attempts': attempts,
  };

  factory QueuedMessage.fromJson(Map<String, dynamic> json) {
    return QueuedMessage(
      id: json['id'],
      recipientId: json['recipient_id'],
      encryptedContent: Uint8List.fromList(json['encrypted_content']),
      createdAt: json['created_at'],
      attempts: json['attempts'] ?? 0,
    );
  }
}

/// Abstract interface for messenger core
/// Both Rust and Go cores implement this interface
abstract class MessengerCore {
  /// Initialize the core engine
  Future<void> init(String dbPath, String encryptionKey);

  /// Generate new identity keys (call during signup)
  Future<KeyBundle> generateIdentityKeys();

  /// Get our public key bundle
  Future<PublicKeyBundle> getPublicKeyBundle();

  /// Initialize a session with a recipient
  Future<void> initSession(String recipientId, PublicKeyBundle recipientKeys);

  /// Check if we have a session with a recipient
  Future<bool> hasSession(String recipientId);

  /// Encrypt a message for a recipient
  Future<Uint8List> encryptMessage(String recipientId, String plaintext);

  /// Decrypt a message from a sender
  Future<String> decryptMessage(String senderId, Uint8List ciphertext);

  /// Queue a message for sending later (offline support)
  Future<void> queueMessage(QueuedMessage message);

  /// Get all queued messages
  Future<List<QueuedMessage>> getQueuedMessages();

  /// Clear sent messages from queue
  Future<void> clearQueue(List<String> messageIds);
}
