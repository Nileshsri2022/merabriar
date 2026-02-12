# Week 7: Core Integration — Architecture & Status

## Overview

Week 7 wires the Flutter UI to the native core (Go/Rust) for real end-to-end encryption,
implements Supabase Realtime for message synchronization, and establishes the complete
message send/receive flow with read receipts.

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│                   Flutter UI                     │
│  (ChatScreen, ChatListScreen, SettingsScreen)    │
└────────────────┬───────────────────┬─────────────┘
                 │                   │
    ┌────────────▼────────┐  ┌──────▼────────────┐
    │   MessageService    │  │   UserService      │
    │  (send/recv/queue)  │  │  (profile/presence)│
    └────────────┬────────┘  └──────┬─────────────┘
                 │                   │
         ┌───────▼───────────────────▼────┐
         │      EncryptionService          │
         │  (key mgmt, session, E2E)       │
         └────────────┬───────────────────┘
                      │
         ┌────────────▼────────────┐
         │    MessengerCore        │
         │  (Go FFI / Rust FFI)    │
         └────────────┬────────────┘
                      │
         ┌────────────▼────────────┐
         │   Native Core (.dll)    │
         │  AES-256-GCM, X3DH,    │
         │  Double Ratchet,        │
         │  SQLCipher storage      │
         └─────────────────────────┘
```

---

## Files Modified / Created

### New Files

| File | Purpose |
|------|---------|
| `lib/services/encryption_service.dart` | Orchestrates key exchange, session management, encrypt/decrypt, prekey rotation, and offline queue |

### Modified Files

| File | Changes |
|------|---------|
| `lib/services/message_service.dart` | Wired to EncryptionService for E2E encryption on send/recv. Retry queue. Realtime decryption. |
| `lib/services/user_service.dart` | Real key upload, Supabase Presence tracking, block/unblock contacts |
| `lib/core/di/providers.dart` | Added `encryptionServiceProvider`, `messageServiceProvider`, `userServiceProvider`. Auto-wiring on init. |
| `lib/features/contacts/screens/contact_profile_screen.dart` | Block button now calls `userService.blockContact()` |

---

## Message Flow

### Send Flow
```
User types message  
  → MessageService.sendMessage()  
    → EncryptionService.encrypt(recipientId, plaintext)  
      → core.ensureSession() → core.encryptMessage()  
    → Supabase INSERT with encrypted_content (no plaintext on server)  
    → Returns Message with status: 'sent'
```

### Receive Flow (Realtime)
```
Supabase Realtime detects INSERT  
  → MessageService._parseMessage(json)  
    → EncryptionService.decrypt(senderId, ciphertext)  
      → core.decryptMessage()  
    → Message added to messageStream  
    → Auto mark as 'delivered'
```

### Read Receipt Flow
```
User opens conversation  
  → ChatScreen marks visible messages as 'read'  
  → Supabase UPDATE: status='read', read_at=now  
  → Sender receives UPDATE event via Realtime  
  → UI updates status icon (✓✓ blue)
```

---

## Encryption Key Exchange

### Initial Key Upload (on signup)
```
1. Core generates identity keypair (Ed25519)
2. Core generates signed pre-key (X25519)
3. Core signs pre-key with identity key
4. Keys uploaded to users table:
   - identity_public_key (BYTEA)
   - signed_prekey (BYTEA)
   - signed_prekey_signature (BYTEA)
```

### Session Establishment
```
1. EncryptionService.ensureSession(recipientId)
2. Check memory cache → check core for existing session
3. If no session: fetch recipient keys from Supabase
4. Validate keys are real (not placeholder [0])
5. core.initSession(recipientId, publicKeyBundle)
6. Session cached for future messages
```

---

## Online Presence

Uses Supabase Realtime Presence (channel: `presence:lobby`):

```dart
// Track own presence
channel.track({
  'user_id': currentUserId,
  'online_at': DateTime.now().toIso8601String(),
});

// Listen for other users
channel.onPresenceSync((_) {
  final state = channel.presenceState();
  // Extract online user IDs from presence state
});
```

Also updates `users.is_online` and `users.last_seen` in the database for offline queries.

---

## Offline Queue

When send fails (network error):
1. Message is encrypted and queued in the native core's SQLCipher database
2. On next app launch, `initializeCoreProvider` calls `flushRetryQueue()`
3. Queued messages are sent to Supabase
4. Successfully sent messages are cleared from the queue

---

## Supabase Schema

### Tables Used
- `users` — profiles, keys, online status
- `messages` — encrypted content, status, timestamps
- `contacts` — block/verify relationships
- `prekeys` — one-time pre-keys for X3DH

### Realtime Enabled
- `messages` — INSERT/UPDATE for live messaging
- `users` — UPDATE for online status

### RLS Policies (Dev Mode)
- All tables allow SELECT/INSERT/UPDATE for anon/authenticated roles
- Production will restrict to `auth.uid()` based policies

---

## Build Status

✅ `flutter analyze` — 0 errors (only info-level `avoid_print` in service code)  
✅ `flutter build apk --debug` — SUCCESS  
✅ `flutter build windows` — SUCCESS  
✅ Database schema verified — all columns match service code
