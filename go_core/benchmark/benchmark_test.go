// Package benchmark provides comprehensive Go core benchmarks.
//
// Run all (requires CGO for storage):
//
//	CC=C:/msys64/mingw64/bin/gcc.exe CGO_ENABLED=1 go test -bench=. -benchmem -count=3 ./benchmark/
//
// Run without storage (no CGO needed):
//
//	go test -bench=. -benchmem -count=3 -tags nostorage ./benchmark/
package benchmark

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"
	"strings"
	"testing"

	"merabriar_core/crypto"
	"merabriar_core/message"
	gosync "merabriar_core/sync"

	"golang.org/x/crypto/curve25519"
	"golang.org/x/crypto/hkdf"
)

// ═══════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════

// createMatchedPair creates a sender/receiver session pair for benchmarks
func createMatchedPair(b *testing.B) (sender *crypto.Session, receiver *crypto.Session) {
	b.Helper()

	alice := crypto.NewKeyManager()
	alice.GenerateIdentityKeys()

	bob := crypto.NewKeyManager()
	bob.GenerateIdentityKeys()
	bobPub, _ := bob.GetPublicKeyBundle()

	sender, _ = crypto.NewSession("bob", alice, bobPub)

	// Build receiver with swapped chains
	alicePreKeyPriv, _ := alice.GetSignedPreKeyPrivate()
	var ap [32]byte
	copy(ap[:], alicePreKeyPriv)
	sharedSecret, _ := curve25519.X25519(ap[:], bobPub.SignedPreKey)

	hkdfReader := hkdf.New(sha256.New, sharedSecret, nil, []byte("merabriar_session"))
	var rootKey, sendChain, recvChain [32]byte
	io.ReadFull(hkdfReader, rootKey[:])
	io.ReadFull(hkdfReader, sendChain[:])
	io.ReadFull(hkdfReader, recvChain[:])

	receiver = crypto.NewSessionDirect("alice", rootKey, recvChain, sendChain)

	return sender, receiver
}

// ═══════════════════════════════════════════════════
// 1. CRYPTOGRAPHY BENCHMARKS
// ═══════════════════════════════════════════════════

func BenchmarkKeyGeneration(b *testing.B) {
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		km := crypto.NewKeyManager()
		km.GenerateIdentityKeys()
	}
}

func BenchmarkSessionSetup(b *testing.B) {
	alice := crypto.NewKeyManager()
	alice.GenerateIdentityKeys()

	bob := crypto.NewKeyManager()
	bob.GenerateIdentityKeys()
	bobPub, _ := bob.GetPublicKeyBundle()

	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		crypto.NewSession("bench-recipient", alice, bobPub)
	}
}

func BenchmarkEncrypt64B(b *testing.B) {
	benchmarkEncrypt(b, 64)
}

func BenchmarkEncrypt256B(b *testing.B) {
	benchmarkEncrypt(b, 256)
}

func BenchmarkEncrypt1KB(b *testing.B) {
	benchmarkEncrypt(b, 1024)
}

func BenchmarkEncrypt4KB(b *testing.B) {
	benchmarkEncrypt(b, 4096)
}

func BenchmarkEncrypt64KB(b *testing.B) {
	benchmarkEncrypt(b, 65536)
}

func benchmarkEncrypt(b *testing.B, size int) {
	alice := crypto.NewKeyManager()
	alice.GenerateIdentityKeys()

	bob := crypto.NewKeyManager()
	bob.GenerateIdentityKeys()
	bobPub, _ := bob.GetPublicKeyBundle()

	session, _ := crypto.NewSession("bench", alice, bobPub)
	plaintext := []byte(strings.Repeat("A", size))

	b.SetBytes(int64(size))
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		session.Encrypt(plaintext)
	}
}

func BenchmarkDecrypt64B(b *testing.B) {
	benchmarkDecrypt(b, 64)
}

func BenchmarkDecrypt256B(b *testing.B) {
	benchmarkDecrypt(b, 256)
}

func BenchmarkDecrypt1KB(b *testing.B) {
	benchmarkDecrypt(b, 1024)
}

func BenchmarkDecrypt4KB(b *testing.B) {
	benchmarkDecrypt(b, 4096)
}

