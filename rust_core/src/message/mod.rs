//! Message Module
//! 
//! Defines message types and handling.
//! 
//! This mirrors Briar's message types in `briar-api`

use serde::{Serialize, Deserialize};

/// Message status
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub enum MessageStatus {
    /// Message is pending (not yet sent)
    Pending,
    
    /// Message has been sent to server
    Sent,
    
    /// Message has been delivered to recipient
    Delivered,
    
    /// Message has been read by recipient
    Read,
    
    /// Message failed to send
    Failed,
}

impl MessageStatus {
    pub fn from_str(s: &str) -> Self {
        match s.to_lowercase().as_str() {
            "pending" => MessageStatus::Pending,
            "sent" => MessageStatus::Sent,
            "delivered" => MessageStatus::Delivered,
            "read" => MessageStatus::Read,
            "failed" => MessageStatus::Failed,
            _ => MessageStatus::Pending,
        }
    }
}

impl ToString for MessageStatus {
    fn to_string(&self) -> String {
        match self {
            MessageStatus::Pending => "pending".to_string(),
            MessageStatus::Sent => "sent".to_string(),
            MessageStatus::Delivered => "delivered".to_string(),
            MessageStatus::Read => "read".to_string(),
            MessageStatus::Failed => "failed".to_string(),
        }
    }
}

/// A message
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Message {
    /// Unique message ID
    pub id: String,
    
    /// Conversation ID (contact or group)
    pub conversation_id: String,
    
    /// Sender ID
    pub sender_id: String,
    
    /// Message content (plaintext - encrypted before sending)
    pub content: String,
    
    /// Unix timestamp
    pub timestamp: i64,
    
    /// Message status
    pub status: MessageStatus,
}

impl Message {
    pub fn new(id: String, conversation_id: String, sender_id: String, content: String) -> Self {
        Message {
            id,
            conversation_id,
            sender_id,
            content,
            timestamp: chrono::Utc::now().timestamp(),
            status: MessageStatus::Pending,
        }
    }
}

/// Message type (for different content types)
#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum MessageType {
    Text,
    Image,
    Voice,
    Video,
    File,
    Location,
    Contact,
}

/// Encrypted message (for transport)
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct EncryptedMessage {
    /// Message ID
    pub id: String,
    
    /// Sender ID
    pub sender_id: String,
    
    /// Recipient ID
    pub recipient_id: String,
    
    /// Encrypted content (ciphertext)
    pub encrypted_content: Vec<u8>,
    
    /// Message type
    pub message_type: MessageType,
    
    /// Timestamp
    pub timestamp: i64,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_message_creation() {
        let msg = Message::new(
            "msg1".to_string(),
            "conv1".to_string(),
            "sender1".to_string(),
            "Hello!".to_string(),
        );
        
        assert_eq!(msg.id, "msg1");
        assert_eq!(msg.status, MessageStatus::Pending);
    }

    #[test]
    fn test_status_conversion() {
        assert_eq!(MessageStatus::from_str("pending"), MessageStatus::Pending);
        assert_eq!(MessageStatus::from_str("sent"), MessageStatus::Sent);
        assert_eq!(MessageStatus::from_str("delivered"), MessageStatus::Delivered);
        assert_eq!(MessageStatus::from_str("read"), MessageStatus::Read);
    }
}
