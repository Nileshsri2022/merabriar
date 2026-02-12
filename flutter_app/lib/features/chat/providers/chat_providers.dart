import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/message_service.dart';
import '../../../services/user_service.dart';

// ══════════════════════════════════════════════════════════════
// Conversations Notifier — reactive chat list state
// ══════════════════════════════════════════════════════════════

/// State for the conversations list
class ConversationsState {
  final List<Conversation> conversations;
  final bool loading;
  final String? error;

  const ConversationsState({
    this.conversations = const [],
    this.loading = true,
    this.error,
  });

  ConversationsState copyWith({
    List<Conversation>? conversations,
    bool? loading,
    String? error,
  }) {
    return ConversationsState(
      conversations: conversations ?? this.conversations,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class ConversationsNotifier extends StateNotifier<ConversationsState> {
  ConversationsNotifier() : super(const ConversationsState());

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final convos = await messageService.getConversations();
      state = state.copyWith(conversations: convos, loading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), loading: false);
    }
  }

  /// Refresh conversations (same as load but can be called on pull-to-refresh)
  Future<void> refresh() => load();

  /// Called when a new message arrives to update last message preview
  void updateConversation(Conversation updated) {
    final convos = [...state.conversations];
    final idx = convos.indexWhere((c) => c.oderId == updated.oderId);
    if (idx >= 0) {
      convos[idx] = updated;
    } else {
      convos.insert(0, updated);
    }
    state = state.copyWith(conversations: convos);
  }
}

final conversationsProvider =
    StateNotifierProvider<ConversationsNotifier, ConversationsState>(
  (ref) => ConversationsNotifier(),
);

// ══════════════════════════════════════════════════════════════
// Messages Notifier — reactive per-chat message list
// ══════════════════════════════════════════════════════════════

/// State for a single chat's messages
class MessagesState {
  final List<Message> messages;
  final bool loading;
  final bool sending;
  final String? error;

  const MessagesState({
    this.messages = const [],
    this.loading = true,
    this.sending = false,
    this.error,
  });

  MessagesState copyWith({
    List<Message>? messages,
    bool? loading,
    bool? sending,
    String? error,
  }) {
    return MessagesState(
      messages: messages ?? this.messages,
      loading: loading ?? this.loading,
      sending: sending ?? this.sending,
      error: error,
    );
  }
}

class MessagesNotifier extends StateNotifier<MessagesState> {
  final String recipientId;

  MessagesNotifier(this.recipientId) : super(const MessagesState());

  Future<void> loadMessages() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final msgs = await messageService.getMessages(recipientId);
      state = state.copyWith(messages: msgs, loading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), loading: false);
    }
  }

  Future<void> sendMessage(String content) async {
    state = state.copyWith(sending: true);
    try {
      final message = await messageService.sendMessage(
        recipientId: recipientId,
        content: content,
      );

      if (message != null) {
        state = state.copyWith(
          messages: [...state.messages, message],
          sending: false,
        );
      } else {
        state = state.copyWith(sending: false);
      }
    } catch (e) {
      state = state.copyWith(sending: false, error: e.toString());
    }
  }

  void addIncomingMessage(Message message) {
    if (!state.messages.any((m) => m.id == message.id)) {
      state = state.copyWith(messages: [...state.messages, message]);
    }
  }

  void markAsRead(String messageId) {
    final msgs = state.messages.map((m) {
      if (m.id == messageId) {
        return Message(
          id: m.id,
          senderId: m.senderId,
          recipientId: m.recipientId,
          content: m.content,
          messageType: m.messageType,
          status: 'read',
          sentAt: m.sentAt,
        );
      }
      return m;
    }).toList();
    state = state.copyWith(messages: msgs);
  }
}

/// Family provider — one MessagesNotifier per recipientId
final messagesProvider =
    StateNotifierProvider.family<MessagesNotifier, MessagesState, String>(
  (ref, recipientId) => MessagesNotifier(recipientId),
);

// ══════════════════════════════════════════════════════════════
// Online Users — tracks who's currently online
// ══════════════════════════════════════════════════════════════

final allUsersProvider = FutureProvider<List<UserProfile>>((ref) async {
  return await userService.getAllUsers();
});

// ══════════════════════════════════════════════════════════════
// Current User Profile
// ══════════════════════════════════════════════════════════════

final currentUserProvider = FutureProvider<UserProfile?>((ref) async {
  return await userService.getCurrentProfile();
});

// ══════════════════════════════════════════════════════════════
// Individual User Profile — keyed by userId
// ══════════════════════════════════════════════════════════════

final userProfileProvider =
    FutureProvider.family<UserProfile?, String>((ref, userId) async {
  return await userService.getUser(userId);
});
