import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/di/providers.dart' show DevMode;

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

  // Use DevMode for proper message alignment
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

/// Message Service - handles all messaging operations
class MessageService {
  final SupabaseClient _client = Supabase.instance.client;

  StreamSubscription? _messageSubscription;
  final _messageController = StreamController<Message>.broadcast();

  Stream<Message> get messageStream => _messageController.stream;

  // DEV MODE: Use DevMode for dynamic user switching
  String? get currentUserId =>
      _client.auth.currentUser?.id ?? DevMode.currentUserId;

  /// Send a message
  Future<Message?> sendMessage({
    required String recipientId,
    required String content,
  }) async {
    if (currentUserId == null) return null;

    try {
      // TODO: Encrypt message using Rust core
      // final encryptedContent = await rustCore.encryptMessage(recipientId, content);

      // For now, store as plain text (encryption placeholder)
      final contentBytes = content.codeUnits;

      final response = await _client
          .from('messages')
          .insert({
            'sender_id': currentUserId,
            'recipient_id': recipientId,
            'content_text': content, // Plain text for now
            'encrypted_content': contentBytes, // Keep for future encryption
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
        encryptedContent: contentBytes,
        status: 'sent',
        sentAt: DateTime.now(),
      );
    } catch (e) {
      print('Error sending message: $e');
      return null;
    }
  }

  /// Get messages for a conversation
  Future<List<Message>> getMessages(String oderId, {int limit = 50}) async {
    if (currentUserId == null) return [];

    try {
      final response = await _client
          .from('messages')
          .select()
          .or('and(sender_id.eq.$currentUserId,recipient_id.eq.$oderId),and(sender_id.eq.$oderId,recipient_id.eq.$currentUserId)')
          .order('sent_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) {
            // Use plain text content if available
            String content = json['content_text'] ?? '';
            List<int>? contentBytes;

            // Fall back to encrypted_content if no plain text
            if (content.isEmpty) {
              final encryptedContent = json['encrypted_content'];
              // Handle different formats from Supabase
              if (encryptedContent is String) {
                String strContent = encryptedContent;

                // Try base64 first (new format)
                try {
                  contentBytes = base64Decode(strContent);
                  content = String.fromCharCodes(contentBytes);
                } catch (e) {
                  // Not base64, try other formats

                  // Check if it's a JSON array like "[104,101,108,108,111]"
                  if (strContent.startsWith('[') && strContent.endsWith(']')) {
                    try {
                      final List<dynamic> decoded = jsonDecode(strContent);
                      contentBytes = decoded.cast<int>().toList();
                      content = String.fromCharCodes(contentBytes);
                    } catch (e) {
                      content = strContent;
                    }
                  } else if (strContent.startsWith('\\x')) {
                    // It's a hex string
                    String hexStr = strContent.substring(2);
                    try {
                      contentBytes = [];
                      for (int i = 0; i < hexStr.length; i += 2) {
                        contentBytes.add(
                            int.parse(hexStr.substring(i, i + 2), radix: 16));
                      }
                      content = String.fromCharCodes(contentBytes);
                    } catch (e) {
                      content = hexStr;
                    }
                  } else {
                    // Plain text
                    content = strContent;
                  }
                }
              } else if (encryptedContent is List) {
                contentBytes = List<int>.from(encryptedContent);
                content = String.fromCharCodes(contentBytes);
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
              readAt: json['read_at'] != null
                  ? DateTime.parse(json['read_at'])
                  : null,
            );
          })
          .toList()
          .reversed
          .toList(); // Reverse to show oldest first
    } catch (e) {
      print('Error getting messages: $e');
      return [];
    }
  }

  /// Get all conversations (users we've chatted with)
  Future<List<Conversation>> getConversations() async {
    if (currentUserId == null) return [];

    try {
      // Get distinct users we've messaged with
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

      // Combine unique user IDs
      final Set<String> userIds = {};
      for (var msg in sentTo) {
        userIds.add(msg['recipient_id']);
      }
      for (var msg in receivedFrom) {
        userIds.add(msg['sender_id']);
      }

      if (userIds.isEmpty) return [];

      // Get user details
      final users = await _client
          .from('users')
          .select('id, display_name, is_online')
          .inFilter('id', userIds.toList());

      // Build conversations with last message
      List<Conversation> conversations = [];
      for (var user in users) {
        final oderId = user['id'];

        // Get last message
        final lastMsgResponse = await _client
            .from('messages')
            .select()
            .or('and(sender_id.eq.$currentUserId,recipient_id.eq.$oderId),and(sender_id.eq.$oderId,recipient_id.eq.$currentUserId)')
            .order('sent_at', ascending: false)
            .limit(1);

        String? lastMessage;
        DateTime? lastMessageTime;
        if (lastMsgResponse.isNotEmpty) {
          // Use plain text content if available
          lastMessage = lastMsgResponse[0]['content_text'];

          // Fall back to encrypted_content decoding
          if (lastMessage == null || lastMessage.isEmpty) {
            final encContent = lastMsgResponse[0]['encrypted_content'];
            if (encContent != null) {
              // Handle different formats from Supabase
              if (encContent is String) {
                String strContent = encContent;

                // Try base64 first (new format)
                try {
                  final bytes = base64Decode(strContent);
                  lastMessage = String.fromCharCodes(bytes);
                } catch (e) {
                  // Not base64, try other formats
                  if (strContent.startsWith('[') && strContent.endsWith(']')) {
                    try {
                      final List<dynamic> decoded = jsonDecode(strContent);
                      lastMessage = String.fromCharCodes(decoded.cast<int>());
                    } catch (e) {
                      lastMessage = strContent;
                    }
                  } else if (strContent.startsWith('\\x')) {
                    String hexStr = strContent.substring(2);
                    try {
                      List<int> bytes = [];
                      for (int i = 0; i < hexStr.length; i += 2) {
                        bytes.add(
                            int.parse(hexStr.substring(i, i + 2), radix: 16));
                      }
                      lastMessage = String.fromCharCodes(bytes);
                    } catch (e) {
                      lastMessage = hexStr;
                    }
                  } else {
                    lastMessage = strContent;
                  }
                }
              } else if (encContent is List) {
                lastMessage = String.fromCharCodes(List<int>.from(encContent));
              }
            }
          }
          lastMessageTime = DateTime.parse(lastMsgResponse[0]['sent_at']);
        }

        // Count unread
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

      // Sort by last message time
      conversations.sort((a, b) {
        if (a.lastMessageTime == null) return 1;
        if (b.lastMessageTime == null) return -1;
        return b.lastMessageTime!.compareTo(a.lastMessageTime!);
      });

      return conversations;
    } catch (e) {
      print('Error getting conversations: $e');
      return [];
    }
  }

  /// Subscribe to new messages (realtime)
  void subscribeToMessages() {
    if (currentUserId == null) return;

    // Use Supabase Realtime channels for INSERT events
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
          callback: (payload) {
            final json = payload.newRecord;

            // Use plain text content if available
            String content = json['content_text'] ?? '';

            // Fall back to encrypted_content decoding
            if (content.isEmpty) {
              final encContent = json['encrypted_content'];
              if (encContent != null && encContent is String) {
                content = encContent;
              }
            }

            _messageController.add(Message(
              id: json['id'],
              senderId: json['sender_id'],
              recipientId: json['recipient_id'],
              content: content,
              status: json['status'] ?? 'sent',
              sentAt: DateTime.parse(json['sent_at']),
            ));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            // Notify about message updates (e.g., status changes for read receipts)
            final json = payload.newRecord;
            String content = json['content_text'] ?? '';

            _messageController.add(Message(
              id: json['id'],
              senderId: json['sender_id'],
              recipientId: json['recipient_id'],
              content: content,
              status: json['status'] ?? 'sent',
              sentAt: DateTime.parse(json['sent_at']),
            ));
          },
        )
        .subscribe((status, [error]) {
      // Subscription active
    });
  }

  /// Mark message as read
  Future<void> markAsRead(String messageId) async {
    try {
      await _client.from('messages').update({
        'status': 'read',
        'read_at': DateTime.now().toIso8601String(),
      }).eq('id', messageId);
    } catch (e) {
      print('Error marking message as read: $e');
    }
  }

  /// Mark message as delivered
  Future<void> markAsDelivered(String messageId) async {
    try {
      await _client.from('messages').update({
        'status': 'delivered',
        'delivered_at': DateTime.now().toIso8601String(),
      }).eq('id', messageId);
    } catch (e) {
      print('Error marking message as delivered: $e');
    }
  }

  /// Cleanup
  void dispose() {
    _messageSubscription?.cancel();
    _messageController.close();
  }
}

/// Global message service instance
final messageService = MessageService();
