//! Key Management
//! 
//! Generates and manages cryptographic keys:
//! - Identity key pair (Ed25519) - for signing
//! - Signed PreKey (X25519) - for key agreement
//! - One-time PreKeys (X25519) - for initial key exchange
//! 
//! Similar to Briar's key generation in CryptoComponent

use ring::signature::{Ed25519KeyPair, KeyPair};
use x25519_dalek::{StaticSecret, PublicKey as X25519PublicKey};
use rand::rngs::OsRng;
use serde::{Serialize, Deserialize};

/// Complete key bundle (private + public)
/// Private keys stay on device, never exported
#[derive(Clone)]
pub struct IdentityKeys {
    /// Ed25519 identity key pair (for signing)
    pub identity_keypair: Vec<u8>,
    
    /// X25519 signed prekey (for key agreement)
    pub signed_prekey_private: [u8; 32],
    pub signed_prekey_public: [u8; 32],
    
    /// Signature of the signed prekey
    pub signed_prekey_signature: Vec<u8>,
}

/// Public key bundle (to share with server/contacts)
#[derive(Clone, Serialize, Deserialize)]
pub struct KeyBundle {
    pub identity_public_key: Vec<u8>,
    pub signed_prekey: Vec<u8>,
    pub signature: Vec<u8>,
}

/// Minimal public key bundle for session init
#[derive(Clone, Serialize, Deserialize)]
pub struct PublicKeyBundle {
    pub identity_public_key: Vec<u8>,
    pub signed_prekey: Vec<u8>,
    pub signature: Vec<u8>,
    pub one_time_prekey: Option<Vec<u8>>,
}

/// Generate new identity keys
/// Call this once during signup
pub fn generate_identity_keys() -> Result<KeyBundle, String> {
    // Generate Ed25519 identity key pair
    let rng = ring::rand::SystemRandom::new();
    let pkcs8_bytes = Ed25519KeyPair::generate_pkcs8(&rng)
        .map_err(|e| format!("Failed to generate identity key: {:?}", e))?;
    
    let identity_keypair = Ed25519KeyPair::from_pkcs8(pkcs8_bytes.as_ref())
        .map_err(|e| format!("Failed to parse identity key: {:?}", e))?;
    
    // Generate X25519 signed prekey
    let signed_prekey_private = StaticSecret::random_from_rng(OsRng);
    let signed_prekey_public = X25519PublicKey::from(&signed_prekey_private);
    
    // Sign the signed prekey with identity key
    let signature = identity_keypair.sign(signed_prekey_public.as_bytes());
    
    // Store keys
    let identity_keys = IdentityKeys {
        identity_keypair: pkcs8_bytes.as_ref().to_vec(),
        signed_prekey_private: signed_prekey_private.to_bytes(),
        signed_prekey_public: signed_prekey_public.to_bytes(),
        signed_prekey_signature: signature.as_ref().to_vec(),
    };
    
    // Store in global state
    let mut keys = super::IDENTITY_KEYS.write().map_err(|e| e.to_string())?;
    *keys = Some(identity_keys.clone());
    
    Ok(KeyBundle {
        identity_public_key: identity_keypair.public_key().as_ref().to_vec(),
        signed_prekey: signed_prekey_public.as_bytes().to_vec(),
        signature: signature.as_ref().to_vec(),
    })
}

/// Get our public key bundle to share with server
pub fn get_public_key_bundle() -> Result<PublicKeyBundle, String> {
    let keys = super::IDENTITY_KEYS.read().map_err(|e| e.to_string())?;
    let identity_keys = keys.as_ref().ok_or("Keys not initialized")?;
    
    // Parse identity keypair to get public key
    let keypair = Ed25519KeyPair::from_pkcs8(&identity_keys.identity_keypair)
        .map_err(|e| format!("Failed to parse identity key: {:?}", e))?;
    
    Ok(PublicKeyBundle {
        identity_public_key: keypair.public_key().as_ref().to_vec(),
        signed_prekey: identity_keys.signed_prekey_public.to_vec(),
        signature: identity_keys.signed_prekey_signature.clone(),
        one_time_prekey: None, // TODO: Generate and rotate one-time prekeys
    })
}

/// Generate a batch of one-time prekeys
#[allow(dead_code)]
pub fn generate_prekeys(count: usize) -> Vec<(u32, Vec<u8>, [u8; 32])> {
    let mut prekeys = Vec::with_capacity(count);
    
    for i in 0..count {
        let private = StaticSecret::random_from_rng(OsRng);
        let public = X25519PublicKey::from(&private);
        
        prekeys.push((
            i as u32,                    // key_id
            public.as_bytes().to_vec(),  // public key
            private.to_bytes(),          // private key (store locally)
        ));
    }
    
    prekeys
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_identity_keys() {
        let bundle = generate_identity_keys().unwrap();
        
        // Ed25519 public key is 32 bytes
        assert_eq!(bundle.identity_public_key.len(), 32);
        
        // X25519 public key is 32 bytes
        assert_eq!(bundle.signed_prekey.len(), 32);
        
        // Ed25519 signature is 64 bytes
        assert_eq!(bundle.signature.len(), 64);
    }

    #[test]
    fn test_generate_prekeys() {
        let prekeys = generate_prekeys(10);
        
        assert_eq!(prekeys.len(), 10);
        
        for (id, public, private) in prekeys {
            assert_eq!(public.len(), 32);
            assert_eq!(private.len(), 32);
        }
    }
}
