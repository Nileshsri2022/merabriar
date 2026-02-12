import 'package:flutter_test/flutter_test.dart';
import 'package:merabriar/features/chat/providers/chat_providers.dart';
import 'package:merabriar/services/message_service.dart';

void main() {
  // ══════════════════════════════════════════════════════════════
  // ConversationsState tests
  // ══════════════════════════════════════════════════════════════

  group('ConversationsState', () {
    test('default state has empty conversations and loading true', () {
      const state = ConversationsState();
      expect(state.conversations, isEmpty);
      expect(state.loading, isTrue);
      expect(state.error, isNull);
    });

    test('copyWith preserves unchanged values', () {
      const state = ConversationsState(loading: false);
      final updated = state.copyWith(error: 'Network error');

      expect(updated.loading, isFalse);
      expect(updated.conversations, isEmpty);
      expect(updated.error, 'Network error');
    });

    test('copyWith clears error when omitted', () {
      final state = const ConversationsState().copyWith(error: 'Some error');
      expect(state.error, 'Some error');

      final cleared = state.copyWith();
      // error is nullable — copyWith sets it to null by default
      expect(cleared.error, isNull);
    });

    test('copyWith replaces conversations list', () {
      const state = ConversationsState();
      final conv = Conversation(
        oderId: 'u1',
        odername: 'Alice',
        lastMessage: 'Hi',
        lastMessageTime: DateTime(2026, 1, 1),
        unreadCount: 2,
        isOnline: true,
      );
      final updated = state.copyWith(conversations: [conv], loading: false);

      expect(updated.conversations, hasLength(1));
      expect(updated.conversations.first.odername, 'Alice');
      expect(updated.loading, isFalse);
    });
  });

  // ══════════════════════════════════════════════════════════════
  // MessagesState tests
  // ══════════════════════════════════════════════════════════════

  group('MessagesState', () {
    test('default state has loading true, sending false', () {
      const state = MessagesState();
      expect(state.messages, isEmpty);
      expect(state.loading, isTrue);
      expect(state.sending, isFalse);
      expect(state.error, isNull);
    });

    test('copyWith toggles sending', () {
      const state = MessagesState(loading: false);
      final sending = state.copyWith(sending: true);
      expect(sending.sending, isTrue);
      expect(sending.loading, isFalse);
    });

    test('copyWith preserves messages while toggling loading', () {
      final msg = _testMessage('m1', 'Hello');
      final state = MessagesState(messages: [msg], loading: false);
      final reloading = state.copyWith(loading: true);

      expect(reloading.messages, hasLength(1));
      expect(reloading.loading, isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════
  // ConversationsNotifier — local logic tests
  // ══════════════════════════════════════════════════════════════

  group('ConversationsNotifier', () {
    test('updateConversation inserts new conversation at front', () {
      final notifier = ConversationsNotifier();
      // Start with loaded empty list
      notifier.state = const ConversationsState(loading: false);

      final conv = Conversation(
        oderId: 'u1',
        odername: 'Alice',
        lastMessage: 'Hello',
        lastMessageTime: DateTime(2026, 1, 1),
        unreadCount: 1,
        isOnline: true,
      );

      notifier.updateConversation(conv);

      expect(notifier.state.conversations, hasLength(1));
      expect(notifier.state.conversations.first.odername, 'Alice');
    });

    test('updateConversation replaces existing conversation', () {
      final notifier = ConversationsNotifier();

      final conv1 = Conversation(
        oderId: 'u1',
        odername: 'Alice',
        lastMessage: 'Hello',
        lastMessageTime: DateTime(2026, 1, 1),
        unreadCount: 1,
        isOnline: true,
      );

      notifier.state = ConversationsState(
        conversations: [conv1],
        loading: false,
      );

      // Update same conversation with new message
      final conv1Updated = Conversation(
        oderId: 'u1',
        odername: 'Alice',
        lastMessage: 'Updated message',
        lastMessageTime: DateTime(2026, 1, 2),
        unreadCount: 2,
        isOnline: true,
      );

      notifier.updateConversation(conv1Updated);

      expect(notifier.state.conversations, hasLength(1));
      expect(notifier.state.conversations.first.lastMessage, 'Updated message');
      expect(notifier.state.conversations.first.unreadCount, 2);
    });

    test('updateConversation inserts if oderId not found', () {
      final notifier = ConversationsNotifier();

      final conv1 = Conversation(
        oderId: 'u1',
        odername: 'Alice',
        lastMessage: 'Hello',
        lastMessageTime: DateTime(2026, 1, 1),
        unreadCount: 0,
        isOnline: false,
      );

      notifier.state = ConversationsState(
        conversations: [conv1],
        loading: false,
      );

      final conv2 = Conversation(
        oderId: 'u2',
        odername: 'Bob',
        lastMessage: 'Hey!',
        lastMessageTime: DateTime(2026, 1, 2),
        unreadCount: 1,
        isOnline: true,
      );

      notifier.updateConversation(conv2);

      expect(notifier.state.conversations, hasLength(2));
      // New conversations go to the front
      expect(notifier.state.conversations.first.odername, 'Bob');
    });
  });

  // ══════════════════════════════════════════════════════════════
  // MessagesNotifier — local logic tests
  // ══════════════════════════════════════════════════════════════

  group('MessagesNotifier', () {
    test('addIncomingMessage adds new message', () {
      final notifier = MessagesNotifier('recipient-1');
      notifier.state = const MessagesState(loading: false);

      final msg = _testMessage('m1', 'Hello!');
      notifier.addIncomingMessage(msg);

      expect(notifier.state.messages, hasLength(1));
      expect(notifier.state.messages.first.content, 'Hello!');
    });

    test('addIncomingMessage deduplicates by id', () {
      final notifier = MessagesNotifier('recipient-1');
      final msg = _testMessage('m1', 'Hello!');
      notifier.state = MessagesState(messages: [msg], loading: false);

      // Add same message again
      notifier.addIncomingMessage(msg);

      expect(notifier.state.messages, hasLength(1));
    });

    test('addIncomingMessage allows different IDs', () {
      final notifier = MessagesNotifier('recipient-1');
      notifier.state = MessagesState(
        messages: [_testMessage('m1', 'First')],
        loading: false,
      );

      notifier.addIncomingMessage(_testMessage('m2', 'Second'));

      expect(notifier.state.messages, hasLength(2));
    });

    test('markAsRead updates message status', () {
      final notifier = MessagesNotifier('recipient-1');
      final msg = _testMessage('m1', 'Hello!', status: 'delivered');
      notifier.state = MessagesState(messages: [msg], loading: false);

      notifier.markAsRead('m1');

      expect(notifier.state.messages.first.status, 'read');
    });

    test('markAsRead preserves other messages', () {
      final notifier = MessagesNotifier('recipient-1');
      notifier.state = MessagesState(
        messages: [
          _testMessage('m1', 'First', status: 'delivered'),
          _testMessage('m2', 'Second', status: 'delivered'),
        ],
        loading: false,
      );

      notifier.markAsRead('m1');

      expect(notifier.state.messages[0].status, 'read');
      expect(notifier.state.messages[1].status, 'delivered');
    });

    test('markAsRead does nothing for unknown ID', () {
      final notifier = MessagesNotifier('recipient-1');
      notifier.state = MessagesState(
        messages: [_testMessage('m1', 'Hello', status: 'sent')],
        loading: false,
      );

      notifier.markAsRead('non-existent');

      expect(notifier.state.messages.first.status, 'sent');
    });
  });
}

/// Helper to create a test message
Message _testMessage(String id, String content, {String status = 'sent'}) {
  return Message(
    id: id,
    senderId: 'sender-1',
    recipientId: 'recipient-1',
    content: content,
    messageType: 'text',
    status: status,
    sentAt: DateTime(2026, 1, 1, 12, 0),
  );
}
