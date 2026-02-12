import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/bridge/core_interface.dart' show QueuedMessage;
import '../core/di/providers.dart' show DevMode;
import 'encryption_service.dart';

/// Message model
class Message {
  final String id;
  final String senderId;
  final String recipientId;
  final String content;
  final List<int>? encryptedContent;
  final String messageType;
  final String status;
  final DateTime sentAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  Message({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.content,
    this.encryptedContent,
    this.messageType = 'text',
    this.status = 'pending',
    required this.sentAt,
    this.deliveredAt,
    this.readAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      senderId: json['sender_id'],
      recipientId: json['recipient_id'],
      content: json['content'] ?? '',
      encryptedContent: json['encrypted_content'] != null
          ? List<int>.from(json['encrypted_content'])
          : null,
      messageType: json['message_type'] ?? 'text',
      status: json['status'] ?? 'pending',
      sentAt: DateTime.parse(json['sent_at']),
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'])
          : null,
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'recipient_id': recipientId,
      'encrypted_content': encryptedContent ?? content.codeUnits,
      'message_type': messageType,
      'status': status,
    };
  }

  bool get isMe =>
      senderId ==
      (Supabase.instance.client.auth.currentUser?.id ?? DevMode.currentUserId);
}

/// Conversation model (for chat list)
class Conversation {
  final String oderId;
  final String odername;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isOnline;

  Conversation({
    required this.oderId,
    required this.odername,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isOnline = false,
  });
}

/// Message Service — wired to EncryptionService for real E2E encryption.
class MessageService {
  final SupabaseClient _client = Supabase.instance.client;

  /// The encryption service — injected after core init.
  EncryptionService? _encryption;

  StreamSubscription? _messageSubscription;
  final _messageController = StreamController<Message>.broadcast();

  Stream<Message> get messageStream => _messageController.stream;

  String? get currentUserId =>
      _client.auth.currentUser?.id ?? DevMode.currentUserId;

  /// Attach the encryption service (called after core init).
  void setEncryptionService(EncryptionService service) {
    _encryption = service;
    print('[MessageService] Encryption service attached');
  }

  // ─── Send ───

  /// Send a message — encrypts if a session is available, else plaintext.
  Future<Message?> sendMessage({
    required String recipientId,
    required String content,
  }) async {
    if (currentUserId == null) return null;

    try {
      Uint8List? ciphertext;
      String? plainFallback;

      // Try to encrypt with the core
      if (_encryption != null) {
        ciphertext = await _encryption!.encrypt(recipientId, content);
      }

      // If encryption produced ciphertext, don't store plaintext
      if (ciphertext != null) {
        plainFallback = null; // E2E encrypted — no plaintext on server
      } else {
        plainFallback = content; // Fallback: store as readable text
      }

      final response = await _client
          .from('messages')
          .insert({
            'sender_id': currentUserId,
            'recipient_id': recipientId,
            'content_text': plainFallback, // null when encrypted
            'encrypted_content': ciphertext?.toList() ?? content.codeUnits,
            'message_type': 'text',
            'status': 'sent',
          })
          .select()
          .single();

      return Message(
        id: response['id'],
        senderId: currentUserId!,
        recipientId: recipientId,
        content: content,
        encryptedContent: ciphertext?.toList() ?? content.codeUnits,
        status: 'sent',
        sentAt: DateTime.now(),
      );
    } catch (e) {
      print('[MessageService] Send failed: $e');

      // Queue for retry if offline
      if (_encryption != null) {
        try {
          final encrypted = await _encryption!.encrypt(recipientId, content);
          if (encrypted != null) {
            await _encryption!.queueForRetry(
              QueuedMessage(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                recipientId: recipientId,
                encryptedContent: encrypted,
                createdAt: DateTime.now().millisecondsSinceEpoch,
              ),
            );
            print('[MessageService] Message queued for retry');
          }
        } catch (_) {}
      }

      return null;
    }
  }

  // ─── Receive / Fetch ───

