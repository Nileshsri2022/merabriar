// Package crypto provides cryptographic operations for MeraBriar.
// This mirrors Briar's bramble-api/crypto/CryptoComponent
package crypto

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"errors"
	"io"

	"golang.org/x/crypto/curve25519"
	"golang.org/x/crypto/hkdf"
)

// KeyBundle contains all identity keys (private + public)
type KeyBundle struct {
	IdentityPublicKey  []byte `json:"identity_public_key"`
	IdentityPrivateKey []byte `json:"-"` // Never export
	SignedPreKey       []byte `json:"signed_prekey"`
	SignedPreKeyPrivate []byte `json:"-"` // Never export
	Signature          []byte `json:"signature"`
}

// PublicKeyBundle contains only public keys (safe to share)
type PublicKeyBundle struct {
	IdentityPublicKey []byte `json:"identity_public_key"`
	SignedPreKey      []byte `json:"signed_prekey"`
	Signature         []byte `json:"signature"`
	OneTimePreKey     []byte `json:"one_time_prekey,omitempty"`
}

// KeyManager manages cryptographic keys
type KeyManager struct {
	identityKeys *KeyBundle
}

// NewKeyManager creates a new key manager
func NewKeyManager() *KeyManager {
	return &KeyManager{}
}

// GenerateIdentityKeys generates new identity keys
// This is called once during signup
func (km *KeyManager) GenerateIdentityKeys() (*KeyBundle, error) {
	// Generate Ed25519 identity key pair (for signing)
	publicKey, privateKey, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return nil, err
	}

	// Generate X25519 signed prekey (for key agreement)
	var preKeyPrivate [32]byte
	if _, err := io.ReadFull(rand.Reader, preKeyPrivate[:]); err != nil {
		return nil, err
	}

	var preKeyPublic [32]byte
	curve25519.ScalarBaseMult(&preKeyPublic, &preKeyPrivate)

	// Sign the signed prekey with identity key
	signature := ed25519.Sign(privateKey, preKeyPublic[:])

	bundle := &KeyBundle{
		IdentityPublicKey:   publicKey,
		IdentityPrivateKey:  privateKey,
		SignedPreKey:        preKeyPublic[:],
		SignedPreKeyPrivate: preKeyPrivate[:],
		Signature:           signature,
	}

	km.identityKeys = bundle
	return bundle, nil
}

// GetPublicKeyBundle returns the public key bundle (safe to share)
func (km *KeyManager) GetPublicKeyBundle() (*PublicKeyBundle, error) {
	if km.identityKeys == nil {
		return nil, errors.New("keys not initialized")
	}

	return &PublicKeyBundle{
		IdentityPublicKey: km.identityKeys.IdentityPublicKey,
		SignedPreKey:      km.identityKeys.SignedPreKey,
		Signature:         km.identityKeys.Signature,
	}, nil
}

// GetSignedPreKeyPrivate returns the private signed prekey (for session creation)
func (km *KeyManager) GetSignedPreKeyPrivate() ([]byte, error) {
	if km.identityKeys == nil {
		return nil, errors.New("keys not initialized")
	}
	return km.identityKeys.SignedPreKeyPrivate, nil
}

// Session represents an encrypted session with a contact
type Session struct {
	RecipientID   string
	rootKey       [32]byte
	sendChainKey  [32]byte
	recvChainKey  [32]byte
	sendCounter   uint32
	recvCounter   uint32
}

// NewSession creates a new session with a recipient
func NewSession(recipientID string, km *KeyManager, recipientKeys *PublicKeyBundle) (*Session, error) {
	// Get our signed prekey private
	ourPreKeyPrivate, err := km.GetSignedPreKeyPrivate()
	if err != nil {
		return nil, err
	}

	// Perform X25519 key agreement
	var ourPrivate [32]byte
	copy(ourPrivate[:], ourPreKeyPrivate)

	var theirPublic [32]byte
	copy(theirPublic[:], recipientKeys.SignedPreKey)

	sharedSecret, err := curve25519.X25519(ourPrivate[:], theirPublic[:])
	if err != nil {
		return nil, err
	}

	// Derive keys using HKDF
	hkdfReader := hkdf.New(sha256.New, sharedSecret, nil, []byte("merabriar_session"))

	var rootKey, sendChain, recvChain [32]byte
	io.ReadFull(hkdfReader, rootKey[:])
	io.ReadFull(hkdfReader, sendChain[:])
	io.ReadFull(hkdfReader, recvChain[:])

	return &Session{
		RecipientID:  recipientID,
		rootKey:      rootKey,
		sendChainKey: sendChain,
		recvChainKey: recvChain,
		sendCounter:  0,
		recvCounter:  0,
	}, nil
}

// Encrypt encrypts a message for the recipient
func (s *Session) Encrypt(plaintext []byte) ([]byte, error) {
	// Derive message key
	messageKey := s.deriveSendKey()

	// Create AES-GCM cipher
	block, err := aes.NewCipher(messageKey[:])
	if err != nil {
		return nil, err
	}

	aesGCM, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}

	// Generate random nonce
	nonce := make([]byte, aesGCM.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return nil, err
	}

	// Encrypt (nonce is prepended to ciphertext)
	ciphertext := aesGCM.Seal(nonce, nonce, plaintext, nil)

	return ciphertext, nil
}

// Decrypt decrypts a message from the sender
func (s *Session) Decrypt(ciphertext []byte) ([]byte, error) {
	// Derive message key
	messageKey := s.deriveRecvKey()

	// Create AES-GCM cipher
	block, err := aes.NewCipher(messageKey[:])
	if err != nil {
		return nil, err
	}

	aesGCM, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}

	nonceSize := aesGCM.NonceSize()
	if len(ciphertext) < nonceSize {
		return nil, errors.New("ciphertext too short")
	}

	// Extract nonce and ciphertext
	nonce, encrypted := ciphertext[:nonceSize], ciphertext[nonceSize:]

	// Decrypt
	plaintext, err := aesGCM.Open(nil, nonce, encrypted, nil)
	if err != nil {
		return nil, err
	}

	return plaintext, nil
}

// deriveSendKey derives the next message key for sending
func (s *Session) deriveSendKey() [32]byte {
	messageKey, newChainKey := s.deriveMessageKey(s.sendChainKey, s.sendCounter)
	s.sendChainKey = newChainKey
	s.sendCounter++
	return messageKey
}

// deriveRecvKey derives the next message key for receiving
func (s *Session) deriveRecvKey() [32]byte {
	messageKey, newChainKey := s.deriveMessageKey(s.recvChainKey, s.recvCounter)
	s.recvChainKey = newChainKey
	s.recvCounter++
	return messageKey
}

// deriveMessageKey derives a message key from chain key using HKDF
func (s *Session) deriveMessageKey(chainKey [32]byte, counter uint32) ([32]byte, [32]byte) {
	// Use counter as salt
	salt := []byte{byte(counter >> 24), byte(counter >> 16), byte(counter >> 8), byte(counter)}
	
	hkdfReader := hkdf.New(sha256.New, chainKey[:], salt, []byte("merabriar_message"))

	var messageKey, newChainKey [32]byte
	io.ReadFull(hkdfReader, messageKey[:])
	io.ReadFull(hkdfReader, newChainKey[:])

	return messageKey, newChainKey
}
