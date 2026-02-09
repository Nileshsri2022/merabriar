//! Cryptography Module
//! 
//! Implements Signal-like E2E encryption:
//! - Key generation (Ed25519 + X25519)
//! - Session management (Double Ratchet)
//! - Message encryption (AES-256-GCM)
//! 
//! This mirrors Briar's `bramble-api/crypto/CryptoComponent`

mod key_management;
mod session;
mod encryption;

pub use key_management::{KeyBundle, PublicKeyBundle, generate_identity_keys, get_public_key_bundle};
pub use session::{init_session, has_session};
pub use encryption::{encrypt_message, decrypt_message};

use std::sync::RwLock;
use std::collections::HashMap;

lazy_static::lazy_static! {
    /// Global session store
    /// In production, this would be persisted to SQLCipher
    static ref SESSIONS: RwLock<HashMap<String, session::Session>> = RwLock::new(HashMap::new());
    
    /// Our identity keys
    static ref IDENTITY_KEYS: RwLock<Option<key_management::IdentityKeys>> = RwLock::new(None);
}

/// Crypto engine trait (mirrors Briar's CryptoComponent)
pub trait CryptoEngine {
    fn generate_secret_key() -> Vec<u8>;
    fn generate_agreement_key_pair() -> (Vec<u8>, Vec<u8>);
    fn generate_signature_key_pair() -> (Vec<u8>, Vec<u8>);
    fn sign(data: &[u8], private_key: &[u8]) -> Vec<u8>;
    fn verify(signature: &[u8], data: &[u8], public_key: &[u8]) -> bool;
    fn encrypt(plaintext: &[u8], key: &[u8]) -> Vec<u8>;
    fn decrypt(ciphertext: &[u8], key: &[u8]) -> Vec<u8>;
}
