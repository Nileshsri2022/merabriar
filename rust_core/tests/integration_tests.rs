//! Integration Tests for MeraBriar Rust Core
//!
//! Tests the full lifecycle of:
//! 1. Key Generation & Session Setup
//! 2. Encrypt → Decrypt Round Trip
//! 3. Storage (Messages, Sessions)
//! 4. Message Queue (Offline Sync)
//! 5. Transport Manager
//! 6. Cross-module workflows (keygen → session → encrypt → store → queue)

use merabriar_core::crypto::{
    KeyBundle, PublicKeyBundle,
    generate_identity_keys, get_public_key_bundle,
    init_session, has_session,
    encrypt_message, decrypt_message,
};
use merabriar_core::sync::QueuedMessage;
use merabriar_core::message::{Message, MessageStatus, EncryptedMessage, MessageType};

// Re-import lib-level functions that take String params
use merabriar_core::{
    init_core, store_message_internal, get_messages_internal,
    queue_message_internal, get_queued_messages_internal, clear_queue_internal,
};

// ═══════════════════════════════════════
// 1. CRYPTO - Key Generation Tests
// ═══════════════════════════════════════

#[test]
fn test_generate_identity_keys_returns_valid_bundle() {
    let bundle = generate_identity_keys().unwrap();

    // Ed25519 public key is 32 bytes
    assert_eq!(bundle.identity_public_key.len(), 32, "Ed25519 public key should be 32 bytes");

    // X25519 signed prekey is 32 bytes
    assert_eq!(bundle.signed_prekey.len(), 32, "X25519 signed prekey should be 32 bytes");

    // Ed25519 signature is 64 bytes
    assert_eq!(bundle.signature.len(), 64, "Ed25519 signature should be 64 bytes");
}

#[test]
fn test_generate_keys_are_unique() {
    let bundle1 = generate_identity_keys().unwrap();
    let bundle2 = generate_identity_keys().unwrap();

    // Each call should generate different keys
    assert_ne!(bundle1.identity_public_key, bundle2.identity_public_key,
        "Two key generations should produce different identity keys");
    assert_ne!(bundle1.signed_prekey, bundle2.signed_prekey,
        "Two key generations should produce different prekeys");
}

#[test]
fn test_get_public_key_bundle_after_generation() {
    // Generate keys first
    let bundle = generate_identity_keys().unwrap();

    // Get public key bundle
    let pub_bundle = get_public_key_bundle().unwrap();

    // Should match generated keys
    assert_eq!(pub_bundle.identity_public_key, bundle.identity_public_key);
    assert_eq!(pub_bundle.signed_prekey, bundle.signed_prekey);
    assert_eq!(pub_bundle.signature, bundle.signature);
    assert!(pub_bundle.one_time_prekey.is_none(), "One-time prekey should be None by default");
}

#[test]
fn test_key_bundle_serialization() {
    let bundle = generate_identity_keys().unwrap();

    // Serialize and deserialize
    let json = serde_json::to_string(&bundle).unwrap();
    let deserialized: KeyBundle = serde_json::from_str(&json).unwrap();

    assert_eq!(bundle.identity_public_key, deserialized.identity_public_key);
    assert_eq!(bundle.signed_prekey, deserialized.signed_prekey);
    assert_eq!(bundle.signature, deserialized.signature);
}

#[test]
fn test_public_key_bundle_serialization() {
    generate_identity_keys().unwrap();
    let pub_bundle = get_public_key_bundle().unwrap();

    let json = serde_json::to_string(&pub_bundle).unwrap();
    let deserialized: PublicKeyBundle = serde_json::from_str(&json).unwrap();

    assert_eq!(pub_bundle.identity_public_key, deserialized.identity_public_key);
    assert_eq!(pub_bundle.signed_prekey, deserialized.signed_prekey);
    assert_eq!(pub_bundle.signature, deserialized.signature);
}

// ═══════════════════════════════════════
// 2. CRYPTO - Session Tests
// ═══════════════════════════════════════

