import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'core_interface.dart';

// FFI struct definitions matching Go's C structs
final class KeyBundleResult extends Struct {
  external Pointer<Utf8> identityPublicKey;
  external Pointer<Utf8> signedPrekey;
  external Pointer<Utf8> signature;
  @Int32()
  external int error;
  external Pointer<Utf8> errorMessage;
}

final class ByteArrayResult extends Struct {
  external Pointer<Uint8> data;
  @Int32()
  external int length;
  @Int32()
  external int error;
  external Pointer<Utf8> errorMessage;
}

final class StringResult extends Struct {
  external Pointer<Utf8> data;
  @Int32()
  external int error;
  external Pointer<Utf8> errorMessage;
}

// FFI type definitions for Go library
typedef InitCoreNative = Int32 Function(Pointer<Utf8>, Pointer<Utf8>);
typedef InitCoreDart = int Function(Pointer<Utf8>, Pointer<Utf8>);

typedef GenerateKeysNative = KeyBundleResult Function();
typedef GenerateKeysDart = KeyBundleResult Function();

typedef GetPublicKeyBundleNative = Pointer<Utf8> Function();
typedef GetPublicKeyBundleDart = Pointer<Utf8> Function();

typedef InitSessionNative = Int32 Function(Pointer<Utf8>, Pointer<Utf8>);
typedef InitSessionDart = int Function(Pointer<Utf8>, Pointer<Utf8>);

typedef HasSessionNative = Int32 Function(Pointer<Utf8>);
typedef HasSessionDart = int Function(Pointer<Utf8>);

typedef EncryptMessageNative = ByteArrayResult Function(
    Pointer<Utf8>, Pointer<Utf8>);
typedef EncryptMessageDart = ByteArrayResult Function(
    Pointer<Utf8>, Pointer<Utf8>);

typedef DecryptMessageNative = StringResult Function(
    Pointer<Utf8>, Pointer<Uint8>, Int32);
typedef DecryptMessageDart = StringResult Function(
    Pointer<Utf8>, Pointer<Uint8>, int);

typedef QueueMessageNative = Int32 Function(Pointer<Utf8>);
typedef QueueMessageDart = int Function(Pointer<Utf8>);

typedef GetQueuedMessagesNative = Pointer<Utf8> Function();
typedef GetQueuedMessagesDart = Pointer<Utf8> Function();

typedef ClearQueueNative = Int32 Function(Pointer<Utf8>);
typedef ClearQueueDart = int Function(Pointer<Utf8>);

typedef FreeCStringNative = Void Function(Pointer<Utf8>);
typedef FreeCStringDart = void Function(Pointer<Utf8>);

typedef FreeBytesNative = Void Function(Pointer<Uint8>);
typedef FreeBytesDart = void Function(Pointer<Uint8>);

/// Go implementation of MessengerCore
/// Uses dart:ffi to call Go shared library
class GoMessengerCore implements MessengerCore {
  late DynamicLibrary _goLib;
  bool _initialized = false;

  // FFI function pointers
  late InitCoreDart _initCore;
  late GenerateKeysDart _generateKeys;
  late GetPublicKeyBundleDart _getPublicKeyBundle;
  late InitSessionDart _initSession;
  late HasSessionDart _hasSession;
  late EncryptMessageDart _encryptMessage;
  late DecryptMessageDart _decryptMessage;
  late QueueMessageDart _queueMessage;
  late GetQueuedMessagesDart _getQueuedMessages;
  late ClearQueueDart _clearQueue;
  late FreeCStringDart _freeCString;
  late FreeBytesDart _freeBytes;

  GoMessengerCore() {
    _loadLibrary();
  }

