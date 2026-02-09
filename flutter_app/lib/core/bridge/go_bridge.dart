import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'core_interface.dart';

// FFI type definitions for Go library
typedef InitCoreNative = Int32 Function(Pointer<Utf8>, Pointer<Utf8>);
typedef InitCoreDart = int Function(Pointer<Utf8>, Pointer<Utf8>);

typedef GenerateKeysNative = Pointer<Utf8> Function();
typedef GenerateKeysDart = Pointer<Utf8> Function();

typedef HasSessionNative = Int32 Function(Pointer<Utf8>);
typedef HasSessionDart = int Function(Pointer<Utf8>);

typedef FreeCStringNative = Void Function(Pointer<Utf8>);
typedef FreeCStringDart = void Function(Pointer<Utf8>);

/// Go implementation of MessengerCore
/// Uses dart:ffi to call Go shared library
class GoMessengerCore implements MessengerCore {
  late DynamicLibrary _goLib;
  bool _initialized = false;

  // FFI function pointers
  late InitCoreDart _initCore;
  late GenerateKeysDart _generateKeys;
  late HasSessionDart _hasSession;
  late FreeCStringDart _freeCString;

  GoMessengerCore() {
    _loadLibrary();
  }

  void _loadLibrary() {
    // Load the Go shared library
    if (Platform.isAndroid) {
      _goLib = DynamicLibrary.open('libmerabriar_core.so');
    } else if (Platform.isIOS) {
      _goLib = DynamicLibrary.process();
    } else if (Platform.isWindows) {
      _goLib = DynamicLibrary.open('merabriar_core.dll');
    } else if (Platform.isMacOS) {
      _goLib = DynamicLibrary.open('libmerabriar_core.dylib');
    } else if (Platform.isLinux) {
      _goLib = DynamicLibrary.open('libmerabriar_core.so');
    } else {
      throw UnsupportedError('Platform not supported');
    }

    // Look up functions
    _initCore = _goLib.lookupFunction<InitCoreNative, InitCoreDart>('InitCore');
    _generateKeys = _goLib.lookupFunction<GenerateKeysNative, GenerateKeysDart>(
      'GenerateIdentityKeys',
    );
    _hasSession = _goLib.lookupFunction<HasSessionNative, HasSessionDart>(
      'HasSession',
    );
    _freeCString = _goLib.lookupFunction<FreeCStringNative, FreeCStringDart>(
      'FreeCString',
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

    final resultPtr = _generateKeys();
    if (resultPtr == nullptr) {
      throw Exception('Failed to generate keys');
    }

    try {
      final jsonStr = resultPtr.toDartString();
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      return KeyBundle(
        identityPublicKey: base64Decode(json['identity_public_key'] as String),
        signedPreKey: base64Decode(json['signed_prekey'] as String),
        signature: base64Decode(json['signature'] as String),
      );
    } finally {
      _freeCString(resultPtr);
    }
  }

  @override
  Future<PublicKeyBundle> getPublicKeyBundle() async {
    if (!_initialized) throw Exception('Core not initialized');

    // TODO: Call Go function
    print('[GoCore] Getting public key bundle...');
    return PublicKeyBundle(
      identityPublicKey: Uint8List(32),
      signedPreKey: Uint8List(32),
      signature: Uint8List(64),
    );
  }

  @override
  Future<void> initSession(
    String recipientId,
    PublicKeyBundle recipientKeys,
  ) async {
    if (!_initialized) throw Exception('Core not initialized');

    // TODO: Call Go function
    print('[GoCore] Session initialized with: $recipientId');
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

    // TODO: Call Go function
    print('[GoCore] Encrypting message for: $recipientId');
    return Uint8List.fromList(plaintext.codeUnits);
  }

  @override
  Future<String> decryptMessage(String senderId, Uint8List ciphertext) async {
    if (!_initialized) throw Exception('Core not initialized');

    // TODO: Call Go function
    print('[GoCore] Decrypting message from: $senderId');
    return String.fromCharCodes(ciphertext);
  }

  @override
  Future<void> queueMessage(QueuedMessage message) async {
    if (!_initialized) throw Exception('Core not initialized');

    // TODO: Call Go function
    print('[GoCore] Queuing message: ${message.id}');
  }

  @override
  Future<List<QueuedMessage>> getQueuedMessages() async {
    if (!_initialized) throw Exception('Core not initialized');

    // TODO: Call Go function
    print('[GoCore] Getting queued messages...');
    return [];
  }

  @override
  Future<void> clearQueue(List<String> messageIds) async {
    if (!_initialized) throw Exception('Core not initialized');

    // TODO: Call Go function
    print('[GoCore] Clearing queue: $messageIds');
  }
}
