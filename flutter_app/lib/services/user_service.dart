import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/di/providers.dart' show DevMode;

/// User profile model
class UserProfile {
  final String id;
  final String? phoneHash;
  final String? displayName;
  final String? avatarUrl;
  final bool isOnline;
  final DateTime? lastSeen;

  UserProfile({
    required this.id,
    this.phoneHash,
    this.displayName,
    this.avatarUrl,
    this.isOnline = false,
    this.lastSeen,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      phoneHash: json['phone_hash'],
      displayName: json['display_name'],
      avatarUrl: json['avatar_url'],
      isOnline: json['is_online'] ?? false,
      lastSeen:
          json['last_seen'] != null ? DateTime.parse(json['last_seen']) : null,
    );
  }
}

/// User Service - handles user operations
class UserService {
  final SupabaseClient _client = Supabase.instance.client;

  // DEV MODE: Use DevMode for dynamic user switching
  String? get currentUserId =>
      _client.auth.currentUser?.id ?? DevMode.currentUserId;

  /// Create or update user profile
  Future<bool> createOrUpdateProfile({
    required String displayName,
    String? phoneHash,
    List<int>? identityPublicKey,
    List<int>? signedPrekey,
    List<int>? signedPrekeySignature,
  }) async {
    if (currentUserId == null) return false;

    try {
      await _client.from('users').upsert({
        'id': currentUserId,
        'display_name': displayName,
        'phone_hash': phoneHash ?? 'email_${currentUserId}',
        'identity_public_key': identityPublicKey ?? [0], // Placeholder
        'signed_prekey': signedPrekey ?? [0], // Placeholder
        'signed_prekey_signature': signedPrekeySignature ?? [0], // Placeholder
        'is_online': true,
        'last_seen': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error creating/updating profile: $e');
      return false;
    }
  }

  /// Get current user profile
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
      print('Error getting profile: $e');
      return null;
    }
  }

  /// Get user by ID
  Future<UserProfile?> getUser(String userId) async {
    try {
      final response =
          await _client.from('users').select().eq('id', userId).maybeSingle();

      if (response == null) return null;
      return UserProfile.fromJson(response);
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  /// Search users by display name
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
      print('Error searching users: $e');
      return [];
    }
  }

  /// Get all users (for testing)
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
      print('Error getting all users: $e');
      return [];
    }
  }

  /// Update online status
  Future<void> setOnlineStatus(bool isOnline) async {
    if (currentUserId == null) return;

    try {
      await _client.from('users').update({
        'is_online': isOnline,
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('id', currentUserId!);
    } catch (e) {
      print('Error updating online status: $e');
    }
  }

  /// Check if current user has a profile
  Future<bool> hasProfile() async {
    final profile = await getCurrentProfile();
    return profile != null;
  }
}

/// Global user service instance
final userService = UserService();
