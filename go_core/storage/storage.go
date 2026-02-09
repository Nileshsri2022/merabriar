// Package storage provides encrypted local storage using SQLCipher.
// This mirrors Briar's bramble-api/db/DatabaseComponent
package storage

import (
	"database/sql"
	"fmt"

	"merabriar_core/message"

	_ "github.com/mattn/go-sqlite3"
)

// Storage handles encrypted database operations
type Storage struct {
	db *sql.DB
}

// New creates a new encrypted storage instance
func New(dbPath, encryptionKey string) (*Storage, error) {
	// For SQLCipher, connection string includes encryption key
	// Note: In production, use a SQLCipher build
	connStr := fmt.Sprintf("%s?_pragma_key=%s&_pragma_cipher_page_size=4096", dbPath, encryptionKey)
	
	db, err := sql.Open("sqlite3", connStr)
	if err != nil {
		return nil, err
	}

	// Create tables
	if err := createTables(db); err != nil {
		return nil, err
	}

	return &Storage{db: db}, nil
}

// createTables creates the database schema
func createTables(db *sql.DB) error {
	schema := `
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
		
		-- Sessions table
		CREATE TABLE IF NOT EXISTS sessions (
			recipient_id TEXT PRIMARY KEY,
			session_data BLOB NOT NULL,
			created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
			updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
		);
		
		-- Queue table
		CREATE TABLE IF NOT EXISTS queue (
			id TEXT PRIMARY KEY,
			recipient_id TEXT NOT NULL,
			encrypted_content BLOB NOT NULL,
			created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
		);
		
		-- Keys table
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
	`

	_, err := db.Exec(schema)
	return err
}

// StoreMessage stores a message in the database
func (s *Storage) StoreMessage(msg *message.Message) error {
	_, err := s.db.Exec(`
		INSERT OR REPLACE INTO messages 
		(id, conversation_id, sender_id, content, timestamp, status) 
		VALUES (?, ?, ?, ?, ?, ?)`,
		msg.ID,
		msg.ConversationID,
		msg.SenderID,
		msg.Content,
		msg.Timestamp,
		msg.Status,
	)
	return err
}

// GetMessage retrieves a single message by ID
func (s *Storage) GetMessage(id string) (*message.Message, error) {
	var msg message.Message
	err := s.db.QueryRow(`
		SELECT id, conversation_id, sender_id, content, timestamp, status 
		FROM messages WHERE id = ?`, id,
	).Scan(&msg.ID, &msg.ConversationID, &msg.SenderID, &msg.Content, &msg.Timestamp, &msg.Status)
	
	if err != nil {
		return nil, err
	}
	return &msg, nil
}

// GetMessages retrieves messages for a conversation
func (s *Storage) GetMessages(conversationID string, limit, offset int) ([]*message.Message, error) {
	rows, err := s.db.Query(`
		SELECT id, conversation_id, sender_id, content, timestamp, status 
		FROM messages 
		WHERE conversation_id = ? 
		ORDER BY timestamp DESC 
		LIMIT ? OFFSET ?`,
		conversationID, limit, offset,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var messages []*message.Message
	for rows.Next() {
		var msg message.Message
		if err := rows.Scan(&msg.ID, &msg.ConversationID, &msg.SenderID, &msg.Content, &msg.Timestamp, &msg.Status); err != nil {
			return nil, err
		}
		messages = append(messages, &msg)
	}

	return messages, nil
}

// StoreSession stores a session in the database
func (s *Storage) StoreSession(recipientID string, sessionData []byte) error {
	_, err := s.db.Exec(`
		INSERT OR REPLACE INTO sessions (recipient_id, session_data, updated_at) 
		VALUES (?, ?, strftime('%s', 'now'))`,
		recipientID, sessionData,
	)
	return err
}

// GetSession retrieves a session from the database
func (s *Storage) GetSession(recipientID string) ([]byte, error) {
	var sessionData []byte
	err := s.db.QueryRow(`SELECT session_data FROM sessions WHERE recipient_id = ?`, recipientID).Scan(&sessionData)
	if err != nil {
		return nil, err
	}
	return sessionData, nil
}

// Close closes the database connection
func (s *Storage) Close() error {
	return s.db.Close()
}
