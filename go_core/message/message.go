// Package message defines message types.
// This mirrors Briar's message types in briar-api
package message

// MessageStatus represents the status of a message
type MessageStatus string

const (
	StatusPending   MessageStatus = "pending"
	StatusSent      MessageStatus = "sent"
	StatusDelivered MessageStatus = "delivered"
	StatusRead      MessageStatus = "read"
	StatusFailed    MessageStatus = "failed"
)

// Message represents a chat message
type Message struct {
	ID             string        `json:"id"`
	ConversationID string        `json:"conversation_id"`
	SenderID       string        `json:"sender_id"`
	Content        string        `json:"content"`
	Timestamp      int64         `json:"timestamp"`
	Status         MessageStatus `json:"status"`
}

// NewMessage creates a new message
func NewMessage(id, conversationID, senderID, content string, timestamp int64) *Message {
	return &Message{
		ID:             id,
		ConversationID: conversationID,
		SenderID:       senderID,
		Content:        content,
		Timestamp:      timestamp,
		Status:         StatusPending,
	}
}

// MessageType represents different content types
type MessageType string

const (
	TypeText     MessageType = "text"
	TypeImage    MessageType = "image"
	TypeVoice    MessageType = "voice"
	TypeVideo    MessageType = "video"
	TypeFile     MessageType = "file"
	TypeLocation MessageType = "location"
	TypeContact  MessageType = "contact"
)

// EncryptedMessage represents a message ready for transport
type EncryptedMessage struct {
	ID               string      `json:"id"`
	SenderID         string      `json:"sender_id"`
	RecipientID      string      `json:"recipient_id"`
	EncryptedContent []byte      `json:"encrypted_content"`
	MessageType      MessageType `json:"message_type"`
	Timestamp        int64       `json:"timestamp"`
}
