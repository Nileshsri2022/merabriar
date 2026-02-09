//! Session Management
//! 
//! Manages encrypted sessions with contacts using a simplified
//! Signal-like protocol. Each session maintains:
//! - Root key (for deriving chain keys)
//! - Chain key (for deriving message keys)
//! - Message counter
//! 
//! This is similar to Briar's session management in bramble-core

use x25519_dalek::{StaticSecret, PublicKey as X25519PublicKey};
use sha2::Sha256;
use hkdf::Hkdf;


use super::key_management::PublicKeyBundle;

/// A session with a contact
#[derive(Clone)]
pub struct Session {
    /// Recipient's ID
    pub recipient_id: String,
    
    /// Shared root key (derived from X3DH)
    #[allow(dead_code)]
    root_key: [u8; 32],
    
    /// Sending chain key (for encrypting)
    send_chain_key: [u8; 32],
    
    /// Receiving chain key (for decrypting)
    recv_chain_key: [u8; 32],
    
    /// Message counters
    send_counter: u32,
    recv_counter: u32,
}

impl Session {
    /// Create a new session with derived keys
    pub fn new(recipient_id: &str, shared_secret: &[u8]) -> Self {
        // Derive root key and initial chain keys using HKDF
        let hk = Hkdf::<Sha256>::new(None, shared_secret);
        
        let mut root_key = [0u8; 32];
        let mut send_chain = [0u8; 32];
        let mut recv_chain = [0u8; 32];
        
        hk.expand(b"root_key", &mut root_key).unwrap();
        hk.expand(b"send_chain", &mut send_chain).unwrap();
        hk.expand(b"recv_chain", &mut recv_chain).unwrap();
        
        Session {
            recipient_id: recipient_id.to_string(),
            root_key,
            send_chain_key: send_chain,
            recv_chain_key: recv_chain,
            send_counter: 0,
            recv_counter: 0,
        }
    }
    
    /// Derive the next message key for sending
    pub fn derive_send_key(&mut self) -> [u8; 32] {
        let (message_key, new_chain_key) = self.derive_message_key(&self.send_chain_key, self.send_counter);
        self.send_chain_key = new_chain_key;
        self.send_counter += 1;
        message_key
    }
    
    /// Derive the next message key for receiving
    pub fn derive_recv_key(&mut self) -> [u8; 32] {
        let (message_key, new_chain_key) = self.derive_message_key(&self.recv_chain_key, self.recv_counter);
        self.recv_chain_key = new_chain_key;
        self.recv_counter += 1;
        message_key
    }
    
    /// Derive a message key from chain key using HKDF
    fn derive_message_key(&self, chain_key: &[u8; 32], counter: u32) -> ([u8; 32], [u8; 32]) {
        let hk = Hkdf::<Sha256>::new(Some(&counter.to_be_bytes()), chain_key);
        
        let mut message_key = [0u8; 32];
        let mut new_chain_key = [0u8; 32];
        
        hk.expand(b"message_key", &mut message_key).unwrap();
        hk.expand(b"chain_key", &mut new_chain_key).unwrap();
        
        (message_key, new_chain_key)
    }
}

/// Initialize a session with a recipient
/// Performs X3DH key agreement
pub fn init_session(recipient_id: &str, recipient_keys: &PublicKeyBundle) -> Result<(), String> {
    // Get our identity keys
    let our_keys = super::IDENTITY_KEYS.read().map_err(|e| e.to_string())?;
    let our_keys = our_keys.as_ref().ok_or("Our keys not initialized")?;
    
    // Parse recipient's signed prekey
    let their_prekey: [u8; 32] = recipient_keys.signed_prekey
        .clone()
        .try_into()
        .map_err(|_| "Invalid prekey length")?;
    let their_prekey = X25519PublicKey::from(their_prekey);
    
    // Perform X25519 key agreement with our signed prekey
    let our_prekey = StaticSecret::from(our_keys.signed_prekey_private);
    let shared_secret = our_prekey.diffie_hellman(&their_prekey);
    
    // Create session with shared secret
    let session = Session::new(recipient_id, shared_secret.as_bytes());
    
    // Store session
    let mut sessions = super::SESSIONS.write().map_err(|e| e.to_string())?;
    sessions.insert(recipient_id.to_string(), session);
    
    Ok(())
}

/// Check if we have a session with a recipient
pub fn has_session(recipient_id: &str) -> bool {
    if let Ok(sessions) = super::SESSIONS.read() {
        sessions.contains_key(recipient_id)
    } else {
        false
    }
}

/// Get a mutable reference to a session
pub fn get_session_mut(recipient_id: &str) -> Result<Session, String> {
    let sessions = super::SESSIONS.read().map_err(|e| e.to_string())?;
    sessions.get(recipient_id)
        .cloned()
        .ok_or_else(|| format!("No session for {}", recipient_id))
}

/// Update a session after use
pub fn update_session(session: Session) -> Result<(), String> {
    let mut sessions = super::SESSIONS.write().map_err(|e| e.to_string())?;
    sessions.insert(session.recipient_id.clone(), session);
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_session_key_derivation() {
        let shared_secret = [0u8; 32]; // Dummy shared secret
        let mut session = Session::new("test", &shared_secret);
        
        // Derive multiple keys - each should be different
        let key1 = session.derive_send_key();
        let key2 = session.derive_send_key();
        let key3 = session.derive_send_key();
        
        assert_ne!(key1, key2);
        assert_ne!(key2, key3);
        assert_ne!(key1, key3);
    }
}
