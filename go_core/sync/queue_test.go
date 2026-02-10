// Package sync tests - comprehensive integration tests for message queue
package sync

import (
	"strconv"
	"sync"
	"testing"
)

// ═══════════════════════════════════════
// 1. Queue Basic Operations
// ═══════════════════════════════════════

func TestNewMessageQueue(t *testing.T) {
	q := NewMessageQueue()
	if q == nil {
		t.Fatal("NewMessageQueue() should not return nil")
	}
	if !q.IsEmpty() {
		t.Error("new queue should be empty")
	}
	if q.Len() != 0 {
		t.Errorf("new queue length = %d, want 0", q.Len())
	}
}

func TestEnqueue(t *testing.T) {
	q := NewMessageQueue()
	msg := NewQueuedMessage("msg-1", "alice", []byte{1, 2, 3})

	q.Enqueue(msg)

	if q.IsEmpty() {
		t.Error("queue should not be empty after enqueue")
	}
	if q.Len() != 1 {
		t.Errorf("queue length = %d, want 1", q.Len())
	}
}

func TestDequeue(t *testing.T) {
	q := NewMessageQueue()
	q.Enqueue(NewQueuedMessage("msg-1", "alice", []byte{1}))
	q.Enqueue(NewQueuedMessage("msg-2", "bob", []byte{2}))

	msg := q.Dequeue()
	if msg == nil {
		t.Fatal("Dequeue() should return a message")
	}
	if msg.ID != "msg-1" {
		t.Errorf("Dequeue() first message ID = %q, want %q", msg.ID, "msg-1")
	}

	if q.Len() != 1 {
		t.Errorf("queue length after dequeue = %d, want 1", q.Len())
	}

	msg2 := q.Dequeue()
	if msg2.ID != "msg-2" {
		t.Errorf("second dequeue ID = %q, want %q", msg2.ID, "msg-2")
	}

	if !q.IsEmpty() {
		t.Error("queue should be empty after dequeuing all messages")
	}
}

func TestDequeueEmpty(t *testing.T) {
	q := NewMessageQueue()
	msg := q.Dequeue()
	if msg != nil {
		t.Error("Dequeue() on empty queue should return nil")
	}
}

func TestPeek(t *testing.T) {
	q := NewMessageQueue()
	q.Enqueue(NewQueuedMessage("msg-peek", "alice", []byte{1}))

	msg := q.Peek()
	if msg == nil {
		t.Fatal("Peek() should return a message")
	}
	if msg.ID != "msg-peek" {
		t.Errorf("Peek() message ID = %q, want %q", msg.ID, "msg-peek")
	}

	// Queue size should not change after peek
	if q.Len() != 1 {
		t.Error("Peek() should not remove the message")
	}
}

func TestPeekEmpty(t *testing.T) {
	q := NewMessageQueue()
	msg := q.Peek()
	if msg != nil {
		t.Error("Peek() on empty queue should return nil")
	}
}

func TestFIFOOrder(t *testing.T) {
	q := NewMessageQueue()
	for i := 0; i < 5; i++ {
		q.Enqueue(NewQueuedMessage("msg-"+strconv.Itoa(i), "alice", []byte{byte(i)}))
	}

	for i := 0; i < 5; i++ {
		msg := q.Dequeue()
		expected := "msg-" + strconv.Itoa(i)
		if msg.ID != expected {
			t.Errorf("dequeue order: got %q, want %q", msg.ID, expected)
		}
	}
}

// ═══════════════════════════════════════
// 2. Queue Filtering
// ═══════════════════════════════════════

func TestGetAll(t *testing.T) {
	q := NewMessageQueue()
	q.Enqueue(NewQueuedMessage("m1", "alice", []byte{1}))
	q.Enqueue(NewQueuedMessage("m2", "bob", []byte{2}))
	q.Enqueue(NewQueuedMessage("m3", "alice", []byte{3}))

	all := q.GetAll()
	if len(all) != 3 {
		t.Errorf("GetAll() returned %d messages, want 3", len(all))
	}
}

