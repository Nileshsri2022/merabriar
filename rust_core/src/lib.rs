#![allow(unexpected_cfgs)]
//! MeraBriar Core - Rust Implementation
//! 
//! This is the core engine for the MeraBriar messenger app.
//! It handles cryptography, storage, sync, and transport.
//! 
//! # Architecture
//! 
//! ```text
//! ┌─────────────────────────────────────────┐
//! │           Flutter UI Layer              │
//! ├─────────────────────────────────────────┤
//! │              FFI Bridge                 │
//! ├─────────────────────────────────────────┤
//! │          Rust Core Engine               │
//! │  ┌─────────┐ ┌─────────┐ ┌───────────┐ │
//! │  │ Crypto  │ │ Storage │ │ Transport │ │
//! │  └─────────┘ └─────────┘ └───────────┘ │
//! └─────────────────────────────────────────┘
//! ```

pub mod crypto;
pub mod storage;
pub mod sync;
pub mod transport;
pub mod message;

use flutter_rust_bridge::frb;

// Re-export main types
pub use crypto::{KeyBundle, PublicKeyBundle, CryptoEngine};
pub use storage::Storage;
pub use sync::{MessageQueue, QueuedMessage};
pub use message::{Message, MessageStatus};

/// Initialize the core engine
/// Call this once when the app starts
#[frb]
pub fn init_core(db_path: String, encryption_key: String) -> Result<(), String> {
    // Initialize storage
    storage::init(&db_path, &encryption_key)?;
    
    // Initialize message queue
    sync::init()?;
    
    Ok(())
}

/// Generate new identity keys
/// Call this during signup
#[frb]
pub fn generate_identity_keys() -> Result<KeyBundle, String> {
    crypto::generate_identity_keys()
}

/// Get the public key bundle (to upload to server)
#[frb]
pub fn get_public_key_bundle() -> Result<PublicKeyBundle, String> {
    crypto::get_public_key_bundle()
}

/// Initialize a session with a recipient
/// Call this before sending messages to a new contact
#[frb]
pub fn init_session(recipient_id: String, recipient_keys: PublicKeyBundle) -> Result<(), String> {
    crypto::init_session(&recipient_id, &recipient_keys)
}

/// Check if we have a session with a recipient
#[frb]
pub fn has_session(recipient_id: String) -> bool {
    crypto::has_session(&recipient_id)
}

/// Encrypt a message for a recipient
#[frb]
pub fn encrypt_message(recipient_id: String, plaintext: String) -> Result<Vec<u8>, String> {
    crypto::encrypt_message(&recipient_id, &plaintext)
}

/// Decrypt a message from a sender
#[frb]
pub fn decrypt_message(sender_id: String, ciphertext: Vec<u8>) -> Result<String, String> {
    crypto::decrypt_message(&sender_id, &ciphertext)
}

/// Queue a message for sending later (offline support)
#[frb]
pub fn queue_message(message: QueuedMessage) -> Result<(), String> {
    sync::queue_message(message)
}

/// Get all queued messages
#[frb]
pub fn get_queued_messages() -> Result<Vec<QueuedMessage>, String> {
    sync::get_queued_messages()
}

/// Clear sent messages from queue
#[frb]
pub fn clear_queue(message_ids: Vec<String>) -> Result<(), String> {
    sync::clear_queue(&message_ids)
}

/// Store a message locally
#[frb]
pub fn store_message(message: Message) -> Result<(), String> {
    storage::store_message(&message)
}

/// Get messages for a conversation
#[frb]
pub fn get_messages(conversation_id: String, limit: i32, offset: i32) -> Result<Vec<Message>, String> {
    storage::get_messages(&conversation_id, limit, offset)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_key_generation() {
        let keys = generate_identity_keys().unwrap();
        assert!(!keys.identity_public_key.is_empty());
        assert!(!keys.signed_prekey.is_empty());
        assert!(!keys.signature.is_empty());
    }
}
