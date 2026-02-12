import 'package:flutter_test/flutter_test.dart';

import 'package:merabriar/services/user_service.dart';

void main() {
  group('UserProfile Model', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'id': 'user-123',
        'phone_hash': 'abc123hash',
        'display_name': 'Alice',
        'avatar_url': 'https://example.com/avatar.png',
        'is_online': true,
        'last_seen': '2026-02-12T10:00:00Z',
        'identity_public_key': [1, 2, 3, 4, 5, 6, 7, 8],
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.id, 'user-123');
      expect(profile.phoneHash, 'abc123hash');
      expect(profile.displayName, 'Alice');
      expect(profile.avatarUrl, 'https://example.com/avatar.png');
      expect(profile.isOnline, true);
      expect(profile.lastSeen, DateTime.parse('2026-02-12T10:00:00Z'));
      expect(profile.hasKeys, true); // List length > 1
    });

    test('fromJson handles minimal fields', () {
      final json = {
        'id': 'user-456',
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.id, 'user-456');
      expect(profile.phoneHash, isNull);
      expect(profile.displayName, isNull);
      expect(profile.avatarUrl, isNull);
      expect(profile.isOnline, false);
      expect(profile.lastSeen, isNull);
      expect(profile.hasKeys, false);
    });

    test('hasKeys is false for placeholder key [0]', () {
      final json = {
        'id': 'user-789',
        'identity_public_key': [0],
      };

      final profile = UserProfile.fromJson(json);
      expect(profile.hasKeys, false); // List with only 1 element
    });

    test('hasKeys is true for real key list', () {
      final json = {
        'id': 'user-abc',
        'identity_public_key': [10, 20, 30, 40],
      };

      final profile = UserProfile.fromJson(json);
      expect(profile.hasKeys, true);
    });

    test('hasKeys is true for real key string', () {
      final json = {
        'id': 'user-def',
        'identity_public_key': 'abcdefghijklmnop',
      };

      final profile = UserProfile.fromJson(json);
      expect(profile.hasKeys, true); // String length > 4
    });

    test('hasKeys is false for short key string', () {
      final json = {
        'id': 'user-ghi',
        'identity_public_key': 'abc',
      };

      final profile = UserProfile.fromJson(json);
      expect(profile.hasKeys, false); // String length <= 4
    });

    test('default values are correct', () {
      final profile = UserProfile(id: 'test-123');

      expect(profile.isOnline, false);
      expect(profile.hasKeys, false);
      expect(profile.displayName, isNull);
      expect(profile.avatarUrl, isNull);
      expect(profile.phoneHash, isNull);
      expect(profile.lastSeen, isNull);
    });
  });
}
