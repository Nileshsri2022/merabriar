// Package storage tests - integration tests for SQLite storage
package storage

import (
	"os"
	"testing"
	"time"

	"merabriar_core/message"
)

// helper: create a temp storage instance
func newTestStorage(t *testing.T) (*Storage, string) {
	t.Helper()
	dbPath := "test_storage_" + t.Name() + ".db"
	os.Remove(dbPath) // clean up from previous runs

	store, err := New(dbPath, "test_key")
	if err != nil {
		t.Fatalf("New() error: %v", err)
	}

	return store, dbPath
}

func cleanup(store *Storage, dbPath string) {
	store.Close()
	os.Remove(dbPath)
}

// ═══════════════════════════════════════
// 1. Storage Initialization
// ═══════════════════════════════════════

func TestNewStorage(t *testing.T) {
	store, dbPath := newTestStorage(t)
	defer cleanup(store, dbPath)

	if store == nil {
		t.Fatal("New() should return non-nil storage")
	}
}

func TestNewStorageCreatesFile(t *testing.T) {
	dbPath := "test_creates_file.db"
	os.Remove(dbPath)

	store, err := New(dbPath, "key")
	if err != nil {
		t.Fatalf("New() error: %v", err)
	}
	defer cleanup(store, dbPath)

	if _, err := os.Stat(dbPath); os.IsNotExist(err) {
		t.Error("database file should exist after init")
	}
}

func TestNewStorageIdempotent(t *testing.T) {
	dbPath := "test_idempotent.db"
	os.Remove(dbPath)

	// Open twice — should not fail (CREATE IF NOT EXISTS)
	store1, err := New(dbPath, "key")
	if err != nil {
		t.Fatalf("first New() error: %v", err)
	}
	store1.Close()

	store2, err := New(dbPath, "key")
	if err != nil {
		t.Fatalf("second New() error: %v", err)
	}
	defer cleanup(store2, dbPath)
}

// ═══════════════════════════════════════
// 2. Message Storage
// ═══════════════════════════════════════

func TestStoreMessage(t *testing.T) {
	store, dbPath := newTestStorage(t)
	defer cleanup(store, dbPath)

	msg := message.NewMessage("msg-1", "conv-1", "alice", "Hello!", time.Now().Unix())

	err := store.StoreMessage(msg)
	if err != nil {
		t.Fatalf("StoreMessage() error: %v", err)
	}
}

func TestStoreAndGetMessage(t *testing.T) {
	store, dbPath := newTestStorage(t)
	defer cleanup(store, dbPath)

	ts := time.Now().Unix()
	msg := message.NewMessage("msg-get-1", "conv-1", "alice", "Hello Bob!", ts)
	store.StoreMessage(msg)

	retrieved, err := store.GetMessage("msg-get-1")
	if err != nil {
		t.Fatalf("GetMessage() error: %v", err)
	}

	if retrieved.ID != "msg-get-1" {
		t.Errorf("ID = %q, want %q", retrieved.ID, "msg-get-1")
	}
	if retrieved.Content != "Hello Bob!" {
		t.Errorf("Content = %q, want %q", retrieved.Content, "Hello Bob!")
	}
	if retrieved.SenderID != "alice" {
		t.Errorf("SenderID = %q, want %q", retrieved.SenderID, "alice")
	}
	if retrieved.ConversationID != "conv-1" {
		t.Errorf("ConversationID = %q, want %q", retrieved.ConversationID, "conv-1")
	}
	if string(retrieved.Status) != string(message.StatusPending) {
		t.Errorf("Status = %q, want %q", retrieved.Status, message.StatusPending)
	}
}

func TestGetMessageNotFound(t *testing.T) {
	store, dbPath := newTestStorage(t)
	defer cleanup(store, dbPath)

	_, err := store.GetMessage("nonexistent")
	if err == nil {
		t.Error("GetMessage() for nonexistent ID should return error")
	}
}

func TestStoreMessageUpsert(t *testing.T) {
	store, dbPath := newTestStorage(t)
	defer cleanup(store, dbPath)

	msg := message.NewMessage("upsert-1", "conv-1", "alice", "Original", 1000)
	store.StoreMessage(msg)

	// Update same ID with different content
	msg2 := &message.Message{
		ID:             "upsert-1",
		ConversationID: "conv-1",
		SenderID:       "alice",
		Content:        "Updated",
		Timestamp:      1001,
		Status:         message.StatusSent,
	}
	err := store.StoreMessage(msg2)
	if err != nil {
		t.Fatalf("StoreMessage (upsert) error: %v", err)
	}

	retrieved, _ := store.GetMessage("upsert-1")
	if retrieved.Content != "Updated" {
		t.Errorf("Content = %q, want %q", retrieved.Content, "Updated")
	}
	if string(retrieved.Status) != string(message.StatusSent) {
		t.Errorf("Status = %q, want %q", retrieved.Status, message.StatusSent)
	}
}

