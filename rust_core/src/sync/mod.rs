//! Sync Module
//! 
//! Handles offline message queue and synchronization.
//! When offline, messages are queued locally and sent when online.
//! 
//! This mirrors Briar's sync capabilities in `bramble-api/sync`

use serde::{Serialize, Deserialize};
use std::sync::RwLock;
use std::collections::VecDeque;

lazy_static::lazy_static! {
    /// In-memory queue (backed by SQLCipher in production)
    static ref QUEUE: RwLock<VecDeque<QueuedMessage>> = RwLock::new(VecDeque::new());
}

/// A message queued for sending
#[derive(Clone, Serialize, Deserialize)]
pub struct QueuedMessage {
    /// Unique message ID
    pub id: String,
    
    /// Recipient ID
    pub recipient_id: String,
    
    /// Encrypted message content
    pub encrypted_content: Vec<u8>,
    
    /// Timestamp when queued
    pub created_at: i64,
    
    /// Number of send attempts
    pub attempts: u32,
}

impl QueuedMessage {
    pub fn new(id: String, recipient_id: String, encrypted_content: Vec<u8>) -> Self {
        QueuedMessage {
            id,
            recipient_id,
            encrypted_content,
            created_at: chrono::Utc::now().timestamp(),
            attempts: 0,
        }
    }
}

/// Initialize the sync module
pub fn init() -> Result<(), String> {
    // In production, load queued messages from SQLCipher
    Ok(())
}

/// Queue a message for sending
pub fn queue_message(message: QueuedMessage) -> Result<(), String> {
    let mut queue = QUEUE.write().map_err(|e| e.to_string())?;
    queue.push_back(message);
    
    // In production, also persist to SQLCipher
    Ok(())
}

/// Get all queued messages
pub fn get_queued_messages() -> Result<Vec<QueuedMessage>, String> {
    let queue = QUEUE.read().map_err(|e| e.to_string())?;
    Ok(queue.iter().cloned().collect())
}

/// Get queued messages for a specific recipient
pub fn get_queued_for_recipient(recipient_id: &str) -> Result<Vec<QueuedMessage>, String> {
    let queue = QUEUE.read().map_err(|e| e.to_string())?;
    Ok(queue
        .iter()
        .filter(|m| m.recipient_id == recipient_id)
        .cloned()
        .collect())
}

/// Clear sent messages from queue
pub fn clear_queue(message_ids: &[String]) -> Result<(), String> {
    let mut queue = QUEUE.write().map_err(|e| e.to_string())?;
    queue.retain(|m| !message_ids.contains(&m.id));
    
    // In production, also remove from SQLCipher
    Ok(())
}

/// Increment attempt counter for a message
pub fn increment_attempts(message_id: &str) -> Result<(), String> {
    let mut queue = QUEUE.write().map_err(|e| e.to_string())?;
    
    for msg in queue.iter_mut() {
        if msg.id == message_id {
            msg.attempts += 1;
            break;
        }
    }
    
    Ok(())
}

/// Get queue size
pub fn queue_size() -> usize {
    QUEUE.read().map(|q| q.len()).unwrap_or(0)
}

/// Message queue trait
pub trait MessageQueue {
    fn enqueue(&mut self, message: QueuedMessage) -> Result<(), String>;
    fn dequeue(&mut self) -> Option<QueuedMessage>;
    fn peek(&self) -> Option<&QueuedMessage>;
    fn len(&self) -> usize;
    fn is_empty(&self) -> bool;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_queue_message() {
        let msg = QueuedMessage::new(
            "msg1".to_string(),
            "recipient1".to_string(),
            vec![1, 2, 3, 4],
        );
        
        queue_message(msg.clone()).unwrap();
        
        let queued = get_queued_messages().unwrap();
        assert!(queued.iter().any(|m| m.id == "msg1"));
    }

    #[test]
    fn test_clear_queue() {
        let msg = QueuedMessage::new(
            "msg2".to_string(),
            "recipient2".to_string(),
            vec![5, 6, 7, 8],
        );
        
        queue_message(msg).unwrap();
        clear_queue(&["msg2".to_string()]).unwrap();
        
        let queued = get_queued_messages().unwrap();
        assert!(!queued.iter().any(|m| m.id == "msg2"));
    }
}
