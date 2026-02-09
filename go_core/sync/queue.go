// Package sync provides offline message queue functionality.
// This mirrors Briar's sync capabilities in bramble-api/sync
package sync

import (
	"sync"
	"time"
)

// QueuedMessage represents a message waiting to be sent
type QueuedMessage struct {
	ID               string `json:"id"`
	RecipientID      string `json:"recipient_id"`
	EncryptedContent []byte `json:"encrypted_content"`
	CreatedAt        int64  `json:"created_at"`
	Attempts         int    `json:"attempts"`
}

// NewQueuedMessage creates a new queued message
func NewQueuedMessage(id, recipientID string, encryptedContent []byte) *QueuedMessage {
	return &QueuedMessage{
		ID:               id,
		RecipientID:      recipientID,
		EncryptedContent: encryptedContent,
		CreatedAt:        time.Now().Unix(),
		Attempts:         0,
	}
}

// MessageQueue manages offline messages
type MessageQueue struct {
	messages []*QueuedMessage
	mu       sync.RWMutex
}

// NewMessageQueue creates a new message queue
func NewMessageQueue() *MessageQueue {
	return &MessageQueue{
		messages: make([]*QueuedMessage, 0),
	}
}

// Enqueue adds a message to the queue
func (q *MessageQueue) Enqueue(msg *QueuedMessage) {
	q.mu.Lock()
	defer q.mu.Unlock()
	q.messages = append(q.messages, msg)
}

// Dequeue removes and returns the first message
func (q *MessageQueue) Dequeue() *QueuedMessage {
	q.mu.Lock()
	defer q.mu.Unlock()

	if len(q.messages) == 0 {
		return nil
	}

	msg := q.messages[0]
	q.messages = q.messages[1:]
	return msg
}

// Peek returns the first message without removing it
func (q *MessageQueue) Peek() *QueuedMessage {
	q.mu.RLock()
	defer q.mu.RUnlock()

	if len(q.messages) == 0 {
		return nil
	}

	return q.messages[0]
}

// GetAll returns all queued messages
func (q *MessageQueue) GetAll() []*QueuedMessage {
	q.mu.RLock()
	defer q.mu.RUnlock()

	result := make([]*QueuedMessage, len(q.messages))
	copy(result, q.messages)
	return result
}

// GetForRecipient returns messages for a specific recipient
func (q *MessageQueue) GetForRecipient(recipientID string) []*QueuedMessage {
	q.mu.RLock()
	defer q.mu.RUnlock()

	var result []*QueuedMessage
	for _, msg := range q.messages {
		if msg.RecipientID == recipientID {
			result = append(result, msg)
		}
	}
	return result
}

// Clear removes messages by ID
func (q *MessageQueue) Clear(ids []string) {
	q.mu.Lock()
	defer q.mu.Unlock()

	idSet := make(map[string]bool)
	for _, id := range ids {
		idSet[id] = true
	}

	var remaining []*QueuedMessage
	for _, msg := range q.messages {
		if !idSet[msg.ID] {
			remaining = append(remaining, msg)
		}
	}

	q.messages = remaining
}

// IncrementAttempts increments the attempt counter for a message
func (q *MessageQueue) IncrementAttempts(id string) {
	q.mu.Lock()
	defer q.mu.Unlock()

	for _, msg := range q.messages {
		if msg.ID == id {
			msg.Attempts++
			break
		}
	}
}

// Len returns the number of queued messages
func (q *MessageQueue) Len() int {
	q.mu.RLock()
	defer q.mu.RUnlock()
	return len(q.messages)
}

// IsEmpty returns true if the queue is empty
func (q *MessageQueue) IsEmpty() bool {
	return q.Len() == 0
}
