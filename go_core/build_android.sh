#!/bin/bash
# Build Go core for Android architectures
# Requires: Go, Android NDK

set -e

export PATH="/c/Program Files/Go/bin:$PATH"

# Android NDK path
NDK_HOME="${ANDROID_NDK_HOME:-$LOCALAPPDATA/Android/sdk/ndk/28.2.13676358}"
TOOLCHAIN="$NDK_HOME/toolchains/llvm/prebuilt/windows-x86_64"

# Output directory
OUTPUT_DIR="../flutter_app/android/app/src/main/jniLibs"

echo "🔨 Building Go core for Android..."
echo "NDK: $NDK_HOME"

# Build for arm64-v8a (most modern phones)
echo ""
echo "📱 Building arm64-v8a..."
export CGO_ENABLED=1
export GOOS=android
export GOARCH=arm64
export CC="$TOOLCHAIN/bin/aarch64-linux-android24-clang"
export CXX="$TOOLCHAIN/bin/aarch64-linux-android24-clang++"
mkdir -p "$OUTPUT_DIR/arm64-v8a"
go build -buildmode=c-shared -o "$OUTPUT_DIR/arm64-v8a/libmerabriar_go.so" .
echo "   ✅ arm64-v8a done"

# Build for armeabi-v7a (older phones)
echo ""
echo "📱 Building armeabi-v7a..."
export GOARCH=arm
export GOARM=7
export CC="$TOOLCHAIN/bin/armv7a-linux-androideabi24-clang"
export CXX="$TOOLCHAIN/bin/armv7a-linux-androideabi24-clang++"
mkdir -p "$OUTPUT_DIR/armeabi-v7a"
go build -buildmode=c-shared -o "$OUTPUT_DIR/armeabi-v7a/libmerabriar_go.so" .
echo "   ✅ armeabi-v7a done"

# Build for x86_64 (emulators)
echo ""
echo "📱 Building x86_64..."
export GOARCH=amd64
unset GOARM
export CC="$TOOLCHAIN/bin/x86_64-linux-android24-clang"
export CXX="$TOOLCHAIN/bin/x86_64-linux-android24-clang++"
mkdir -p "$OUTPUT_DIR/x86_64"
go build -buildmode=c-shared -o "$OUTPUT_DIR/x86_64/libmerabriar_go.so" .
echo "   ✅ x86_64 done"

echo ""
echo "🎉 All Android builds complete!"
ls -la "$OUTPUT_DIR"/*/libmerabriar_go.so
