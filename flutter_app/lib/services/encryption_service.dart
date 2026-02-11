import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/bridge/core_interface.dart';
import '../core/di/providers.dart' show DevMode;

/// EncryptionService — orchestrates core ↔ Supabase key exchange & encryption.
///
/// Responsibilities:
///   1. Generate and upload identity keys during signup
///   2. Fetch recipient's public key bundle from Supabase
///   3. Establish Double Ratchet sessions via the active core
///   4. Encrypt outgoing messages
///   5. Decrypt incoming messages
///   6. Manage prekey rotation
class EncryptionService {
  final MessengerCore _core;
  final SupabaseClient _client = Supabase.instance.client;

  /// Cache of established sessions to avoid redundant lookups
  final Set<String> _sessionCache = {};

  EncryptionService(this._core);

  String? get _currentUserId =>
      _client.auth.currentUser?.id ?? DevMode.currentUserId;

  // ─── Key management ───

  /// Generate identity keys and upload them to Supabase.
  /// Called once during first-time signup.
  Future<KeyBundle> generateAndUploadKeys() async {
    final keys = await _core.generateIdentityKeys();

    // Upload to Supabase users table
    if (_currentUserId != null) {
      await _client.from('users').update({
        'identity_public_key': keys.identityPublicKey.toList(),
        'signed_prekey': keys.signedPreKey.toList(),
        'signed_prekey_signature': keys.signature.toList(),
      }).eq('id', _currentUserId!);

      print('[Encryption] Keys uploaded for $_currentUserId');
    }

    return keys;
  }

  /// Fetch a recipient's public key bundle from Supabase.
  Future<PublicKeyBundle?> fetchRecipientKeys(String recipientId) async {
    try {
      final response = await _client
          .from('users')
          .select('identity_public_key, signed_prekey, signed_prekey_signature')
          .eq('id', recipientId)
          .maybeSingle();

      if (response == null) return null;

      // Parse BYTEA columns — Supabase returns them as base64 strings
      final idKey = _parseBytea(response['identity_public_key']);
      final spk = _parseBytea(response['signed_prekey']);
      final sig = _parseBytea(response['signed_prekey_signature']);

      if (idKey == null || spk == null || sig == null) return null;

      // Also check for a one-time prekey
      Uint8List? otpk;
      try {
        final prekeyResponse = await _client
            .from('prekeys')
            .select('id, public_key')
            .eq('user_id', recipientId)
            .eq('used', false)
            .limit(1)
            .maybeSingle();

        if (prekeyResponse != null) {
          otpk = _parseBytea(prekeyResponse['public_key']);
          // Mark it as used
          await _client
              .from('prekeys')
              .update({'used': true}).eq('id', prekeyResponse['id']);
        }
      } catch (_) {
        // Prekeys table might have no entries — that's fine
      }

      return PublicKeyBundle(
        identityPublicKey: idKey,
        signedPreKey: spk,
        signature: sig,
        oneTimePreKey: otpk,
      );
    } catch (e) {
      print('[Encryption] Failed to fetch keys for $recipientId: $e');
      return null;
    }
  }

  // ─── Session management ───

  /// Ensure we have an active session with the recipient.
  /// If not, fetch their keys and establish one.
  Future<bool> ensureSession(String recipientId) async {
    // Check memory cache first
    if (_sessionCache.contains(recipientId)) return true;

    // Check the core
    final hasIt = await _core.hasSession(recipientId);
    if (hasIt) {
      _sessionCache.add(recipientId);
      return true;
    }

    // Fetch keys and establish session
    final keys = await fetchRecipientKeys(recipientId);
    if (keys == null) {
      print('[Encryption] No keys found for $recipientId — '
          'fallback to plaintext');
      return false;
    }

    // Check for placeholder keys ([0])
    if (keys.identityPublicKey.length <= 1) {
      print('[Encryption] Recipient has placeholder keys — '
          'fallback to plaintext');
      return false;
    }

    try {
      await _core.initSession(recipientId, keys);
      _sessionCache.add(recipientId);
      print('[Encryption] Session established with $recipientId');
      return true;
    } catch (e) {
      print('[Encryption] Session init failed: $e');
      return false;
    }
  }

  // ─── Encrypt / Decrypt ───

  /// Encrypt a plaintext message for the given recipient.
  /// Returns null if encryption is not available (falls back to plaintext).
  Future<Uint8List?> encrypt(String recipientId, String plaintext) async {
    final sessionReady = await ensureSession(recipientId);
    if (!sessionReady) return null;

    try {
      return await _core.encryptMessage(recipientId, plaintext);
    } catch (e) {
      print('[Encryption] Encrypt failed: $e');
      return null;
    }
  }

  /// Decrypt a ciphertext message from the given sender.
  /// Returns null if decryption fails.
  Future<String?> decrypt(String senderId, Uint8List ciphertext) async {
    final sessionReady = await ensureSession(senderId);
    if (!sessionReady) return null;

    try {
      return await _core.decryptMessage(senderId, ciphertext);
    } catch (e) {
      print('[Encryption] Decrypt failed: $e');
      return null;
    }
  }

  // ─── Offline queue ───

  /// Queue a message for sending when connectivity is restored.
  Future<void> queueForRetry(QueuedMessage message) async {
    await _core.queueMessage(message);
  }

  /// Get all queued (unsent) messages.
  Future<List<QueuedMessage>> getPendingQueue() async {
    return await _core.getQueuedMessages();
  }

  /// Flush successfully sent messages from the queue.
  Future<void> flushQueue(List<String> sentIds) async {
    if (sentIds.isEmpty) return;
    await _core.clearQueue(sentIds);
  }

  // ─── Helpers ───

  /// Parse a BYTEA column from Supabase.
  /// Supabase can return BYTEA as:
  ///  - A hex string like `\x48656c6c6f`
  ///  - A base64 string
  ///  - A List<int>
  Uint8List? _parseBytea(dynamic value) {
    if (value == null) return null;
    if (value is List) return Uint8List.fromList(value.cast<int>());

    if (value is String) {
      if (value.startsWith('\\x') || value.startsWith('\\\\x')) {
        // Hex string
        final hex = value.replaceAll(RegExp(r'^\\+x'), '');
        final bytes = <int>[];
        for (var i = 0; i < hex.length; i += 2) {
          bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
        }
        return Uint8List.fromList(bytes);
      }
      // Try base64
      try {
        return Uint8List.fromList(base64Decode(value));
      } catch (_) {
        return Uint8List.fromList(value.codeUnits);
      }
    }

    return null;
  }
}