  /// Get messages for a conversation — decrypts if encrypted.
  Future<List<Message>> getMessages(String oderId, {int limit = 50}) async {
    if (currentUserId == null) return [];

    try {
      final response = await _client
          .from('messages')
          .select()
          .or('and(sender_id.eq.$currentUserId,recipient_id.eq.$oderId),'
              'and(sender_id.eq.$oderId,recipient_id.eq.$currentUserId)')
          .order('sent_at', ascending: false)
          .limit(limit);

      final messages = <Message>[];

      for (final json in (response as List)) {
        final msg = await _parseMessage(json);
        messages.add(msg);
      }

      return messages.reversed.toList();
    } catch (e) {
      print('[MessageService] Get messages error: $e');
      return [];
    }
  }

  /// Parse a single message row — handles decryption.
  Future<Message> _parseMessage(Map<String, dynamic> json) async {
    String content = json['content_text'] ?? '';
    List<int>? contentBytes;

    // If no plaintext, try to decrypt
    if (content.isEmpty) {
      final encryptedRaw = json['encrypted_content'];
      contentBytes = _parseEncryptedContent(encryptedRaw);

      if (contentBytes != null && _encryption != null) {
        // Try to decrypt with the core
        final senderId = json['sender_id'] as String;
        final currentId = currentUserId;

        // Only decrypt messages FROM others (we already know our own plaintext)
        if (senderId != currentId) {
          final decrypted = await _encryption!.decrypt(
            senderId,
            Uint8List.fromList(contentBytes),
          );
          if (decrypted != null) {
            content = decrypted;
          } else {
            // Decryption failed — show raw bytes as string
            content = _bytesToString(contentBytes);
          }
        } else {
          content = _bytesToString(contentBytes);
        }
      } else if (contentBytes != null) {
        content = _bytesToString(contentBytes);
      }
    }

    return Message(
      id: json['id'],
      senderId: json['sender_id'],
      recipientId: json['recipient_id'],
      content: content,
      encryptedContent: contentBytes,
      messageType: json['message_type'] ?? 'text',
      status: json['status'] ?? 'sent',
      sentAt: DateTime.parse(json['sent_at']),
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'])
          : null,
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
    );
  }

  // ─── Conversations list ───

  Future<List<Conversation>> getConversations() async {
    if (currentUserId == null) return [];

    try {
      final sentTo = await _client
          .from('messages')
          .select('recipient_id')
          .eq('sender_id', currentUserId!)
          .order('sent_at', ascending: false);

      final receivedFrom = await _client
          .from('messages')
          .select('sender_id')
          .eq('recipient_id', currentUserId!)
          .order('sent_at', ascending: false);

      final Set<String> userIds = {};
      for (var msg in sentTo) {
        userIds.add(msg['recipient_id']);
      }
      for (var msg in receivedFrom) {
        userIds.add(msg['sender_id']);
      }

      if (userIds.isEmpty) return [];

      final users = await _client
          .from('users')
          .select('id, display_name, is_online')
          .inFilter('id', userIds.toList());

      List<Conversation> conversations = [];
      for (var user in users) {
        final oderId = user['id'];

        // Last message
        final lastMsgResponse = await _client
            .from('messages')
            .select()
            .or('and(sender_id.eq.$currentUserId,recipient_id.eq.$oderId),'
                'and(sender_id.eq.$oderId,recipient_id.eq.$currentUserId)')
            .order('sent_at', ascending: false)
            .limit(1);

        String? lastMessage;
        DateTime? lastMessageTime;
        if (lastMsgResponse.isNotEmpty) {
          lastMessage = lastMsgResponse[0]['content_text'];

          if (lastMessage == null || lastMessage.isEmpty) {
            final encContent = lastMsgResponse[0]['encrypted_content'];
            final bytes = _parseEncryptedContent(encContent);
            if (bytes != null) {
              lastMessage = _bytesToString(bytes);
            }
          }
          lastMessageTime = DateTime.parse(lastMsgResponse[0]['sent_at']);
        }

        // Unread count
        final unreadResponse = await _client
            .from('messages')
            .select()
            .eq('sender_id', oderId)
            .eq('recipient_id', currentUserId!)
            .neq('status', 'read');

        conversations.add(Conversation(
          oderId: oderId,
          odername: user['display_name'] ?? 'Unknown',
          lastMessage: lastMessage,
          lastMessageTime: lastMessageTime,
          unreadCount: (unreadResponse as List).length,
          isOnline: user['is_online'] ?? false,
        ));
      }

      conversations.sort((a, b) {
        if (a.lastMessageTime == null) return 1;
        if (b.lastMessageTime == null) return -1;
        return b.lastMessageTime!.compareTo(a.lastMessageTime!);
      });

      return conversations;
    } catch (e) {
      print('[MessageService] Conversations error: $e');
      return [];
    }
  }

