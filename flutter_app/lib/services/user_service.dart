import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/di/providers.dart' show DevMode;
import 'encryption_service.dart';

/// User profile model
class UserProfile {
  final String id;
  final String? phoneHash;
  final String? displayName;
  final String? avatarUrl;
  final bool isOnline;
  final DateTime? lastSeen;
  final bool hasKeys;

  UserProfile({
    required this.id,
    this.phoneHash,
    this.displayName,
    this.avatarUrl,
    this.isOnline = false,
    this.lastSeen,
    this.hasKeys = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // Determine if user has real keys (not placeholder [0])
    bool keysPresent = false;
    final idKey = json['identity_public_key'];
    if (idKey != null) {
      if (idKey is List && idKey.length > 1) keysPresent = true;
      if (idKey is String && idKey.length > 4) keysPresent = true;
    }

    return UserProfile(
      id: json['id'],
      phoneHash: json['phone_hash'],
      displayName: json['display_name'],
      avatarUrl: json['avatar_url'],
      isOnline: json['is_online'] ?? false,
      lastSeen:
          json['last_seen'] != null ? DateTime.parse(json['last_seen']) : null,
      hasKeys: keysPresent,
    );
  }
}

/// User Service — handles profiles, online presence, and key upload.
class UserService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Encryption service — injected after core init.
  EncryptionService? _encryption;

  /// Supabase Realtime channel for presence tracking.
  RealtimeChannel? _presenceChannel;

  String? get currentUserId =>
      _client.auth.currentUser?.id ?? DevMode.currentUserId;

  /// Attach the encryption service.
  void setEncryptionService(EncryptionService service) {
    _encryption = service;
  }

  // ─── Profile CRUD ───

  /// Create or update user profile.
  /// If EncryptionService is attached, generates and uploads real keys.
  Future<bool> createOrUpdateProfile({
    required String displayName,
    String? phoneHash,
    bool generateKeys = false,
  }) async {
    if (currentUserId == null) return false;

    try {
      // Base profile data
      final profileData = <String, dynamic>{
        'id': currentUserId,
        'display_name': displayName,
        'phone_hash': phoneHash ?? 'email_$currentUserId',
        'is_online': true,
        'last_seen': DateTime.now().toIso8601String(),
      };

      // Generate and include real keys if requested & encryption is available
      if (generateKeys && _encryption != null) {
        final keys = await _encryption!.generateAndUploadKeys();

        profileData['identity_public_key'] = keys.identityPublicKey.toList();
        profileData['signed_prekey'] = keys.signedPreKey.toList();
        profileData['signed_prekey_signature'] = keys.signature.toList();
      } else {
        // Placeholder keys for users without core initialised
        profileData['identity_public_key'] = [0];
        profileData['signed_prekey'] = [0];
        profileData['signed_prekey_signature'] = [0];
      }

      await _client.from('users').upsert(profileData);
      print('[UserService] Profile saved for $displayName');
      return true;
    } catch (e) {
      print('[UserService] Profile save error: $e');
      return false;
    }
  }

  /// Upload real keys (call after core init if keys were placeholders).
  Future<bool> uploadKeysIfNeeded() async {
    if (_encryption == null || currentUserId == null) return false;

    try {
      final profile = await getCurrentProfile();
      if (profile != null && !profile.hasKeys) {
        await _encryption!.generateAndUploadKeys();
        print('[UserService] Keys uploaded for ${profile.displayName}');
        return true;
      }
      return false;
    } catch (e) {
      print('[UserService] Key upload error: $e');
      return false;
    }
  }

  // ─── Profile lookup ───

  Future<UserProfile?> getCurrentProfile() async {
    if (currentUserId == null) return null;

    try {
      final response = await _client
          .from('users')
          .select()
          .eq('id', currentUserId!)
          .maybeSingle();

      if (response == null) return null;
      return UserProfile.fromJson(response);
    } catch (e) {
      print('[UserService] Get profile error: $e');
      return null;
    }
  }

