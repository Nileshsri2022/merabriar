// Package main provides the MeraBriar Core engine in Go.
// This implements the same interface as the Rust core, allowing
// Flutter to use either implementation.
//
// Architecture (same as Briar):
//
//	┌─────────────────────────────────────────┐
//	│           Flutter UI Layer              │
//	├─────────────────────────────────────────┤
//	│              FFI Bridge                 │
//	├─────────────────────────────────────────┤
//	│           Go Core Engine                │
//	│  ┌─────────┐ ┌─────────┐ ┌───────────┐ │
//	│  │ Crypto  │ │ Storage │ │ Transport │ │
//	│  └─────────┘ └─────────┘ └───────────┘ │
//	└─────────────────────────────────────────┘
package main

/*
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

// Key bundle structure for FFI
typedef struct {
    char* identity_public_key;
    char* signed_prekey;
    char* signature;
    int error;
    char* error_message;
} KeyBundleResult;

// Byte array for encrypted data
typedef struct {
    uint8_t* data;
    int length;
    int error;
    char* error_message;
} ByteArrayResult;

// String result
typedef struct {
    char* data;
    int error;
    char* error_message;
} StringResult;
*/
import "C"

import (
	"encoding/base64"
	"encoding/json"
	"merabriar_core/crypto"
	"merabriar_core/message"
	"merabriar_core/storage"
	"merabriar_core/sync"
	"unsafe"
)

// Global state
var (
	db      *storage.Storage
	queue   *sync.MessageQueue
	keyMgr  *crypto.KeyManager
	sessions = make(map[string]*crypto.Session)
)

//export InitCore
func InitCore(dbPath *C.char, encryptionKey *C.char) C.int {
	path := C.GoString(dbPath)
	key := C.GoString(encryptionKey)

	// Initialize storage
	var err error
	db, err = storage.New(path, key)
	if err != nil {
		return 1
	}

	// Initialize queue
	queue = sync.NewMessageQueue()

	// Initialize key manager
	keyMgr = crypto.NewKeyManager()

	return 0
}

//export GenerateIdentityKeys
func GenerateIdentityKeys() C.KeyBundleResult {
	bundle, err := keyMgr.GenerateIdentityKeys()
	if err != nil {
		return C.KeyBundleResult{
			error:         1,
			error_message: C.CString(err.Error()),
		}
	}

	return C.KeyBundleResult{
		identity_public_key: C.CString(base64.StdEncoding.EncodeToString(bundle.IdentityPublicKey)),
		signed_prekey:       C.CString(base64.StdEncoding.EncodeToString(bundle.SignedPreKey)),
		signature:           C.CString(base64.StdEncoding.EncodeToString(bundle.Signature)),
		error:               0,
	}
}

//export GetPublicKeyBundle
func GetPublicKeyBundle() *C.char {
	bundle, err := keyMgr.GetPublicKeyBundle()
	if err != nil {
		return nil
	}

	jsonBytes, _ := json.Marshal(bundle)
	return C.CString(string(jsonBytes))
}

//export InitSession
func InitSession(recipientId *C.char, keysJson *C.char) C.int {
	rid := C.GoString(recipientId)
	keysStr := C.GoString(keysJson)

	var keys crypto.PublicKeyBundle
	if err := json.Unmarshal([]byte(keysStr), &keys); err != nil {
		return 1
	}

	session, err := crypto.NewSession(rid, keyMgr, &keys)
	if err != nil {
		return 1
	}

	sessions[rid] = session
	return 0
}

//export HasSession
func HasSession(recipientId *C.char) C.int {
	rid := C.GoString(recipientId)
	if _, exists := sessions[rid]; exists {
		return 1
	}
	return 0
}

//export EncryptMessage
func EncryptMessage(recipientId *C.char, plaintext *C.char) C.ByteArrayResult {
	rid := C.GoString(recipientId)
	pt := C.GoString(plaintext)

	session, exists := sessions[rid]
	if !exists {
		return C.ByteArrayResult{
			error:         1,
			error_message: C.CString("No session for recipient"),
		}
	}

	ciphertext, err := session.Encrypt([]byte(pt))
	if err != nil {
		return C.ByteArrayResult{
			error:         1,
			error_message: C.CString(err.Error()),
		}
	}

	// Copy to C memory
	cData := C.CBytes(ciphertext)
	return C.ByteArrayResult{
		data:   (*C.uint8_t)(cData),
		length: C.int(len(ciphertext)),
		error:  0,
	}
}

//export DecryptMessage
func DecryptMessage(senderId *C.char, ciphertext *C.uint8_t, length C.int) C.StringResult {
	sid := C.GoString(senderId)
	ct := C.GoBytes(unsafe.Pointer(ciphertext), length)

	session, exists := sessions[sid]
	if !exists {
		return C.StringResult{
			error:         1,
			error_message: C.CString("No session for sender"),
		}
	}

	plaintext, err := session.Decrypt(ct)
	if err != nil {
		return C.StringResult{
			error:         1,
			error_message: C.CString(err.Error()),
		}
	}

	return C.StringResult{
		data:  C.CString(string(plaintext)),
		error: 0,
	}
}

//export QueueMessage
func QueueMessage(messageJson *C.char) C.int {
	msgStr := C.GoString(messageJson)

	var msg sync.QueuedMessage
	if err := json.Unmarshal([]byte(msgStr), &msg); err != nil {
		return 1
	}

	queue.Enqueue(&msg)
	return 0
}

//export GetQueuedMessages
func GetQueuedMessages() *C.char {
	messages := queue.GetAll()
	jsonBytes, _ := json.Marshal(messages)
	return C.CString(string(jsonBytes))
}

//export ClearQueue
func ClearQueue(idsJson *C.char) C.int {
	idsStr := C.GoString(idsJson)

	var ids []string
	if err := json.Unmarshal([]byte(idsStr), &ids); err != nil {
		return 1
	}

	queue.Clear(ids)
	return 0
}

//export StoreMessage
func StoreMessage(messageJson *C.char) C.int {
	msgStr := C.GoString(messageJson)

	var msg message.Message
	if err := json.Unmarshal([]byte(msgStr), &msg); err != nil {
		return 1
	}

	if err := db.StoreMessage(&msg); err != nil {
		return 1
	}

	return 0
}

//export GetMessages
func GetMessages(conversationId *C.char, limit C.int, offset C.int) *C.char {
	convId := C.GoString(conversationId)

	messages, err := db.GetMessages(convId, int(limit), int(offset))
	if err != nil {
		return nil
	}

	jsonBytes, _ := json.Marshal(messages)
	return C.CString(string(jsonBytes))
}

// Free C memory (call from Flutter)
//export FreeCString
func FreeCString(s *C.char) {
	C.free(unsafe.Pointer(s))
}

//export FreeBytes
func FreeBytes(data *C.uint8_t) {
	C.free(unsafe.Pointer(data))
}

func main() {
	// Required for cgo shared library
}