  // ─── Realtime ───

  /// Subscribe to new message inserts and status updates.
  void subscribeToMessages() {
    if (currentUserId == null) return;

    final channel = _client.channel('messages_channel_$currentUserId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: currentUserId!,
          ),
          callback: (payload) async {
            final json = payload.newRecord;
            final msg = await _parseMessage(json);

            _messageController.add(msg);

            // Auto mark as delivered
            markAsDelivered(msg.id);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            final json = payload.newRecord;
            final msg = await _parseMessage(json);
            _messageController.add(msg);
          },
        )
        .subscribe((status, [error]) {
      print('[Realtime] Subscription status: $status');
    });
  }

  // ─── Read receipts ───

  Future<void> markAsRead(String messageId) async {
    try {
      await _client.from('messages').update({
        'status': 'read',
        'read_at': DateTime.now().toIso8601String(),
      }).eq('id', messageId);
    } catch (e) {
      print('[MessageService] markAsRead error: $e');
    }
  }

  Future<void> markAsDelivered(String messageId) async {
    try {
      await _client.from('messages').update({
        'status': 'delivered',
        'delivered_at': DateTime.now().toIso8601String(),
      }).eq('id', messageId);
    } catch (e) {
      print('[MessageService] markAsDelivered error: $e');
    }
  }

  // ─── Retry queue flush ───

  /// Try to send all queued messages. Call this when connectivity returns.
  Future<int> flushRetryQueue() async {
    if (_encryption == null) return 0;

    final queued = await _encryption!.getPendingQueue();
    if (queued.isEmpty) return 0;

    final sentIds = <String>[];
    for (final msg in queued) {
      try {
        await _client.from('messages').insert({
          'sender_id': currentUserId,
          'recipient_id': msg.recipientId,
          'encrypted_content': msg.encryptedContent.toList(),
          'message_type': 'text',
          'status': 'sent',
        });
        sentIds.add(msg.id);
      } catch (e) {
        print('[MessageService] Retry send failed for ${msg.id}: $e');
      }
    }

    await _encryption!.flushQueue(sentIds);
    print('[MessageService] Flushed ${sentIds.length} queued messages');
    return sentIds.length;
  }

  // ─── Helpers ───

  /// Parse encrypted_content from Supabase (handles hex, base64, List, JSON).
  List<int>? _parseEncryptedContent(dynamic raw) {
    if (raw == null) return null;
    if (raw is List) return List<int>.from(raw);

    if (raw is String) {
      // Hex string
      if (raw.startsWith('\\x') || raw.startsWith('\\\\x')) {
        final hex = raw.replaceAll(RegExp(r'^\\+x'), '');
        final bytes = <int>[];
        for (var i = 0; i < hex.length; i += 2) {
          bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
        }
        return bytes;
      }
      // JSON array
      if (raw.startsWith('[') && raw.endsWith(']')) {
        try {
          return List<int>.from(jsonDecode(raw));
        } catch (_) {}
      }
      // Base64
      try {
        return base64Decode(raw).toList();
      } catch (_) {}
      // Plain text codeUnits
      return raw.codeUnits;
    }
    return null;
  }

  /// Best-effort bytes → readable string.
  String _bytesToString(List<int> bytes) {
    try {
      return String.fromCharCodes(bytes);
    } catch (_) {
      return '<encrypted>';
    }
  }

  void dispose() {
    _messageSubscription?.cancel();
    _messageController.close();
  }
}

/// Global message service instance
final messageService = MessageService();
