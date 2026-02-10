#!/bin/bash
# Build Rust and Go cores for Android
# Usage: bash build_android.sh [rust|go|all]
# Requires: Rust (with cargo-ndk), Go, Android NDK

set -e

# ============================================================
# Auto-detect Android NDK
# ============================================================
find_ndk() {
  local ndk_base=""

  # Check common NDK locations
  if [ -n "$ANDROID_NDK_HOME" ]; then
    ndk_base="$ANDROID_NDK_HOME"
  elif [ -d "$LOCALAPPDATA/Android/sdk/ndk" ]; then
    # Windows: pick latest version
    ndk_base="$LOCALAPPDATA/Android/sdk/ndk/$(ls "$LOCALAPPDATA/Android/sdk/ndk" | sort -V | tail -1)"
  elif [ -d "$HOME/Android/Sdk/ndk" ]; then
    # Linux
    ndk_base="$HOME/Android/Sdk/ndk/$(ls "$HOME/Android/Sdk/ndk" | sort -V | tail -1)"
  elif [ -d "$HOME/Library/Android/sdk/ndk" ]; then
    # macOS
    ndk_base="$HOME/Library/Android/sdk/ndk/$(ls "$HOME/Library/Android/sdk/ndk" | sort -V | tail -1)"
  else
    echo "❌ Android NDK not found! Set ANDROID_NDK_HOME environment variable."
    exit 1
  fi

  echo "$ndk_base"
}

NDK_HOME=$(find_ndk)
echo "📍 NDK: $NDK_HOME"

# Detect OS for toolchain path
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) TOOLCHAIN_OS="windows-x86_64" ;;
  Linux*)               TOOLCHAIN_OS="linux-x86_64" ;;
  Darwin*)              TOOLCHAIN_OS="darwin-x86_64" ;;
  *)                    echo "❌ Unsupported OS"; exit 1 ;;
esac

TOOLCHAIN="$NDK_HOME/toolchains/llvm/prebuilt/$TOOLCHAIN_OS"
OUTPUT_DIR="flutter_app/android/app/src/main/jniLibs"
BUILD_TARGET="${1:-all}"

export PATH="/c/Program Files/Go/bin:/c/msys64/mingw64/bin:$PATH"

# ============================================================
# Build Rust Core
# ============================================================
build_rust() {
  echo ""
  echo "🦀 Building Rust core for Android..."
  cd rust_core

  export ANDROID_NDK_HOME="$NDK_HOME"
  cargo ndk -t arm64-v8a -t armeabi-v7a -t x86_64 \
    -o "../$OUTPUT_DIR" build --release

  echo "   ✅ Rust core done"
  cd ..
}

# ============================================================
# Build Go Core
# ============================================================
build_go() {
  echo ""
  echo "🐹 Building Go core for Android..."
  cd go_core

  export CGO_ENABLED=1
  export GOOS=android

  # arm64-v8a
  echo "   📱 arm64-v8a..."
  export GOARCH=arm64
  export CC="$TOOLCHAIN/bin/aarch64-linux-android24-clang"
  export CXX="$TOOLCHAIN/bin/aarch64-linux-android24-clang++"
  mkdir -p "../$OUTPUT_DIR/arm64-v8a"
  go build -buildmode=c-shared -o "../$OUTPUT_DIR/arm64-v8a/libmerabriar_go.so" .

  # armeabi-v7a
  echo "   📱 armeabi-v7a..."
  export GOARCH=arm
  export GOARM=7
  export CC="$TOOLCHAIN/bin/armv7a-linux-androideabi24-clang"
  export CXX="$TOOLCHAIN/bin/armv7a-linux-androideabi24-clang++"
  mkdir -p "../$OUTPUT_DIR/armeabi-v7a"
  go build -buildmode=c-shared -o "../$OUTPUT_DIR/armeabi-v7a/libmerabriar_go.so" .

  # x86_64
  echo "   📱 x86_64..."
  export GOARCH=amd64
  unset GOARM
  export CC="$TOOLCHAIN/bin/x86_64-linux-android24-clang"
  export CXX="$TOOLCHAIN/bin/x86_64-linux-android24-clang++"
  mkdir -p "../$OUTPUT_DIR/x86_64"
  go build -buildmode=c-shared -o "../$OUTPUT_DIR/x86_64/libmerabriar_go.so" .

  echo "   ✅ Go core done"
  cd ..
}

# ============================================================
# Run builds
# ============================================================
echo "🔨 MeraBriar Android Build"
echo "=========================="

case "$BUILD_TARGET" in
  rust) build_rust ;;
  go)   build_go ;;
  all)  build_rust; build_go ;;
  *)    echo "Usage: bash build_android.sh [rust|go|all]"; exit 1 ;;
esac

echo ""
echo "🎉 Build complete! Libraries:"
find "$OUTPUT_DIR" -name "*.so" -exec ls -lh {} \;
