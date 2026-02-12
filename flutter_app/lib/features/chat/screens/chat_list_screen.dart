import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/app_theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/connectivity_banner.dart';
import '../../../core/widgets/error_state.dart';
import '../../../services/message_service.dart';
import '../../../services/user_service.dart';
import '../providers/chat_providers.dart';

/// Premium Chat List Screen
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen>
    with SingleTickerProviderStateMixin, ConnectivityMixin {
  late AnimationController _fabController;
  late Animation<double> _fabScale;

  @override
  void initState() {
    super.initState();

    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fabScale = CurvedAnimation(
      parent: _fabController,
      curve: Curves.easeOutBack,
    );

    _loadData();
    messageService.subscribeToMessages();

    messageService.messageStream.listen((_) {
      ref.read(conversationsProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  @override
  void onConnectivityChanged(ConnectivityStatus status) {
    final convState = ref.read(conversationsProvider);
    if (status == ConnectivityStatus.online && convState.error != null) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final hasProfile = await userService.hasProfile();
    if (!hasProfile) {
      final email = Supabase.instance.client.auth.currentUser?.email ?? '';
      final displayName = email.split('@').first;
      await userService.createOrUpdateProfile(displayName: displayName);
    }

    await ref.read(conversationsProvider.notifier).load();
    // Refresh allUsersProvider
    ref.invalidate(allUsersProvider);

    _fabController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final convState = ref.watch(conversationsProvider);
    final usersAsync = ref.watch(allUsersProvider);
    final allUsers = usersAsync.valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.eco, size: 22),
            SizedBox(width: 8),
            Text('MeraBriar'),
          ],
        ),
        actions: [
          // Search
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchSheet(context),
            tooltip: 'Search contacts',
          ),
          // Settings
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              context.push('/settings');
            },
            tooltip: 'Settings',
          ),
          // More options
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                await userService.setOnlineStatus(false);
                await Supabase.instance.client.auth.signOut();
                if (mounted) {
                  context.go('/login');
                }
              } else if (value == 'refresh') {
                _loadData();
              }
            },
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 20),
                    SizedBox(width: 10),
                    Text('Refresh'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 10),
                    Text('Sign Out'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          ConnectivityBanner(
            isOffline: isOffline,
            onRetry: () {
              recheckConnectivity();
              _loadData();
            },
          ),
          Expanded(
            child: convState.loading
                ? _buildShimmerList()
                : _buildBody(theme, isDark, convState, allUsers),
          ),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabScale,
        child: FloatingActionButton(
          onPressed: () => _showNewChatSheet(context),
          tooltip: 'New chat',
          child: const Icon(Icons.edit_square),
        ),
      ),
    );
  }

  // ── Loading Shimmer ──
  Widget _buildShimmerList() {
    return ListView.builder(
      itemCount: 6,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        return _ShimmerTile(delay: index * 100);
      },
    );
  }

  // ── Main Body ──
  Widget _buildBody(ThemeData theme, bool isDark, ConversationsState convState,
      List<UserProfile> allUsers) {
    if (convState.error != null) {
      return ErrorStateWidget.connection(onRetry: _loadData);
    }

    if (convState.conversations.isEmpty) {
      return _buildEmptyState(theme, allUsers);
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.brandGreen,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: convState.conversations.length,
        separatorBuilder: (_, __) =>
            const Divider(indent: 82, endIndent: 16, height: 0),
        itemBuilder: (context, index) {
          final conv = convState.conversations[index];
          return StaggerSlideIn(
            index: index,
            child: _ConversationTile(
              conversation: conv,
              onTap: () {
                context
                    .push(
                      '/chats/${conv.oderId}?name=${Uri.encodeComponent(conv.odername)}',
                    )
                    .then((_) =>
                        ref.read(conversationsProvider.notifier).refresh());
              },
              onLongPress: () => _showContactProfile(conv),
            ),
          );
        },
      ),
    );
  }

  // ── Empty State ──
  Widget _buildEmptyState(ThemeData theme, List<UserProfile> allUsers) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.brandGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline,
                size: 48,
                color: AppTheme.brandGreen.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No conversations yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the ✏️ button to start a\nnew encrypted conversation',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            if (allUsers.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.brandGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${allUsers.length} contacts available',
                  style: TextStyle(
                    color: AppTheme.brandGreen,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Contact Profile ──
  void _showContactProfile(Conversation conv) {
    context.push(
      '/contact/${conv.oderId}?name=${Uri.encodeComponent(conv.odername)}',
    );
  }

  // ── Search Sheet ──
  void _showSearchSheet(BuildContext context) {
    final searchController = TextEditingController();
    List<UserProfile> results = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search contacts...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (query) async {
                    if (query.trim().length >= 2) {
                      final found = await userService.searchUsers(query.trim());
                      setSheetState(() => results = found);
                    } else {
                      setSheetState(() => results = []);
                    }
                  },
                ),
              ),
              const Divider(height: 0),
              Expanded(
                child: results.isEmpty
                    ? Center(
                        child: Text(
                          searchController.text.length < 2
                              ? 'Type at least 2 characters...'
                              : 'No users found',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final user = results[index];
                          return _UserTile(
                            user: user,
                            onTap: () {
                              Navigator.pop(context);
                              context
                                  .push(
                                    '/chats/${user.id}?name=${Uri.encodeComponent(user.displayName ?? 'Unknown')}',
                                  )
                                  .then((_) => ref
                                      .read(conversationsProvider.notifier)
                                      .refresh());
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── New Chat Sheet ──
  void _showNewChatSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.people, color: AppTheme.brandGreen),
                  const SizedBox(width: 10),
                  const Text(
                    'Start New Chat',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 0),
            Expanded(
              child: ref.watch(allUsersProvider).when(
                    data: (allUsers) => allUsers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline,
                                    size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  'No contacts found',
                                  style: TextStyle(color: Colors.grey.shade500),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Invite friends to join MeraBriar',
                                  style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: allUsers.length,
                            separatorBuilder: (_, __) =>
                                const Divider(indent: 72, height: 0),
                            itemBuilder: (context, index) {
                              final user = allUsers[index];
                              return _UserTile(
                                user: user,
                                onTap: () {
                                  Navigator.pop(context);
                                  context
                                      .push(
                                        '/chats/${user.id}?name=${Uri.encodeComponent(user.displayName ?? 'Unknown')}',
                                      )
                                      .then((_) => ref
                                          .read(conversationsProvider.notifier)
                                          .refresh());
                                },
                              );
                            },
                          ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// Reusable Widgets
// ═══════════════════════════════════════════════

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ConversationTile({
    required this.conversation,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUnread = conversation.unreadCount > 0;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: hasUnread ? AppGradients.accentGradient : null,
                    color: hasUnread
                        ? null
                        : AppTheme.brandGreen.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      conversation.odername.isNotEmpty
                          ? conversation.odername[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: hasUnread ? Colors.white : AppTheme.brandGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                if (conversation.isOnline)
                  Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppTheme.success,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.odername,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessage ?? 'No messages yet',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: hasUnread
                                ? theme.colorScheme.onSurface.withOpacity(0.7)
                                : theme.colorScheme.onSurface.withOpacity(0.4),
                            fontWeight:
                                hasUnread ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Time & Badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (conversation.lastMessageTime != null)
                  Text(
                    _formatTime(conversation.lastMessageTime!),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          hasUnread ? FontWeight.w600 : FontWeight.normal,
                      color: hasUnread
                          ? AppTheme.brandGreen
                          : theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                if (hasUnread) ...[
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    height: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.brandGreen,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Center(
                      child: Text(
                        conversation.unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays > 0) {
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${time.day}/${time.month}';
    }
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _UserTile extends StatelessWidget {
  final UserProfile user;
  final VoidCallback onTap;

  const _UserTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppTheme.brandGreen.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            user.displayName?.isNotEmpty == true
                ? user.displayName![0].toUpperCase()
                : '?',
            style: const TextStyle(
              color: AppTheme.brandGreen,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      ),
      title: Text(
        user.displayName ?? 'Unknown',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        user.isOnline ? 'Online' : 'Offline',
        style: TextStyle(
          fontSize: 13,
          color: user.isOnline ? AppTheme.success : Colors.grey.shade500,
        ),
      ),
      trailing: user.isOnline
          ? Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppTheme.success,
                shape: BoxShape.circle,
              ),
            )
          : null,
      onTap: onTap,
    );
  }
}

class _ShimmerTile extends StatefulWidget {
  final int delay;
  const _ShimmerTile({required this.delay});

  @override
  State<_ShimmerTile> createState() => _ShimmerTileState();
}

class _ShimmerTileState extends State<_ShimmerTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        isDark ? const Color(0xFF1B2838) : const Color(0xFFEEEEEE);
    final highlightColor =
        isDark ? const Color(0xFF243447) : const Color(0xFFF5F5F5);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(radius: 26, backgroundColor: baseColor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 14,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 200,
                  height: 12,
                  decoration: BoxDecoration(
                    color: highlightColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
