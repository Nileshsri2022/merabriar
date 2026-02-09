# MeraBriar - Hybrid Messenger

A cross-platform encrypted messaging app inspired by Briar, built with Flutter + Rust/Go + Supabase.

## 🏗️ Architecture

```
merabriar/
├── 📱 flutter_app/          # Flutter UI (Cross-platform)
├── 🦀 rust_core/            # Rust core engine
├── 🐹 go_core/              # Go core engine (alternative)
├── 🔧 supabase/             # Cloud backend
└── 📄 docs/                 # Documentation
```

## 🎯 Features

### MVP (Phase 1)
- ✅ Phone signup with OTP (Supabase Auth)
- ✅ 1:1 E2E encrypted messaging
- ✅ Read receipts (sent/delivered/read)
- ✅ Online/offline status
- ✅ Offline message queue

### Future (Phase 2+)
- ⏳ Group chats
- ⏳ Voice messages
- ⏳ Image/file sharing
- ⏳ P2P transports (Bluetooth, WiFi, Tor)
- ⏳ Voice/Video calls

## 🔧 Dual Core

This project includes **both Rust and Go** implementations of the core engine.
You can build and test both to compare performance!

### Switching Cores
```dart
// flutter_app/lib/core/di/providers.dart
const CoreType activeCore = CoreType.rust;  // Change to CoreType.go
```

## 🚀 Quick Start

### Prerequisites
- Flutter SDK 3.16+
- Rust 1.75+
- Go 1.21+
- Supabase CLI

### Setup
```bash
# 1. Setup Flutter
cd flutter_app
flutter pub get

# 2. Setup Rust core
cd ../rust_core
cargo build

# 3. Setup Go core
cd ../go_core
go build

# 4. Run app
cd ../flutter_app
flutter run
```

## 📖 Documentation

- [Design Document](../docs/plans/2026-02-09-hybrid-messenger-design.md)
- [Implementation Plan](../docs/plans/2026-02-09-implementation-plan.md)
- [Architecture Comparison with Briar](../docs/plans/architecture-comparison-briar.md)

## 🏗️ Based on Briar

This project follows the same architectural patterns as [Briar](https://briarproject.org/):
- Layered architecture (Core + UI separation)
- Transport plugin system (Cloud, Tor, Bluetooth, LAN)
- E2E encryption
- Offline-first design

## 📄 License

MIT License
