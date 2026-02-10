// Package message tests - comprehensive integration tests for message types
package message

import (
	"encoding/json"
	"testing"
	"time"
)

// ═══════════════════════════════════════
// 1. Message Creation
// ═══════════════════════════════════════

func TestNewMessage(t *testing.T) {
	ts := time.Now().Unix()
	msg := NewMessage("test-id", "conv-1", "sender-1", "Hello!", ts)

	if msg.ID != "test-id" {
		t.Errorf("ID = %q, want %q", msg.ID, "test-id")
	}
	if msg.ConversationID != "conv-1" {
		t.Errorf("ConversationID = %q, want %q", msg.ConversationID, "conv-1")
	}
	if msg.SenderID != "sender-1" {
		t.Errorf("SenderID = %q, want %q", msg.SenderID, "sender-1")
	}
	if msg.Content != "Hello!" {
		t.Errorf("Content = %q, want %q", msg.Content, "Hello!")
	}
	if msg.Timestamp != ts {
		t.Errorf("Timestamp = %d, want %d", msg.Timestamp, ts)
	}
	if msg.Status != StatusPending {
		t.Errorf("Status = %q, want %q", msg.Status, StatusPending)
	}
}

func TestNewMessageDefaultStatus(t *testing.T) {
	msg := NewMessage("id", "conv", "sender", "content", 0)
	if msg.Status != StatusPending {
		t.Errorf("new message status = %q, want %q", msg.Status, StatusPending)
	}
}

// ═══════════════════════════════════════
// 2. Message Status
// ═══════════════════════════════════════

func TestMessageStatusValues(t *testing.T) {
	tests := []struct {
		status MessageStatus
		want   string
	}{
		{StatusPending, "pending"},
		{StatusSent, "sent"},
		{StatusDelivered, "delivered"},
		{StatusRead, "read"},
		{StatusFailed, "failed"},
	}

	for _, tt := range tests {
		if string(tt.status) != tt.want {
			t.Errorf("status = %q, want %q", string(tt.status), tt.want)
		}
	}
}

func TestMessageStatusTransitions(t *testing.T) {
	msg := NewMessage("id", "conv", "sender", "content", 0)

	// Pending → Sent
	msg.Status = StatusSent
	if msg.Status != StatusSent {
		t.Errorf("after setting Sent, status = %q", msg.Status)
	}

	// Sent → Delivered
	msg.Status = StatusDelivered
	if msg.Status != StatusDelivered {
		t.Errorf("after setting Delivered, status = %q", msg.Status)
	}

	// Delivered → Read
	msg.Status = StatusRead
	if msg.Status != StatusRead {
		t.Errorf("after setting Read, status = %q", msg.Status)
	}
}

// ═══════════════════════════════════════
// 3. Serialization
// ═══════════════════════════════════════

func TestMessageSerialization(t *testing.T) {
	msg := NewMessage("ser-1", "conv-1", "alice", "Hello Bob!", 1234567890)
	msg.Status = StatusSent

	// Marshal
	data, err := json.Marshal(msg)
	if err != nil {
		t.Fatalf("json.Marshal error: %v", err)
	}

	// Unmarshal
	var restored Message
	if err := json.Unmarshal(data, &restored); err != nil {
		t.Fatalf("json.Unmarshal error: %v", err)
	}

	if restored.ID != msg.ID {
		t.Errorf("ID = %q, want %q", restored.ID, msg.ID)
	}
	if restored.ConversationID != msg.ConversationID {
		t.Errorf("ConversationID = %q, want %q", restored.ConversationID, msg.ConversationID)
	}
	if restored.SenderID != msg.SenderID {
		t.Errorf("SenderID = %q, want %q", restored.SenderID, msg.SenderID)
	}
	if restored.Content != msg.Content {
		t.Errorf("Content = %q, want %q", restored.Content, msg.Content)
	}
	if restored.Timestamp != msg.Timestamp {
		t.Errorf("Timestamp = %d, want %d", restored.Timestamp, msg.Timestamp)
	}
	if restored.Status != msg.Status {
		t.Errorf("Status = %q, want %q", restored.Status, msg.Status)
	}
}