func TestGetAllReturnsSnapshotCopy(t *testing.T) {
	q := NewMessageQueue()
	q.Enqueue(NewQueuedMessage("m1", "alice", []byte{1}))

	all := q.GetAll()

	// Enqueue more after snapshot
	q.Enqueue(NewQueuedMessage("m2", "bob", []byte{2}))

	// Snapshot should not be affected
	if len(all) != 1 {
		t.Error("GetAll() should return a snapshot, not a live reference")
	}
}

func TestGetForRecipient(t *testing.T) {
	q := NewMessageQueue()
	q.Enqueue(NewQueuedMessage("m1", "alice", []byte{1}))
	q.Enqueue(NewQueuedMessage("m2", "bob", []byte{2}))
	q.Enqueue(NewQueuedMessage("m3", "alice", []byte{3}))
	q.Enqueue(NewQueuedMessage("m4", "charlie", []byte{4}))

	aliceMsgs := q.GetForRecipient("alice")
	if len(aliceMsgs) != 2 {
		t.Errorf("GetForRecipient(alice) = %d messages, want 2", len(aliceMsgs))
	}

	for _, msg := range aliceMsgs {
		if msg.RecipientID != "alice" {
			t.Errorf("filtered message has RecipientID = %q, want %q", msg.RecipientID, "alice")
		}
	}

	bobMsgs := q.GetForRecipient("bob")
	if len(bobMsgs) != 1 {
		t.Errorf("GetForRecipient(bob) = %d messages, want 1", len(bobMsgs))
	}
}

func TestGetForRecipientNotFound(t *testing.T) {
	q := NewMessageQueue()
	q.Enqueue(NewQueuedMessage("m1", "alice", []byte{1}))

	msgs := q.GetForRecipient("unknown")
	if len(msgs) != 0 {
		t.Errorf("GetForRecipient(unknown) = %d messages, want 0", len(msgs))
	}
}

// ═══════════════════════════════════════
// 3. Queue Clearing
// ═══════════════════════════════════════

func TestClearSpecificMessages(t *testing.T) {
	q := NewMessageQueue()
	q.Enqueue(NewQueuedMessage("m1", "alice", []byte{1}))
	q.Enqueue(NewQueuedMessage("m2", "bob", []byte{2}))
	q.Enqueue(NewQueuedMessage("m3", "charlie", []byte{3}))

	q.Clear([]string{"m1", "m3"})

	if q.Len() != 1 {
		t.Errorf("after clearing 2 of 3, queue length = %d, want 1", q.Len())
	}

	remaining := q.GetAll()
	if remaining[0].ID != "m2" {
		t.Errorf("remaining message ID = %q, want %q", remaining[0].ID, "m2")
	}
}

func TestClearNonexistentIDs(t *testing.T) {
	q := NewMessageQueue()
	q.Enqueue(NewQueuedMessage("m1", "alice", []byte{1}))

	// Clear IDs that don't exist — should not panic or alter queue
	q.Clear([]string{"nonexistent-1", "nonexistent-2"})

	if q.Len() != 1 {
		t.Errorf("clearing nonexistent IDs should not affect queue, length = %d, want 1", q.Len())
	}
}

func TestClearEmptyList(t *testing.T) {
	q := NewMessageQueue()
	q.Enqueue(NewQueuedMessage("m1", "alice", []byte{1}))

	q.Clear([]string{})

	if q.Len() != 1 {
		t.Error("clearing empty list should not affect queue")
	}
}

func TestClearAllMessages(t *testing.T) {
	q := NewMessageQueue()
	q.Enqueue(NewQueuedMessage("m1", "alice", []byte{1}))
	q.Enqueue(NewQueuedMessage("m2", "bob", []byte{2}))

	q.Clear([]string{"m1", "m2"})

	if !q.IsEmpty() {
		t.Error("queue should be empty after clearing all messages")
	}
}

