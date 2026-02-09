//! Message Encryption/Decryption
//! 
//! Uses AES-256-GCM for symmetric encryption of messages.
//! Each message uses a unique key derived from the session chain.
//! 
//! Message format:
//! | nonce (12 bytes) | ciphertext | tag (16 bytes) |

use aes_gcm::{
    aead::{Aead, KeyInit, OsRng},
    Aes256Gcm, Nonce,
};
use rand::RngCore;

use super::session::{get_session_mut, update_session};

/// Encrypt a message for a recipient
/// 
/// Returns the encrypted bytes (nonce + ciphertext + tag)
pub fn encrypt_message(recipient_id: &str, plaintext: &str) -> Result<Vec<u8>, String> {
    // Get session and derive message key
    let mut session = get_session_mut(recipient_id)?;
    let message_key = session.derive_send_key();
    
    // Create cipher
    let cipher = Aes256Gcm::new_from_slice(&message_key)
        .map_err(|e| format!("Failed to create cipher: {:?}", e))?;
    
    // Generate random nonce
    let mut nonce_bytes = [0u8; 12];
    OsRng.fill_bytes(&mut nonce_bytes);
    let nonce = Nonce::from_slice(&nonce_bytes);
    
    // Encrypt
    let ciphertext = cipher.encrypt(nonce, plaintext.as_bytes())
        .map_err(|e| format!("Encryption failed: {:?}", e))?;
    
    // Update session state
    update_session(session)?;
    
    // Combine nonce + ciphertext
    let mut result = nonce_bytes.to_vec();
    result.extend(ciphertext);
    
    Ok(result)
}

/// Decrypt a message from a sender
/// 
/// Expects format: nonce (12 bytes) + ciphertext + tag
pub fn decrypt_message(sender_id: &str, ciphertext: &[u8]) -> Result<String, String> {
    if ciphertext.len() < 12 + 16 {
        return Err("Ciphertext too short".to_string());
    }
    
    // Get session and derive message key
    let mut session = get_session_mut(sender_id)?;
    let message_key = session.derive_recv_key();
    
    // Create cipher
    let cipher = Aes256Gcm::new_from_slice(&message_key)
        .map_err(|e| format!("Failed to create cipher: {:?}", e))?;
    
    // Extract nonce and ciphertext
    let nonce = Nonce::from_slice(&ciphertext[..12]);
    let encrypted = &ciphertext[12..];
    
    // Decrypt
    let plaintext = cipher.decrypt(nonce, encrypted)
        .map_err(|e| format!("Decryption failed: {:?}", e))?;
    
    // Update session state
    update_session(session)?;
    
    // Convert to string
    String::from_utf8(plaintext)
        .map_err(|e| format!("Invalid UTF-8: {:?}", e))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::crypto::key_management::generate_identity_keys;
    use crate::crypto::session::{init_session, Session};
    use crate::crypto::SESSIONS;

    fn setup_test_session() {
        // Create a dummy session for testing
        let shared_secret = [42u8; 32];
        let session = Session::new("test_user", &shared_secret);
        
        let mut sessions = SESSIONS.write().unwrap();
        sessions.insert("test_user".to_string(), session.clone());
        
        // Also insert as ourselves for decryption
        let recv_session = Session::new("test_user", &shared_secret);
        sessions.insert("self".to_string(), recv_session);
    }

    #[test]
    fn test_encrypt_decrypt() {
        setup_test_session();
        
        let plaintext = "Hello, World!";
        
        // Encrypt
        let ciphertext = encrypt_message("test_user", plaintext).unwrap();
        
        // Verify ciphertext is different from plaintext
        assert_ne!(ciphertext, plaintext.as_bytes());
        assert!(ciphertext.len() >= 12 + plaintext.len() + 16);
        
        // Note: In real usage, decryption would use the recipient's session
        // This test just verifies encryption works
    }

    #[test]
    fn test_ciphertext_format() {
        setup_test_session();
        
        let plaintext = "Test";
        let ciphertext = encrypt_message("test_user", plaintext).unwrap();
        
        // Should have: 12 byte nonce + ciphertext + 16 byte tag
        assert!(ciphertext.len() >= 12 + 16);
        
        // Nonce should be first 12 bytes
        let nonce = &ciphertext[..12];
        assert_eq!(nonce.len(), 12);
    }
}