  Future<UserProfile?> getUser(String userId) async {
    try {
      final response =
          await _client.from('users').select().eq('id', userId).maybeSingle();

      if (response == null) return null;
      return UserProfile.fromJson(response);
    } catch (e) {
      print('[UserService] Get user error: $e');
      return null;
    }
  }

  Future<List<UserProfile>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    try {
      final userId = currentUserId;

      List<dynamic> response;
      if (userId != null && userId.isNotEmpty) {
        response = await _client
            .from('users')
            .select()
            .ilike('display_name', '%$query%')
            .neq('id', userId)
            .limit(20);
      } else {
        response = await _client
            .from('users')
            .select()
            .ilike('display_name', '%$query%')
            .limit(20);
      }

      return response
          .map((json) => UserProfile.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('[UserService] Search error: $e');
      return [];
    }
  }

  Future<List<UserProfile>> getAllUsers() async {
    try {
      final userId = currentUserId;

      List<dynamic> response;
      if (userId != null && userId.isNotEmpty) {
        response =
            await _client.from('users').select().neq('id', userId).limit(50);
      } else {
        response = await _client.from('users').select().limit(50);
      }

      return response
          .map((json) => UserProfile.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('[UserService] Get all users error: $e');
      return [];
    }
  }

  // ─── Online presence ───

  Future<void> setOnlineStatus(bool isOnline) async {
    if (currentUserId == null) return;

    try {
      await _client.from('users').update({
        'is_online': isOnline,
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('id', currentUserId!);
    } catch (e) {
      print('[UserService] Online status error: $e');
    }
  }

  /// Subscribe to Supabase Presence for live online/offline indicators.
  void subscribeToPresence({
    Function(List<String> onlineUserIds)? onSync,
  }) {
    _presenceChannel?.unsubscribe();

    _presenceChannel = _client.channel('presence:lobby');

    _presenceChannel!.onPresenceSync((payload) {
      final state = _presenceChannel!.presenceState();
      final onlineIds = <String>[];
      for (final presenceState in state) {
        for (final presence in presenceState.presences) {
          final userId = presence.payload['user_id'];
          if (userId != null && userId is String) {
            onlineIds.add(userId);
          }
        }
      }
      onSync?.call(onlineIds);
    }).subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        // Track our own presence
        await _presenceChannel!.track({
          'user_id': currentUserId,
          'online_at': DateTime.now().toIso8601String(),
        });
        print('[Presence] Tracking started');
      }
    });
  }

  /// Untrack presence (call on sign-out).
  Future<void> untrackPresence() async {
    try {
      await _presenceChannel?.untrack();
      await _presenceChannel?.unsubscribe();
      _presenceChannel = null;
    } catch (_) {}
  }

  // ─── Contact management ───

  /// Block a contact.
  Future<bool> blockContact(String contactId) async {
    if (currentUserId == null) return false;

    try {
      await _client.from('contacts').upsert({
        'user_id': currentUserId,
        'contact_id': contactId,
        'is_blocked': true,
      });
      print('[UserService] Blocked $contactId');
      return true;
    } catch (e) {
      print('[UserService] Block error: $e');
      return false;
    }
  }

  /// Unblock a contact.
  Future<bool> unblockContact(String contactId) async {
    if (currentUserId == null) return false;

    try {
      await _client
          .from('contacts')
          .update({'is_blocked': false})
          .eq('user_id', currentUserId!)
          .eq('contact_id', contactId);
      return true;
    } catch (e) {
      print('[UserService] Unblock error: $e');
      return false;
    }
  }

  /// Check if a contact is blocked.
  Future<bool> isBlocked(String contactId) async {
    if (currentUserId == null) return false;

    try {
      final response = await _client
          .from('contacts')
          .select('is_blocked')
          .eq('user_id', currentUserId!)
          .eq('contact_id', contactId)
          .maybeSingle();

      return response?['is_blocked'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasProfile() async {
    final profile = await getCurrentProfile();
    return profile != null;
  }
}

/// Global user service instance
final userService = UserService();
