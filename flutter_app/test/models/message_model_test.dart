import 'package:flutter_test/flutter_test.dart';

import 'package:merabriar/services/message_service.dart';

void main() {
  group('Message Model', () {
    test('fromJson parses correctly with all fields', () {
      final json = {
        'id': 'msg-123',
        'sender_id': 'user-1',
        'recipient_id': 'user-2',
        'content': null,
        'content_text': 'Hello world',
        'encrypted_content': null,
        'message_type': 'text',
        'status': 'delivered',
        'sent_at': '2026-02-12T10:00:00Z',
        'delivered_at': '2026-02-12T10:00:05Z',
        'read_at': null,
      };

      final msg = Message.fromJson(json);

      expect(msg.id, 'msg-123');
      expect(msg.senderId, 'user-1');
      expect(msg.recipientId, 'user-2');
      expect(msg.messageType, 'text');
      expect(msg.status, 'delivered');
      expect(msg.sentAt, DateTime.parse('2026-02-12T10:00:00Z'));
      expect(msg.deliveredAt, DateTime.parse('2026-02-12T10:00:05Z'));
      expect(msg.readAt, isNull);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'msg-456',
        'sender_id': 'user-1',
        'recipient_id': 'user-2',
        'content': null,
        'sent_at': '2026-02-12T10:00:00Z',
      };

      final msg = Message.fromJson(json);

      expect(msg.content, '');
      expect(msg.messageType, 'text');
      expect(msg.status, 'pending');
      expect(msg.encryptedContent, isNull);
      expect(msg.deliveredAt, isNull);
      expect(msg.readAt, isNull);
    });

    test('toJson produces correct output', () {
      final msg = Message(
        id: 'msg-789',
        senderId: 'user-1',
        recipientId: 'user-2',
        content: 'Test message',
        sentAt: DateTime.parse('2026-02-12T10:00:00Z'),
        status: 'sent',
      );

      final json = msg.toJson();

      expect(json['id'], 'msg-789');
      expect(json['sender_id'], 'user-1');
      expect(json['recipient_id'], 'user-2');
      expect(json['message_type'], 'text');
      expect(json['status'], 'sent');
      // When no encryptedContent, it uses content.codeUnits
      expect(json['encrypted_content'], isNotNull);
    });

    test('toJson includes encrypted content when set', () {
      final msg = Message(
        id: 'msg-enc',
        senderId: 'user-1',
        recipientId: 'user-2',
        content: '',
        encryptedContent: [1, 2, 3, 4, 5],
        sentAt: DateTime.parse('2026-02-12T10:00:00Z'),
      );

      final json = msg.toJson();
      expect(json['encrypted_content'], [1, 2, 3, 4, 5]);
    });
  });

  group('Conversation Model', () {
    test('creates with required fields', () {
      final conv = Conversation(
        oderId: 'user-2',
        odername: 'Alice',
      );

      expect(conv.oderId, 'user-2');
      expect(conv.odername, 'Alice');
      expect(conv.lastMessage, isNull);
      expect(conv.lastMessageTime, isNull);
      expect(conv.unreadCount, 0);
      expect(conv.isOnline, false);
    });

    test('creates with all fields', () {
      final now = DateTime.now();
      final conv = Conversation(
        oderId: 'user-3',
        odername: 'Bob',
        lastMessage: 'Hey there',
        lastMessageTime: now,
        unreadCount: 3,
        isOnline: true,
      );

      expect(conv.oderId, 'user-3');
      expect(conv.odername, 'Bob');
      expect(conv.lastMessage, 'Hey there');
      expect(conv.lastMessageTime, now);
      expect(conv.unreadCount, 3);
      expect(conv.isOnline, true);
    });
  });
}