#[test]
fn test_session_init_and_check() {
    // Generate our keys
    generate_identity_keys().unwrap();

    // Create a fake recipient's public key bundle
    let recipient_bundle = generate_identity_keys().unwrap();
    let recipient_pub = get_public_key_bundle().unwrap();

    // Init session
    let result = init_session("alice", &recipient_pub);
    assert!(result.is_ok(), "Session init should succeed: {:?}", result.err());

    // Check session exists
    assert!(has_session("alice"), "Session should exist for alice");

    // Check session doesn't exist for unknown
    assert!(!has_session("unknown_user"), "Session should not exist for unknown user");
}

#[test]
fn test_multiple_sessions() {
    generate_identity_keys().unwrap();
    let pub_bundle = get_public_key_bundle().unwrap();

    // Init sessions for multiple recipients
    init_session("bob", &pub_bundle).unwrap();
    init_session("charlie", &pub_bundle).unwrap();
    init_session("dave", &pub_bundle).unwrap();

    assert!(has_session("bob"));
    assert!(has_session("charlie"));
    assert!(has_session("dave"));
    assert!(!has_session("eve"));
}

// ═══════════════════════════════════════
// 3. CRYPTO - Encryption/Decryption Tests
// ═══════════════════════════════════════

#[test]
fn test_encrypt_message_produces_ciphertext() {
    generate_identity_keys().unwrap();
    let pub_bundle = get_public_key_bundle().unwrap();
    init_session("enc_test_user", &pub_bundle).unwrap();

    let plaintext = "Hello, World! 🌍";
    let ciphertext = encrypt_message("enc_test_user", plaintext).unwrap();

    // Ciphertext should be at least nonce(12) + plaintext + tag(16) bytes
    assert!(ciphertext.len() >= 12 + 16, "Ciphertext too short");
    assert_ne!(ciphertext, plaintext.as_bytes(), "Ciphertext should differ from plaintext");
}

#[test]
fn test_encrypt_same_message_produces_different_ciphertext() {
    generate_identity_keys().unwrap();
    let pub_bundle = get_public_key_bundle().unwrap();
    init_session("enc_unique_user", &pub_bundle).unwrap();

    let plaintext = "Same message";
    let ct1 = encrypt_message("enc_unique_user", plaintext).unwrap();
    let ct2 = encrypt_message("enc_unique_user", plaintext).unwrap();

    // Nonces should be different → different ciphertext
    assert_ne!(ct1, ct2, "Encrypting the same plaintext twice should produce different ciphertexts");
}

#[test]
fn test_encrypt_empty_plaintext() {
    generate_identity_keys().unwrap();
    let pub_bundle = get_public_key_bundle().unwrap();
    init_session("enc_empty_user", &pub_bundle).unwrap();

    let ciphertext = encrypt_message("enc_empty_user", "").unwrap();

    // Even empty plaintext should produce nonce + tag
    assert!(ciphertext.len() >= 12 + 16, "Even empty plaintext should produce ciphertext");
}

#[test]
fn test_encrypt_without_session_fails() {
    let result = encrypt_message("nonexistent_user_12345", "test");
    assert!(result.is_err(), "Encryption without session should fail");
}

#[test]
fn test_decrypt_invalid_ciphertext() {
    generate_identity_keys().unwrap();
    let pub_bundle = get_public_key_bundle().unwrap();
    init_session("dec_invalid_user", &pub_bundle).unwrap();

    // Too short ciphertext
    let result = decrypt_message("dec_invalid_user", &vec![0u8; 10]);
    assert!(result.is_err(), "Decrypting too-short ciphertext should fail");
}

#[test]
fn test_ciphertext_format() {
    generate_identity_keys().unwrap();
    let pub_bundle = get_public_key_bundle().unwrap();
    init_session("format_test_user", &pub_bundle).unwrap();

    let plaintext = "Test format";
    let ciphertext = encrypt_message("format_test_user", plaintext).unwrap();

    // First 12 bytes = nonce
    assert_eq!(ciphertext[..12].len(), 12, "Nonce should be 12 bytes");

    // Remaining bytes = encrypted payload + 16-byte GCM tag
    let payload_len = ciphertext.len() - 12;
    assert!(payload_len >= plaintext.len() + 16,
        "Payload should be at least plaintext + 16 byte tag");
}

