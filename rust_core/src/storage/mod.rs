//! Storage Module
//! 
//! Handles local encrypted storage using SQLCipher.
//! All data at rest is encrypted.
//! 
//! This mirrors Briar's `bramble-api/db/DatabaseComponent`

use rusqlite::{Connection, params};
use std::sync::RwLock;
use serde::{Serialize, Deserialize};

use crate::message::Message;

lazy_static::lazy_static! {
    static ref DB: RwLock<Option<Connection>> = RwLock::new(None);
}

/// Initialize the encrypted database
pub fn init(db_path: &str, encryption_key: &str) -> Result<(), String> {
    let conn = Connection::open(db_path)
        .map_err(|e| format!("Failed to open database: {:?}", e))?;
    
    // Set SQLCipher encryption key
    conn.execute_batch(&format!("PRAGMA key = '{}';", encryption_key))
        .map_err(|e| format!("Failed to set encryption key: {:?}", e))?;
    
    // Create tables
    conn.execute_batch(
        r#"
        -- Messages table
        CREATE TABLE IF NOT EXISTS messages (
            id TEXT PRIMARY KEY,
            conversation_id TEXT NOT NULL,
            sender_id TEXT NOT NULL,
            content TEXT NOT NULL,
            encrypted_content BLOB,
            timestamp INTEGER NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
        );
        
        -- Create index for conversation queries
        CREATE INDEX IF NOT EXISTS idx_messages_conversation 
            ON messages(conversation_id, timestamp DESC);
        
        -- Sessions table (for crypto sessions)
        CREATE TABLE IF NOT EXISTS sessions (
            recipient_id TEXT PRIMARY KEY,
            session_data BLOB NOT NULL,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
            updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
        );
        
        -- Offline queue table
        CREATE TABLE IF NOT EXISTS queue (
            id TEXT PRIMARY KEY,
            recipient_id TEXT NOT NULL,
            encrypted_content BLOB NOT NULL,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
        );
        
        -- Keys table (for our keys)
        CREATE TABLE IF NOT EXISTS keys (
            key_type TEXT PRIMARY KEY,
            key_data BLOB NOT NULL,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
        );
        
        -- Contacts table
        CREATE TABLE IF NOT EXISTS contacts (
            id TEXT PRIMARY KEY,
            display_name TEXT,
            phone_hash TEXT,
            public_keys BLOB,
            is_verified INTEGER DEFAULT 0,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
        );
        "#
    ).map_err(|e| format!("Failed to create tables: {:?}", e))?;
    
    // Store connection
    let mut db = DB.write().map_err(|e| e.to_string())?;
    *db = Some(conn);
    
    Ok(())
}

/// Store a message locally
pub fn store_message(message: &Message) -> Result<(), String> {
    let db = DB.read().map_err(|e| e.to_string())?;
    let conn = db.as_ref().ok_or("Database not initialized")?;
    
    conn.execute(
        "INSERT OR REPLACE INTO messages (id, conversation_id, sender_id, content, timestamp, status) 
         VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
        params![
            message.id,
            message.conversation_id,
            message.sender_id,
            message.content,
            message.timestamp,
            message.status.to_string(),
        ],
    ).map_err(|e| format!("Failed to store message: {:?}", e))?;
    
    Ok(())
}

/// Get messages for a conversation
pub fn get_messages(conversation_id: &str, limit: i32, offset: i32) -> Result<Vec<Message>, String> {
    let db = DB.read().map_err(|e| e.to_string())?;
    let conn = db.as_ref().ok_or("Database not initialized")?;
    
    let mut stmt = conn.prepare(
        "SELECT id, conversation_id, sender_id, content, timestamp, status 
         FROM messages 
         WHERE conversation_id = ?1 
         ORDER BY timestamp DESC 
         LIMIT ?2 OFFSET ?3"
    ).map_err(|e| format!("Failed to prepare query: {:?}", e))?;
    
    let messages = stmt.query_map(params![conversation_id, limit, offset], |row| {
        Ok(Message {
            id: row.get(0)?,
            conversation_id: row.get(1)?,
            sender_id: row.get(2)?,
            content: row.get(3)?,
            timestamp: row.get(4)?,
            status: crate::message::MessageStatus::from_str(&row.get::<_, String>(5)?),
        })
    }).map_err(|e| format!("Failed to query messages: {:?}", e))?;
    
    messages
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| format!("Failed to collect messages: {:?}", e))
}

/// Store a session
pub fn store_session(recipient_id: &str, session_data: &[u8]) -> Result<(), String> {
    let db = DB.read().map_err(|e| e.to_string())?;
    let conn = db.as_ref().ok_or("Database not initialized")?;
    
    conn.execute(
        "INSERT OR REPLACE INTO sessions (recipient_id, session_data, updated_at) 
         VALUES (?1, ?2, strftime('%s', 'now'))",
        params![recipient_id, session_data],
    ).map_err(|e| format!("Failed to store session: {:?}", e))?;
    
    Ok(())
}

/// Get a session
pub fn get_session(recipient_id: &str) -> Result<Option<Vec<u8>>, String> {
    let db = DB.read().map_err(|e| e.to_string())?;
    let conn = db.as_ref().ok_or("Database not initialized")?;
    
    let result = conn.query_row(
        "SELECT session_data FROM sessions WHERE recipient_id = ?1",
        params![recipient_id],
        |row| row.get(0),
    );
    
    match result {
        Ok(data) => Ok(Some(data)),
        Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
        Err(e) => Err(format!("Failed to get session: {:?}", e)),
    }
}

/// Storage trait (mirrors Briar's DatabaseComponent)
pub trait Storage {
    fn init(&self, encryption_key: &str) -> Result<(), String>;
    fn store_message(&self, message: &Message) -> Result<(), String>;
    fn get_message(&self, id: &str) -> Result<Option<Message>, String>;
    fn get_messages(&self, conversation_id: &str, limit: i32, offset: i32) -> Result<Vec<Message>, String>;
}