// ═══════════════════════════════════════
// 4. Queue Attempts & Metadata
// ═══════════════════════════════════════

func TestNewQueuedMessage(t *testing.T) {
	msg := NewQueuedMessage("test-id", "alice", []byte{1, 2, 3})

	if msg.ID != "test-id" {
		t.Errorf("ID = %q, want %q", msg.ID, "test-id")
	}
	if msg.RecipientID != "alice" {
		t.Errorf("RecipientID = %q, want %q", msg.RecipientID, "alice")
	}
	if msg.Attempts != 0 {
		t.Errorf("Attempts = %d, want 0", msg.Attempts)
	}
	if msg.CreatedAt <= 0 {
		t.Error("CreatedAt should be a positive timestamp")
	}
}

func TestIncrementAttempts(t *testing.T) {
	q := NewMessageQueue()
	q.Enqueue(NewQueuedMessage("retry-msg", "alice", []byte{1}))

	q.IncrementAttempts("retry-msg")
	q.IncrementAttempts("retry-msg")
	q.IncrementAttempts("retry-msg")

	all := q.GetAll()
	var found *QueuedMessage
	for _, msg := range all {
		if msg.ID == "retry-msg" {
			found = msg
			break
		}
	}

	if found == nil {
		t.Fatal("message not found in queue")
	}
	if found.Attempts != 3 {
		t.Errorf("Attempts = %d, want 3", found.Attempts)
	}
}

func TestIncrementAttemptsNonexistent(t *testing.T) {
	q := NewMessageQueue()
	// Should not panic
	q.IncrementAttempts("nonexistent")
}

// ═══════════════════════════════════════
// 5. Concurrency Tests
// ═══════════════════════════════════════

func TestConcurrentEnqueueDequeue(t *testing.T) {
	q := NewMessageQueue()
	var wg sync.WaitGroup

	// Concurrent enqueues
	for i := 0; i < 100; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			q.Enqueue(NewQueuedMessage("concurrent-"+strconv.Itoa(i), "recip", []byte{byte(i % 256)}))
		}(i)
	}

	wg.Wait()

	if q.Len() != 100 {
		t.Errorf("after 100 concurrent enqueues, length = %d, want 100", q.Len())
	}

	// Concurrent dequeues
	dequeued := make(chan *QueuedMessage, 100)
	for i := 0; i < 100; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			msg := q.Dequeue()
			if msg != nil {
				dequeued <- msg
			}
		}()
	}

	wg.Wait()
	close(dequeued)

	count := 0
	for range dequeued {
		count++
	}

	if count != 100 {
		t.Errorf("dequeued %d messages, want 100", count)
	}

	if !q.IsEmpty() {
		t.Error("queue should be empty after dequeuing all messages")
	}
}

func TestConcurrentReadWrite(t *testing.T) {
	q := NewMessageQueue()
	var wg sync.WaitGroup

	// Writers and readers concurrently
	for i := 0; i < 50; i++ {
		wg.Add(2)
		go func(i int) {
			defer wg.Done()
			q.Enqueue(NewQueuedMessage("rw-"+strconv.Itoa(i), "recip", []byte{byte(i)}))
		}(i)
		go func() {
			defer wg.Done()
			q.GetAll() // Read operation shouldn't conflict
		}()
	}

	wg.Wait()
	// If we reach here without panic/race detection, concurrency is safe
}

// ═══════════════════════════════════════
// 6. Benchmarks
// ═══════════════════════════════════════

func BenchmarkEnqueue(b *testing.B) {
	q := NewMessageQueue()
	msg := NewQueuedMessage("bench-msg", "alice", []byte{1, 2, 3})

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		q.Enqueue(msg)
	}
}

func BenchmarkDequeue(b *testing.B) {
	q := NewMessageQueue()
	for i := 0; i < b.N; i++ {
		q.Enqueue(NewQueuedMessage("bench-"+strconv.Itoa(i), "alice", []byte{1}))
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		q.Dequeue()
	}
}