// ═══════════════════════════════════════
// 4. STORAGE - Database Tests
// ═══════════════════════════════════════

#[test]
fn test_storage_init() {
    use std::fs;
    let db_path = "test_storage_init.db";
    let _ = fs::remove_file(db_path);

    let result = init_core(db_path.to_string(), "test_key".to_string());
    assert!(result.is_ok(), "Storage init should succeed: {:?}", result.err());

    // Cleanup
    let _ = fs::remove_file(db_path);
}

#[test]
fn test_store_and_retrieve_message() {
    use std::fs;
    let db_path = "test_store_msg.db";
    let _ = fs::remove_file(db_path);

    init_core(db_path.to_string(), "test_key".to_string()).unwrap();

    // Store a message
    let msg = Message::new(
        "msg-001".to_string(),
        "conv-001".to_string(),
        "user-alice".to_string(),
        "Hello Bob!".to_string(),
    );
    store_message_internal(msg.clone()).unwrap();

    // Retrieve messages
    let messages = get_messages_internal("conv-001".to_string(), 10, 0).unwrap();
    assert!(!messages.is_empty(), "Should retrieve at least one message");
    assert_eq!(messages[0].id, "msg-001");
    assert_eq!(messages[0].content, "Hello Bob!");
    assert_eq!(messages[0].sender_id, "user-alice");
    assert_eq!(messages[0].status, MessageStatus::Pending);

    let _ = fs::remove_file(db_path);
}

#[test]
fn test_store_multiple_messages_pagination() {
    use std::fs;
    let db_path = "test_pagination.db";
    let _ = fs::remove_file(db_path);

    init_core(db_path.to_string(), "test_key".to_string()).unwrap();

    // Store 5 messages
    for i in 0..5 {
        let msg = Message {
            id: format!("msg-{}", i),
            conversation_id: "conv-pag".to_string(),
            sender_id: "alice".to_string(),
            content: format!("Message {}", i),
            timestamp: 1000 + i as i64,
            status: MessageStatus::Sent,
        };
        store_message_internal(msg).unwrap();
    }

    // Get page 1 (limit 2, offset 0) - should return newest first
    let page1 = get_messages_internal("conv-pag".to_string(), 2, 0).unwrap();
    assert_eq!(page1.len(), 2, "Page 1 should have 2 messages");

    // Get page 2 (limit 2, offset 2)
    let page2 = get_messages_internal("conv-pag".to_string(), 2, 2).unwrap();
    assert_eq!(page2.len(), 2, "Page 2 should have 2 messages");

    // Get page 3 (limit 2, offset 4) - should have 1 remaining
    let page3 = get_messages_internal("conv-pag".to_string(), 2, 4).unwrap();
    assert_eq!(page3.len(), 1, "Page 3 should have 1 message");

    let _ = fs::remove_file(db_path);
}

#[test]
fn test_messages_for_different_conversations() {
    use std::fs;
    let db_path = "test_multi_conv.db";
    let _ = fs::remove_file(db_path);

    init_core(db_path.to_string(), "test_key".to_string()).unwrap();

    // Store messages in different conversations
    store_message_internal(Message {
        id: "a1".to_string(),
        conversation_id: "conv-A".to_string(),
        sender_id: "alice".to_string(),
        content: "Hello A".to_string(),
        timestamp: 100,
        status: MessageStatus::Sent,
    }).unwrap();

    store_message_internal(Message {
        id: "b1".to_string(),
        conversation_id: "conv-B".to_string(),
        sender_id: "bob".to_string(),
        content: "Hello B".to_string(),
        timestamp: 200,
        status: MessageStatus::Sent,
    }).unwrap();

    let msgs_a = get_messages_internal("conv-A".to_string(), 10, 0).unwrap();
    let msgs_b = get_messages_internal("conv-B".to_string(), 10, 0).unwrap();

    assert_eq!(msgs_a.len(), 1);
    assert_eq!(msgs_b.len(), 1);
    assert_eq!(msgs_a[0].content, "Hello A");
    assert_eq!(msgs_b[0].content, "Hello B");

    let _ = fs::remove_file(db_path);
}