  void _loadLibrary() {
    // Load the Go shared library
    if (Platform.isAndroid) {
      _goLib = DynamicLibrary.open('libmerabriar_go.so');
    } else if (Platform.isIOS) {
      _goLib = DynamicLibrary.process();
    } else if (Platform.isWindows) {
      _goLib = DynamicLibrary.open('merabriar_go.dll');
    } else if (Platform.isMacOS) {
      _goLib = DynamicLibrary.open('libmerabriar_go.dylib');
    } else if (Platform.isLinux) {
      _goLib = DynamicLibrary.open('libmerabriar_go.so');
    } else {
      throw UnsupportedError('Platform not supported');
    }

    // Look up functions
    _initCore = _goLib.lookupFunction<InitCoreNative, InitCoreDart>('InitCore');
    _generateKeys = _goLib.lookupFunction<GenerateKeysNative, GenerateKeysDart>(
      'GenerateIdentityKeys',
    );
    _getPublicKeyBundle =
        _goLib.lookupFunction<GetPublicKeyBundleNative, GetPublicKeyBundleDart>(
      'GetPublicKeyBundle',
    );
    _initSession = _goLib.lookupFunction<InitSessionNative, InitSessionDart>(
      'InitSession',
    );
    _hasSession = _goLib.lookupFunction<HasSessionNative, HasSessionDart>(
      'HasSession',
    );
    _encryptMessage =
        _goLib.lookupFunction<EncryptMessageNative, EncryptMessageDart>(
      'EncryptMessage',
    );
    _decryptMessage =
        _goLib.lookupFunction<DecryptMessageNative, DecryptMessageDart>(
      'DecryptMessage',
    );
    _queueMessage = _goLib.lookupFunction<QueueMessageNative, QueueMessageDart>(
      'QueueMessage',
    );
    _getQueuedMessages =
        _goLib.lookupFunction<GetQueuedMessagesNative, GetQueuedMessagesDart>(
      'GetQueuedMessages',
    );
    _clearQueue = _goLib.lookupFunction<ClearQueueNative, ClearQueueDart>(
      'ClearQueue',
    );
    _freeCString = _goLib.lookupFunction<FreeCStringNative, FreeCStringDart>(
      'FreeCString',
    );
    _freeBytes = _goLib.lookupFunction<FreeBytesNative, FreeBytesDart>(
      'FreeBytes',
    );
  }

  @override
  Future<void> init(String dbPath, String encryptionKey) async {
    final dbPathPtr = dbPath.toNativeUtf8();
    final keyPtr = encryptionKey.toNativeUtf8();

    try {
      final result = _initCore(dbPathPtr, keyPtr);
      if (result != 0) {
        throw Exception('Failed to initialize Go core');
      }
      _initialized = true;
      print('[GoCore] Initialized with db: $dbPath');
    } finally {
      calloc.free(dbPathPtr);
      calloc.free(keyPtr);
    }
  }

  @override
  Future<KeyBundle> generateIdentityKeys() async {
    if (!_initialized) throw Exception('Core not initialized');

    final result = _generateKeys();
    if (result.error != 0) {
      final errMsg = result.errorMessage.toDartString();
      throw Exception('Failed to generate keys: $errMsg');
    }

    try {
      return KeyBundle(
        identityPublicKey:
            base64Decode(result.identityPublicKey.toDartString()),
        signedPreKey: base64Decode(result.signedPrekey.toDartString()),
        signature: base64Decode(result.signature.toDartString()),
      );
    } finally {
      _freeCString(result.identityPublicKey);
      _freeCString(result.signedPrekey);
      _freeCString(result.signature);
    }
  }

  @override
  Future<PublicKeyBundle> getPublicKeyBundle() async {
    if (!_initialized) throw Exception('Core not initialized');

    final resultPtr = _getPublicKeyBundle();
    if (resultPtr == nullptr) {
      throw Exception('Failed to get public key bundle');
    }

    try {
      final jsonStr = resultPtr.toDartString();
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      return PublicKeyBundle(
        identityPublicKey: base64Decode(json['identity_public_key'] as String),
        signedPreKey: base64Decode(json['signed_prekey'] as String),
        signature: base64Decode(json['signature'] as String),
        oneTimePreKey: json['one_time_prekey'] != null
            ? base64Decode(json['one_time_prekey'] as String)
            : null,
      );
    } finally {
      _freeCString(resultPtr);
    }
  }

  @override
  Future<void> initSession(
    String recipientId,
    PublicKeyBundle recipientKeys,
  ) async {
    if (!_initialized) throw Exception('Core not initialized');

    final recipientPtr = recipientId.toNativeUtf8();
    final keysJson = jsonEncode({
      'identity_public_key': base64Encode(recipientKeys.identityPublicKey),
      'signed_prekey': base64Encode(recipientKeys.signedPreKey),
      'signature': base64Encode(recipientKeys.signature),
      if (recipientKeys.oneTimePreKey != null)
        'one_time_prekey': base64Encode(recipientKeys.oneTimePreKey!),
    });
    final keysPtr = keysJson.toNativeUtf8();

    try {
      final result = _initSession(recipientPtr, keysPtr);
      if (result != 0) {
        throw Exception('Failed to initialize session');
      }
      print('[GoCore] Session initialized with: $recipientId');
    } finally {
      calloc.free(recipientPtr);
      calloc.free(keysPtr);
    }
  }