// ═══════════════════════════════════════
// 3. Message Retrieval
// ═══════════════════════════════════════

func TestGetMessages(t *testing.T) {
	store, dbPath := newTestStorage(t)
	defer cleanup(store, dbPath)

	// Store 5 messages
	for i := 0; i < 5; i++ {
		msg := &message.Message{
			ID:             "msg-" + string(rune('a'+i)),
			ConversationID: "conv-1",
			SenderID:       "alice",
			Content:        "Message " + string(rune('A'+i)),
			Timestamp:      int64(1000 + i),
			Status:         message.StatusSent,
		}
		store.StoreMessage(msg)
	}

	messages, err := store.GetMessages("conv-1", 10, 0)
	if err != nil {
		t.Fatalf("GetMessages() error: %v", err)
	}

	if len(messages) != 5 {
		t.Errorf("GetMessages() returned %d messages, want 5", len(messages))
	}
}

func TestGetMessagesPagination(t *testing.T) {
	store, dbPath := newTestStorage(t)
	defer cleanup(store, dbPath)

	for i := 0; i < 10; i++ {
		msg := &message.Message{
			ID:             "page-msg-" + string(rune('a'+i)),
			ConversationID: "conv-page",
			SenderID:       "alice",
			Content:        "Content",
			Timestamp:      int64(1000 + i),
			Status:         message.StatusPending,
		}
		store.StoreMessage(msg)
	}

	// Page 1: 3 messages
	page1, _ := store.GetMessages("conv-page", 3, 0)
	if len(page1) != 3 {
		t.Errorf("page 1 length = %d, want 3", len(page1))
	}

	// Page 2: 3 messages
	page2, _ := store.GetMessages("conv-page", 3, 3)
	if len(page2) != 3 {
		t.Errorf("page 2 length = %d, want 3", len(page2))
	}

	// Pages should not overlap
	if len(page1) > 0 && len(page2) > 0 && page1[0].ID == page2[0].ID {
		t.Error("paginated pages should not overlap")
	}
}

func TestGetMessagesDifferentConversations(t *testing.T) {
	store, dbPath := newTestStorage(t)
	defer cleanup(store, dbPath)

	store.StoreMessage(&message.Message{
		ID: "a1", ConversationID: "conv-A", SenderID: "alice",
		Content: "Hello A", Timestamp: 100, Status: message.StatusSent,
	})
	store.StoreMessage(&message.Message{
		ID: "b1", ConversationID: "conv-B", SenderID: "bob",
		Content: "Hello B", Timestamp: 200, Status: message.StatusSent,
	})

	msgsA, _ := store.GetMessages("conv-A", 10, 0)
	msgsB, _ := store.GetMessages("conv-B", 10, 0)

	if len(msgsA) != 1 {
		t.Errorf("conv-A messages = %d, want 1", len(msgsA))
	}
	if len(msgsB) != 1 {
		t.Errorf("conv-B messages = %d, want 1", len(msgsB))
	}

	if msgsA[0].Content != "Hello A" {
		t.Errorf("conv-A content = %q, want %q", msgsA[0].Content, "Hello A")
	}
	if msgsB[0].Content != "Hello B" {
		t.Errorf("conv-B content = %q, want %q", msgsB[0].Content, "Hello B")
	}
}

func TestGetMessagesEmpty(t *testing.T) {
	store, dbPath := newTestStorage(t)
	defer cleanup(store, dbPath)

	messages, err := store.GetMessages("nonexistent-conv", 10, 0)
	if err != nil {
		t.Fatalf("GetMessages() for empty conversation error: %v", err)
	}
	if messages == nil {
		// nil is acceptable for empty result
	} else if len(messages) != 0 {
		t.Errorf("messages for nonexistent conversation = %d, want 0", len(messages))
	}
}

func TestGetMessagesDescendingOrder(t *testing.T) {
	store, dbPath := newTestStorage(t)
	defer cleanup(store, dbPath)

	for i := 0; i < 5; i++ {
		store.StoreMessage(&message.Message{
			ID: "order-" + string(rune('a'+i)), ConversationID: "conv-order",
			SenderID: "alice", Content: "Content", Timestamp: int64(1000 + i),
			Status: message.StatusPending,
		})
	}

	messages, _ := store.GetMessages("conv-order", 10, 0)

	// Should be in descending order by timestamp
	for i := 1; i < len(messages); i++ {
		if messages[i].Timestamp > messages[i-1].Timestamp {
			t.Errorf("messages should be in descending timestamp order: [%d]=%d > [%d]=%d",
				i, messages[i].Timestamp, i-1, messages[i-1].Timestamp)
		}
	}
}