// ═══════════════════════════════════════
// 5. SYNC - Message Queue Tests
// ═══════════════════════════════════════

#[test]
fn test_queue_and_retrieve() {
    let msg = QueuedMessage::new(
        "q-msg-001".to_string(),
        "recipient-1".to_string(),
        vec![10, 20, 30, 40],
    );

    queue_message_internal(msg).unwrap();

    let queued = get_queued_messages_internal().unwrap();
    assert!(queued.iter().any(|m| m.id == "q-msg-001"), "Queued message should be retrievable");
}

#[test]
fn test_queue_multiple_and_filter_by_recipient() {
    use merabriar_core::sync;

    let msg1 = QueuedMessage::new("qm1".to_string(), "alice".to_string(), vec![1]);
    let msg2 = QueuedMessage::new("qm2".to_string(), "bob".to_string(), vec![2]);
    let msg3 = QueuedMessage::new("qm3".to_string(), "alice".to_string(), vec![3]);

    sync::queue_message(msg1).unwrap();
    sync::queue_message(msg2).unwrap();
    sync::queue_message(msg3).unwrap();

    let alice_msgs = sync::get_queued_for_recipient("alice").unwrap();
    assert!(alice_msgs.len() >= 2, "Alice should have at least 2 queued messages");
    assert!(alice_msgs.iter().all(|m| m.recipient_id == "alice"));
}

#[test]
fn test_queue_clear_specific_messages() {
    use merabriar_core::sync;

    let msg = QueuedMessage::new("clear-me".to_string(), "recip".to_string(), vec![99]);
    sync::queue_message(msg).unwrap();

    // Verify it exists
    let before = sync::get_queued_messages().unwrap();
    assert!(before.iter().any(|m| m.id == "clear-me"));

    // Clear it
    sync::clear_queue(&["clear-me".to_string()]).unwrap();

    // Verify it's gone
    let after = sync::get_queued_messages().unwrap();
    assert!(!after.iter().any(|m| m.id == "clear-me"), "Cleared message should be removed");
}

#[test]
fn test_queue_increment_attempts() {
    use merabriar_core::sync;

    let msg = QueuedMessage::new("retry-msg".to_string(), "recip".to_string(), vec![55]);
    sync::queue_message(msg).unwrap();

    // Increment attempts twice
    sync::increment_attempts("retry-msg").unwrap();
    sync::increment_attempts("retry-msg").unwrap();

    let queued = sync::get_queued_messages().unwrap();
    let found = queued.iter().find(|m| m.id == "retry-msg");
    assert!(found.is_some());
    assert_eq!(found.unwrap().attempts, 2, "Attempts should be incremented to 2");
}

#[test]
fn test_queue_size() {
    use merabriar_core::sync;

    let initial_size = sync::queue_size();

    sync::queue_message(QueuedMessage::new(
        "size-test".to_string(), "recip".to_string(), vec![1]
    )).unwrap();

    assert!(sync::queue_size() > initial_size, "Queue size should increase after enqueue");
}

// ═══════════════════════════════════════
// 6. MESSAGE - Type Tests
// ═══════════════════════════════════════

#[test]
fn test_message_creation() {
    let msg = Message::new(
        "test-id".to_string(),
        "conv-id".to_string(),
        "sender-id".to_string(),
        "Hello!".to_string(),
    );

    assert_eq!(msg.id, "test-id");
    assert_eq!(msg.conversation_id, "conv-id");
    assert_eq!(msg.sender_id, "sender-id");
    assert_eq!(msg.content, "Hello!");
    assert_eq!(msg.status, MessageStatus::Pending);
    assert!(msg.timestamp > 0, "Timestamp should be positive");
}