func TestMessageJSONStructure(t *testing.T) {
	msg := NewMessage("json-1", "conv-1", "alice", "Test", 1000)

	data, _ := json.Marshal(msg)
	jsonStr := string(data)

	// Verify JSON field names
	expectedFields := []string{
		`"id"`, `"conversation_id"`, `"sender_id"`,
		`"content"`, `"timestamp"`, `"status"`,
	}

	for _, field := range expectedFields {
		if !contains(jsonStr, field) {
			t.Errorf("JSON should contain field %s, got: %s", field, jsonStr)
		}
	}
}

func TestEncryptedMessageSerialization(t *testing.T) {
	enc := &EncryptedMessage{
		ID:               "enc-1",
		SenderID:         "alice",
		RecipientID:      "bob",
		EncryptedContent: []byte{0xDE, 0xAD, 0xBE, 0xEF},
		MessageType:      TypeText,
		Timestamp:        1234567890,
	}

	data, err := json.Marshal(enc)
	if err != nil {
		t.Fatalf("json.Marshal error: %v", err)
	}

	var restored EncryptedMessage
	if err := json.Unmarshal(data, &restored); err != nil {
		t.Fatalf("json.Unmarshal error: %v", err)
	}

	if restored.ID != enc.ID {
		t.Errorf("ID = %q, want %q", restored.ID, enc.ID)
	}
	if restored.SenderID != enc.SenderID {
		t.Errorf("SenderID = %q, want %q", restored.SenderID, enc.SenderID)
	}
	if restored.RecipientID != enc.RecipientID {
		t.Errorf("RecipientID = %q, want %q", restored.RecipientID, enc.RecipientID)
	}
	if restored.MessageType != enc.MessageType {
		t.Errorf("MessageType = %q, want %q", restored.MessageType, enc.MessageType)
	}
}

// ═══════════════════════════════════════
// 4. Message Types
// ═══════════════════════════════════════

func TestMessageTypeValues(t *testing.T) {
	types := map[MessageType]string{
		TypeText:     "text",
		TypeImage:    "image",
		TypeVoice:    "voice",
		TypeVideo:    "video",
		TypeFile:     "file",
		TypeLocation: "location",
		TypeContact:  "contact",
	}

	for mt, expected := range types {
		if string(mt) != expected {
			t.Errorf("MessageType = %q, want %q", string(mt), expected)
		}
	}
}

func TestMessageTypeCount(t *testing.T) {
	// Ensure we have 7 message types
	types := []MessageType{TypeText, TypeImage, TypeVoice, TypeVideo, TypeFile, TypeLocation, TypeContact}
	if len(types) != 7 {
		t.Errorf("expected 7 message types, got %d", len(types))
	}
}

// ═══════════════════════════════════════
// 5. Edge Cases
// ═══════════════════════════════════════

func TestEmptyContent(t *testing.T) {
	msg := NewMessage("empty", "conv", "sender", "", 0)
	if msg.Content != "" {
		t.Error("empty content should be preserved")
	}

	data, _ := json.Marshal(msg)
	var restored Message
	json.Unmarshal(data, &restored)
	if restored.Content != "" {
		t.Error("empty content should survive serialization")
	}
}

func TestUnicodeContent(t *testing.T) {
	unicodeTexts := []string{
		"Hello 🌍🔐💬",
		"مرحبا",
		"こんにちは",
		"Привет мир",
		"🇮🇳 भारत",
	}

	for _, text := range unicodeTexts {
		msg := NewMessage("unicode", "conv", "sender", text, 0)

		data, err := json.Marshal(msg)
		if err != nil {
			t.Fatalf("Marshal(%q) error: %v", text, err)
		}

		var restored Message
		json.Unmarshal(data, &restored)
		if restored.Content != text {
			t.Errorf("Content = %q, want %q", restored.Content, text)
		}
	}
}

func TestZeroTimestamp(t *testing.T) {
	msg := NewMessage("id", "conv", "sender", "content", 0)
	if msg.Timestamp != 0 {
		t.Errorf("Timestamp = %d, want 0", msg.Timestamp)
	}
}

func TestNegativeTimestamp(t *testing.T) {
	msg := NewMessage("id", "conv", "sender", "content", -1)
	if msg.Timestamp != -1 {
		t.Errorf("Timestamp = %d, want -1", msg.Timestamp)
	}
}

// ═══════════════════════════════════════
// Helpers
// ═══════════════════════════════════════

func contains(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(s) > 0 && containsSubstring(s, substr))
}

func containsSubstring(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
