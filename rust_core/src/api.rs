//! API Module - Clean FFI interface for Flutter
//! 
//! This module contains only the functions and types that should be
//! exposed to Flutter via flutter_rust_bridge.

use flutter_rust_bridge::frb;
use crate::crypto;

// ============================================================================
// Types for FFI
// ============================================================================

/// Public key bundle (to share with server/contacts)
#[frb(non_opaque)]
#[derive(Clone)]
pub struct KeyBundleDto {
    pub identity_public_key: Vec<u8>,
    pub signed_prekey: Vec<u8>,
    pub signature: Vec<u8>,
}

/// Minimal public key bundle for session init
#[frb(non_opaque)]
#[derive(Clone)]
pub struct PublicKeyBundleDto {
    pub identity_public_key: Vec<u8>,
    pub signed_prekey: Vec<u8>,
    pub signature: Vec<u8>,
    pub one_time_prekey: Option<Vec<u8>>,
}

// ============================================================================
// Core API Functions
// ============================================================================

/// Initialize the core engine
/// Call this once when the app starts
#[frb]
pub fn init_core(db_path: String, encryption_key: String) -> Result<(), String> {
    crate::storage::init(&db_path, &encryption_key)?;
    crate::sync::init()?;
    Ok(())
}

/// Generate new identity keys
/// Call this during signup
#[frb]
pub fn generate_identity_keys() -> Result<KeyBundleDto, String> {
    let bundle = crypto::generate_identity_keys()?;
    Ok(KeyBundleDto {
        identity_public_key: bundle.identity_public_key,
        signed_prekey: bundle.signed_prekey,
        signature: bundle.signature,
    })
}

/// Get the public key bundle (to upload to server)
#[frb]
pub fn get_public_key_bundle() -> Result<PublicKeyBundleDto, String> {
    let bundle = crypto::get_public_key_bundle()?;
    Ok(PublicKeyBundleDto {
        identity_public_key: bundle.identity_public_key,
        signed_prekey: bundle.signed_prekey,
        signature: bundle.signature,
        one_time_prekey: bundle.one_time_prekey,
    })
}

/// Initialize a session with a recipient
/// Call this before sending messages to a new contact
#[frb]
pub fn init_session(recipient_id: String, identity_public_key: Vec<u8>, signed_prekey: Vec<u8>, signature: Vec<u8>, one_time_prekey: Option<Vec<u8>>) -> Result<(), String> {
    let recipient_keys = crypto::PublicKeyBundle {
        identity_public_key,
        signed_prekey,
        signature,
        one_time_prekey,
    };
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