func BenchmarkDecrypt64KB(b *testing.B) {
	benchmarkDecrypt(b, 65536)
}

func benchmarkDecrypt(b *testing.B, size int) {
	sender, receiver := createMatchedPair(b)
	plaintext := []byte(strings.Repeat("B", size))

	// Pre-encrypt all messages
	ciphertexts := make([][]byte, b.N)
	for i := 0; i < b.N; i++ {
		ct, _ := sender.Encrypt(plaintext)
		ciphertexts[i] = ct
	}

	b.SetBytes(int64(size))
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		receiver.Decrypt(ciphertexts[i])
	}
}

func BenchmarkEncryptDecryptRoundTrip(b *testing.B) {
	sender, receiver := createMatchedPair(b)
	plaintext := []byte("Standard benchmark message for round-trip E2E test")

	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		ct, _ := sender.Encrypt(plaintext)
		receiver.Decrypt(ct)
	}
}

// ═══════════════════════════════════════════════════
// 2. SYNC / QUEUE BENCHMARKS
// ═══════════════════════════════════════════════════

func BenchmarkQueueEnqueue(b *testing.B) {
	q := gosync.NewMessageQueue()

	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		msg := gosync.NewQueuedMessage(
			fmt.Sprintf("enq-%d", i),
			"recipient",
			[]byte{1, 2, 3, 4, 5, 6, 7, 8},
		)
		q.Enqueue(msg)
	}
}

func BenchmarkQueueDequeue(b *testing.B) {
	q := gosync.NewMessageQueue()

	// Pre-populate
	for i := 0; i < b.N; i++ {
		q.Enqueue(gosync.NewQueuedMessage(
			fmt.Sprintf("deq-%d", i), "recipient", []byte{1, 2, 3},
		))
	}

	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		q.Dequeue()
	}
}

func BenchmarkQueueGetAll500(b *testing.B) {
	q := gosync.NewMessageQueue()
	for i := 0; i < 500; i++ {
		recip := "alice"
		if i%2 != 0 {
			recip = "bob"
		}
		q.Enqueue(gosync.NewQueuedMessage(
			fmt.Sprintf("getall-%d", i), recip, []byte{1, 2, 3, 4},
		))
	}

	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		q.GetAll()
	}
}

func BenchmarkQueueFilterRecipient(b *testing.B) {
	q := gosync.NewMessageQueue()
	for i := 0; i < 500; i++ {
		recip := "alice"
		if i%2 != 0 {
			recip = "bob"
		}
		q.Enqueue(gosync.NewQueuedMessage(
			fmt.Sprintf("filter-%d", i), recip, []byte{1, 2, 3, 4},
		))
	}

	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		q.GetForRecipient("alice")
	}
}

// ═══════════════════════════════════════════════════
// 3. SERIALIZATION BENCHMARKS
// ═══════════════════════════════════════════════════

func BenchmarkMessageSerialize(b *testing.B) {
	msg := message.NewMessage("ser-bench", "conv-bench", "alice",
		"Benchmark serialization content with some reasonable length text", 1234567890)

	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		json.Marshal(msg)
	}
}

func BenchmarkMessageDeserialize(b *testing.B) {
	msg := message.NewMessage("ser-bench", "conv-bench", "alice",
		"Benchmark serialization content with some reasonable length text", 1234567890)
	data, _ := json.Marshal(msg)

	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		var m message.Message
		json.Unmarshal(data, &m)
	}
}

func BenchmarkEncryptedMessageSerialize(b *testing.B) {
	enc := &message.EncryptedMessage{
		ID:               "enc-bench",
		SenderID:         "alice",
		RecipientID:      "bob",
		EncryptedContent: make([]byte, 512),
		MessageType:      message.TypeText,
		Timestamp:        1234567890,
	}

	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		json.Marshal(enc)
	}
}

func BenchmarkEncryptedMessageDeserialize(b *testing.B) {
	enc := &message.EncryptedMessage{
		ID:               "enc-bench",
		SenderID:         "alice",
		RecipientID:      "bob",
		EncryptedContent: make([]byte, 512),
		MessageType:      message.TypeText,
		Timestamp:        1234567890,
	}
	data, _ := json.Marshal(enc)

	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		var e message.EncryptedMessage
		json.Unmarshal(data, &e)
	}
}