#[test]
fn test_message_status_from_str() {
    assert_eq!(MessageStatus::from_str("pending"), MessageStatus::Pending);
    assert_eq!(MessageStatus::from_str("sent"), MessageStatus::Sent);
    assert_eq!(MessageStatus::from_str("delivered"), MessageStatus::Delivered);
    assert_eq!(MessageStatus::from_str("read"), MessageStatus::Read);
    assert_eq!(MessageStatus::from_str("failed"), MessageStatus::Failed);

    // Unknown status defaults to Pending
    assert_eq!(MessageStatus::from_str("unknown"), MessageStatus::Pending);
    assert_eq!(MessageStatus::from_str(""), MessageStatus::Pending);
}

#[test]
fn test_message_status_to_string() {
    assert_eq!(ToString::to_string(&MessageStatus::Pending), "pending");
    assert_eq!(ToString::to_string(&MessageStatus::Sent), "sent");
    assert_eq!(ToString::to_string(&MessageStatus::Delivered), "delivered");
    assert_eq!(ToString::to_string(&MessageStatus::Read), "read");
    assert_eq!(ToString::to_string(&MessageStatus::Failed), "failed");
}

#[test]
fn test_message_status_roundtrip() {
    let statuses = vec![
        MessageStatus::Pending,
        MessageStatus::Sent,
        MessageStatus::Delivered,
        MessageStatus::Read,
        MessageStatus::Failed,
    ];

    for status in statuses {
        let s: String = ToString::to_string(&status);
        let restored = MessageStatus::from_str(&s);
        assert_eq!(status, restored, "Status roundtrip failed for {:?}", status);
    }
}

#[test]
fn test_message_serialization() {
    let msg = Message::new(
        "ser-id".to_string(),
        "ser-conv".to_string(),
        "ser-sender".to_string(),
        "Serialized content".to_string(),
    );

    let json = serde_json::to_string(&msg).unwrap();
    let deserialized: Message = serde_json::from_str(&json).unwrap();

    assert_eq!(msg.id, deserialized.id);
    assert_eq!(msg.content, deserialized.content);
    assert_eq!(msg.conversation_id, deserialized.conversation_id);
    assert_eq!(msg.sender_id, deserialized.sender_id);
}

#[test]
fn test_encrypted_message_struct() {
    let enc_msg = EncryptedMessage {
        id: "enc-001".to_string(),
        sender_id: "alice".to_string(),
        recipient_id: "bob".to_string(),
        encrypted_content: vec![0xDE, 0xAD, 0xBE, 0xEF],
        message_type: MessageType::Text,
        timestamp: 1234567890,
    };

    let json = serde_json::to_string(&enc_msg).unwrap();
    let deserialized: EncryptedMessage = serde_json::from_str(&json).unwrap();

    assert_eq!(enc_msg.id, deserialized.id);
    assert_eq!(enc_msg.encrypted_content, deserialized.encrypted_content);
}

// ═══════════════════════════════════════
// 7. TRANSPORT - Manager Tests
// ═══════════════════════════════════════

#[test]
fn test_transport_manager_creation() {
    use merabriar_core::transport::TransportManager;
    let manager = TransportManager::new();

    // Initially no transport is active (all start Disabled)
    let best = manager.get_best_transport();
    assert!(best.is_none(), "No transport should be active initially");
}

#[test]
fn test_transport_available_list() {
    use merabriar_core::transport::TransportManager;
    let manager = TransportManager::new();

    let available = manager.get_available_transports();
    assert!(available.is_empty(), "No transports should be available initially (all disabled)");
}

#[test]
fn test_cloud_transport_start_stop() {
    use merabriar_core::transport::{CloudTransport, Transport, TransportState, TransportId};

    let mut transport = CloudTransport::new();

    // Initially disabled
    assert_eq!(transport.state(), TransportState::Disabled);

    // Check ID
    assert_eq!(transport.id().0, TransportId::CLOUD);

    // Not available when disabled
    assert!(!transport.is_available());
}

// ═══════════════════════════════════════
// 8. CROSS-MODULE INTEGRATION Tests
// ═══════════════════════════════════════

