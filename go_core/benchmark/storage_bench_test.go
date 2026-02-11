//go:build cgo
// +build cgo

// Storage benchmarks require CGO for go-sqlite3.
// Run with: CC=<64-bit-gcc> CGO_ENABLED=1 go test -bench=BenchmarkStorage -benchmem ./benchmark/
package benchmark

import (
	"fmt"
	"os"
	"testing"

	"merabriar_core/message"
	"merabriar_core/storage"
)

func BenchmarkStorageWriteMessage(b *testing.B) {
	dbPath := "bench_write_msg.db"
	os.Remove(dbPath)
	store, err := storage.New(dbPath, "bench_key")
	if err != nil {
		b.Fatal(err)
	}
	defer func() {
		store.Close()
		os.Remove(dbPath)
	}()

	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		msg := &message.Message{
			ID:             fmt.Sprintf("bench-msg-%d", i),
			ConversationID: "bench-conv",
			SenderID:       "alice",
			Content:        "Benchmark message content for storage performance testing",
			Timestamp:      int64(1000 + i),
			Status:         message.StatusSent,
		}
		store.StoreMessage(msg)
	}
}

func BenchmarkStorageReadMessages50(b *testing.B) {
	dbPath := "bench_read_msg.db"
	os.Remove(dbPath)
	store, err := storage.New(dbPath, "bench_key")
	if err != nil {
		b.Fatal(err)
	}
	defer func() {
		store.Close()
		os.Remove(dbPath)
	}()

	// Pre-populate 1000 messages
	for i := 0; i < 1000; i++ {
		msg := &message.Message{
			ID:             fmt.Sprintf("read-bench-%d", i),
			ConversationID: "bench-read-conv",
			SenderID:       "alice",
			Content:        fmt.Sprintf("Message content number %d", i),
			Timestamp:      int64(1000 + i),
			Status:         message.StatusSent,
		}
		store.StoreMessage(msg)
	}

	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		store.GetMessages("bench-read-conv", 50, 0)
	}
}

func BenchmarkStorageWriteSession(b *testing.B) {
	dbPath := "bench_session_w.db"
	os.Remove(dbPath)
	store, err := storage.New(dbPath, "bench_key")
	if err != nil {
		b.Fatal(err)
	}
	defer func() {
		store.Close()
		os.Remove(dbPath)
	}()

	sessionData := make([]byte, 256)
	for i := range sessionData {
		sessionData[i] = byte(i % 256)
	}

	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		store.StoreSession(fmt.Sprintf("session-%d", i), sessionData)
	}
}

func BenchmarkStorageReadSession(b *testing.B) {
	dbPath := "bench_session_r.db"
	os.Remove(dbPath)
	store, err := storage.New(dbPath, "bench_key")
	if err != nil {
		b.Fatal(err)
	}
	defer func() {
		store.Close()
		os.Remove(dbPath)
	}()

	sessionData := make([]byte, 256)
	store.StoreSession("read-session", sessionData)

	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		store.GetSession("read-session")
	}
}
