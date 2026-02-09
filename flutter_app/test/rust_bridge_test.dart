// Simple test to verify Rust FFI bindings work
// Run with: dart test/rust_bridge_test.dart

import 'dart:io';
import 'package:merabriar/src/rust/api.dart' as rust_api;
import 'package:merabriar/src/rust/frb_generated.dart';

void main() async {
  print('🧪 Testing Flutter-Rust Bridge...\n');

  try {
    // Initialize the Rust library
    print('1. Initializing RustLib...');
    await RustLib.init();
    print('   ✅ RustLib initialized!\n');

    // Test key generation
    print('2. Generating identity keys...');
    final keys = await rust_api.generateIdentityKeys();
    print('   ✅ Keys generated!');
    print('   - Identity key: ${keys.identityPublicKey.length} bytes');
    print('   - Signed prekey: ${keys.signedPrekey.length} bytes');
    print('   - Signature: ${keys.signature.length} bytes\n');

    // Test encryption
    print('3. Testing encryption...');
    final recipientId = 'test-recipient';

    // First we need a session - for now just test the API exists
    print(
        '   - hasSession check: ${await rust_api.hasSession(recipientId: recipientId)}');
    print('   ✅ API calls work!\n');

    print('🎉 All tests passed!');
  } catch (e, stack) {
    print('❌ Error: $e');
    print(stack);
    exit(1);
  }
}