// ═══════════════════════════════════════
// 4. Session Storage
// ═══════════════════════════════════════

func TestStoreAndGetSession(t *testing.T) {
	store, dbPath := newTestStorage(t)
	defer cleanup(store, dbPath)

	sessionData := []byte{0xCA, 0xFE, 0xBA, 0xBE, 0xDE, 0xAD}

	err := store.StoreSession("alice", sessionData)
	if err != nil {
		t.Fatalf("StoreSession() error: %v", err)
	}

	retrieved, err := store.GetSession("alice")
	if err != nil {
		t.Fatalf("GetSession() error: %v", err)
	}

	if len(retrieved) != len(sessionData) {
		t.Errorf("session data length = %d, want %d", len(retrieved), len(sessionData))
	}

	for i, b := range sessionData {
		if retrieved[i] != b {
			t.Errorf("session data[%d] = %02x, want %02x", i, retrieved[i], b)
		}
	}
}

func TestGetSessionNotFound(t *testing.T) {
	store, dbPath := newTestStorage(t)
	defer cleanup(store, dbPath)

	_, err := store.GetSession("nonexistent")
	if err == nil {
		t.Error("GetSession() for nonexistent recipient should return error")
	}
}

func TestStoreSessionUpsert(t *testing.T) {
	store, dbPath := newTestStorage(t)
	defer cleanup(store, dbPath)

	store.StoreSession("alice", []byte{1, 2, 3})
	store.StoreSession("alice", []byte{4, 5, 6}) // update

	retrieved, _ := store.GetSession("alice")
	if len(retrieved) != 3 || retrieved[0] != 4 {
		t.Error("StoreSession should upsert (update existing)")
	}
}

func TestMultipleSessions(t *testing.T) {
	store, dbPath := newTestStorage(t)
	defer cleanup(store, dbPath)

	store.StoreSession("alice", []byte{1})
	store.StoreSession("bob", []byte{2})
	store.StoreSession("charlie", []byte{3})

	a, _ := store.GetSession("alice")
	b, _ := store.GetSession("bob")
	c, _ := store.GetSession("charlie")

	if a[0] != 1 || b[0] != 2 || c[0] != 3 {
		t.Error("each recipient should have their own session data")
	}
}

// ═══════════════════════════════════════
// 5. Close
// ═══════════════════════════════════════

func TestClose(t *testing.T) {
	store, dbPath := newTestStorage(t)
	defer os.Remove(dbPath)

	err := store.Close()
	if err != nil {
		t.Fatalf("Close() error: %v", err)
	}
}

// ═══════════════════════════════════════
// 6. Unicode & Edge Cases
// ═══════════════════════════════════════

func TestStoreUnicodeMessage(t *testing.T) {
	store, dbPath := newTestStorage(t)
	defer cleanup(store, dbPath)

	unicodeTexts := []string{
		"Hello 🌍🔐💬",
		"مرحبا",
		"こんにちは",
		"🇮🇳 भारत",
	}

	for i, text := range unicodeTexts {
		msg := &message.Message{
			ID: "unicode-" + string(rune('a'+i)), ConversationID: "conv-unicode",
			SenderID: "alice", Content: text, Timestamp: int64(1000 + i),
			Status: message.StatusPending,
		}
		store.StoreMessage(msg)
	}

	messages, _ := store.GetMessages("conv-unicode", 10, 0)
	if len(messages) != len(unicodeTexts) {
		t.Errorf("stored %d messages, retrieved %d", len(unicodeTexts), len(messages))
	}
}

func TestStoreLargeMessage(t *testing.T) {
	store, dbPath := newTestStorage(t)
	defer cleanup(store, dbPath)

	largeContent := ""
	for i := 0; i < 10000; i++ {
		largeContent += "A"
	}

	msg := &message.Message{
		ID: "large", ConversationID: "conv-large", SenderID: "alice",
		Content: largeContent, Timestamp: 1000, Status: message.StatusPending,
	}
	err := store.StoreMessage(msg)
	if err != nil {
		t.Fatalf("StoreMessage (large) error: %v", err)
	}

	retrieved, _ := store.GetMessage("large")
	if len(retrieved.Content) != 10000 {
		t.Errorf("large message content length = %d, want 10000", len(retrieved.Content))
	}
}

func TestStoreLargeSessionData(t *testing.T) {
	store, dbPath := newTestStorage(t)
	defer cleanup(store, dbPath)

	largeData := make([]byte, 10000)
	for i := range largeData {
		largeData[i] = byte(i % 256)
	}

	err := store.StoreSession("big-session", largeData)
	if err != nil {
		t.Fatalf("StoreSession (large) error: %v", err)
	}

	retrieved, _ := store.GetSession("big-session")
	if len(retrieved) != 10000 {
		t.Errorf("large session data length = %d, want 10000", len(retrieved))
	}
}