  @override
  Future<bool> hasSession(String recipientId) async {
    if (!_initialized) throw Exception('Core not initialized');

    final recipientPtr = recipientId.toNativeUtf8();
    try {
      final result = _hasSession(recipientPtr);
      return result == 1;
    } finally {
      calloc.free(recipientPtr);
    }
  }

  @override
  Future<Uint8List> encryptMessage(String recipientId, String plaintext) async {
    if (!_initialized) throw Exception('Core not initialized');

    final recipientPtr = recipientId.toNativeUtf8();
    final plaintextPtr = plaintext.toNativeUtf8();

    try {
      final result = _encryptMessage(recipientPtr, plaintextPtr);
      if (result.error != 0) {
        final errMsg = result.errorMessage.toDartString();
        throw Exception('Encryption failed: $errMsg');
      }

      // Copy data to Dart
      final ciphertext = Uint8List(result.length);
      for (int i = 0; i < result.length; i++) {
        ciphertext[i] = result.data[i];
      }

      // Free C memory
      _freeBytes(result.data);
      return ciphertext;
    } finally {
      calloc.free(recipientPtr);
      calloc.free(plaintextPtr);
    }
  }

  @override
  Future<String> decryptMessage(String senderId, Uint8List ciphertext) async {
    if (!_initialized) throw Exception('Core not initialized');

    final senderPtr = senderId.toNativeUtf8();
    final ciphertextPtr = calloc<Uint8>(ciphertext.length);
    for (int i = 0; i < ciphertext.length; i++) {
      ciphertextPtr[i] = ciphertext[i];
    }

    try {
      final result =
          _decryptMessage(senderPtr, ciphertextPtr, ciphertext.length);
      if (result.error != 0) {
        final errMsg = result.errorMessage.toDartString();
        throw Exception('Decryption failed: $errMsg');
      }

      final plaintext = result.data.toDartString();
      _freeCString(result.data);
      return plaintext;
    } finally {
      calloc.free(senderPtr);
      calloc.free(ciphertextPtr);
    }
  }

  @override
  Future<void> queueMessage(QueuedMessage message) async {
    if (!_initialized) throw Exception('Core not initialized');

    final messageJson = jsonEncode({
      'id': message.id,
      'recipient_id': message.recipientId,
      'encrypted_content': base64Encode(message.encryptedContent),
      'created_at': message.createdAt,
    });
    final messagePtr = messageJson.toNativeUtf8();

    try {
      final result = _queueMessage(messagePtr);
      if (result != 0) {
        throw Exception('Failed to queue message');
      }
      print('[GoCore] Queued message: ${message.id}');
    } finally {
      calloc.free(messagePtr);
    }
  }

  @override
  Future<List<QueuedMessage>> getQueuedMessages() async {
    if (!_initialized) throw Exception('Core not initialized');

    final resultPtr = _getQueuedMessages();
    if (resultPtr == nullptr) {
      return [];
    }

    try {
      final jsonStr = resultPtr.toDartString();
      final list = jsonDecode(jsonStr) as List<dynamic>;

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return QueuedMessage(
          id: map['id'] as String,
          recipientId: map['recipient_id'] as String,
          encryptedContent: base64Decode(map['encrypted_content'] as String),
          createdAt: map['created_at'] as int,
        );
      }).toList();
    } finally {
      _freeCString(resultPtr);
    }
  }

  @override
  Future<void> clearQueue(List<String> messageIds) async {
    if (!_initialized) throw Exception('Core not initialized');

    final idsJson = jsonEncode(messageIds);
    final idsPtr = idsJson.toNativeUtf8();

    try {
      final result = _clearQueue(idsPtr);
      if (result != 0) {
        throw Exception('Failed to clear queue');
      }
      print('[GoCore] Cleared queue: $messageIds');
    } finally {
      calloc.free(idsPtr);
    }
  }
}