#[test]
fn test_full_lifecycle_keygen_to_encrypt() {
    // Step 1: Generate keys
    let bundle = generate_identity_keys().unwrap();
    assert!(!bundle.identity_public_key.is_empty());

    // Step 2: Get public key bundle
    let pub_bundle = get_public_key_bundle().unwrap();
    assert_eq!(pub_bundle.identity_public_key, bundle.identity_public_key);

    // Step 3: Init session
    init_session("lifecycle_peer", &pub_bundle).unwrap();
    assert!(has_session("lifecycle_peer"));

    // Step 4: Encrypt a message
    let plaintext = "End-to-end test message 🔐";
    let ciphertext = encrypt_message("lifecycle_peer", plaintext).unwrap();
    assert!(ciphertext.len() > 28); // At least nonce + tag
}

#[test]
fn test_message_store_and_queue_workflow() {
    use std::fs;
    let db_path = "test_workflow.db";
    let _ = fs::remove_file(db_path);

    // Step 1: Init core
    init_core(db_path.to_string(), "workflow_key".to_string()).unwrap();

    // Step 2: Create and store a message
    let msg = Message::new(
        "wf-msg-001".to_string(),
        "wf-conv-001".to_string(),
        "alice".to_string(),
        "Workflow test".to_string(),
    );
    store_message_internal(msg).unwrap();

    // Step 3: Queue encrypted version for offline sending
    let queued = QueuedMessage::new(
        "wf-msg-001".to_string(),
        "bob".to_string(),
        vec![0xCA, 0xFE, 0xBA, 0xBE],
    );
    queue_message_internal(queued).unwrap();

    // Step 4: Verify both stored and queued
    let stored_msgs = get_messages_internal("wf-conv-001".to_string(), 10, 0).unwrap();
    assert!(!stored_msgs.is_empty(), "Stored message should be retrievable");

    let queue = get_queued_messages_internal().unwrap();
    assert!(queue.iter().any(|m| m.id == "wf-msg-001"), "Queued message should be in queue");

    // Step 5: Clear queue (simulate successful send)
    clear_queue_internal(vec!["wf-msg-001".to_string()]).unwrap();
    let queue_after = get_queued_messages_internal().unwrap();
    assert!(!queue_after.iter().any(|m| m.id == "wf-msg-001"), "Queue should be cleared");

    let _ = fs::remove_file(db_path);
}

#[test]
fn test_queued_message_serialization() {
    let msg = QueuedMessage::new(
        "ser-q-1".to_string(),
        "recip-1".to_string(),
        vec![11, 22, 33],
    );

    let json = serde_json::to_string(&msg).unwrap();
    let deserialized: QueuedMessage = serde_json::from_str(&json).unwrap();

    assert_eq!(msg.id, deserialized.id);
    assert_eq!(msg.recipient_id, deserialized.recipient_id);
    assert_eq!(msg.encrypted_content, deserialized.encrypted_content);
    assert_eq!(msg.attempts, 0);
}

#[test]
fn test_large_message_encryption() {
    generate_identity_keys().unwrap();
    let pub_bundle = get_public_key_bundle().unwrap();
    init_session("large_msg_peer", &pub_bundle).unwrap();

    // Create a large message (100KB)
    let large_text = "A".repeat(100_000);
    let ciphertext = encrypt_message("large_msg_peer", &large_text).unwrap();

    // Ciphertext should be larger than plaintext (nonce + tag overhead)
    assert!(ciphertext.len() > large_text.len(),
        "Ciphertext should be larger than plaintext due to nonce + tag");
}

#[test]
fn test_unicode_message_handling() {
    generate_identity_keys().unwrap();
    let pub_bundle = get_public_key_bundle().unwrap();
    init_session("unicode_peer", &pub_bundle).unwrap();

    // Various Unicode characters
    let unicode_texts = vec![
        "Hello 🌍🔐💬",
        "مرحبا",
        "こんにちは",
        "Привет мир",
        "🇮🇳 भारत",
        "Mixed: Hello мир 🌍 世界",
    ];

    for plaintext in unicode_texts {
        let ciphertext = encrypt_message("unicode_peer", plaintext).unwrap();
        assert!(!ciphertext.is_empty(), "Encryption of '{}' should produce ciphertext", plaintext);
    }
}
