# Post-MVP Implementation Plan (Week 9+)

**Date:** February 12, 2026  
**Status:** 🚧 In Progress (P1–P3 Complete)
**Based on:** Skills audit (`flutter-expert`, `flutter-testing`, `flutter-animations`, `supabase-postgres-best-practices`, `find-skills`)

---

## Installed Skills Summary

| Skill | Source | Purpose |
|---|---|---|
| `find-skills` | vercel-labs/skills | Discover & install more skills |
| `flutter-expert` | jeffallan/claude-skills | Flutter 3+, Riverpod, GoRouter, performance |
| `flutter-testing` | madteacher/mad-agents-skills | Unit, widget, integration, & plugin testing |
| `flutter-animations` | madteacher/mad-agents-skills | Implicit, explicit, hero, staggered animations |
| `supabase-postgres-best-practices` | supabase/agent-skills | Postgres query optimization, RLS, indexing |

---

## Prioritized Next Steps

### ✅ Priority 1: Navigation Overhaul (GoRouter)

**Skill:** `flutter-expert` → `references/gorouter-navigation.md`

The app currently uses manual `Navigator.push()` throughout. Migrating to GoRouter will:
- Enable declarative routing with deep link support
- Centralize route definitions
- Support guards (auth redirects)
- Play well with the existing `AppLinks` deep link setup

**Tasks:**
- [x] Add `go_router` dependency
- [x] Define `GoRouter` configuration with auth guard
- [x] Replace all `Navigator.push` / `Navigator.pushReplacement` calls
- [x] Integrate with Supabase auth state for redirect-on-logout
- [x] Support deep link `/chat/:recipientId` from magic link callback
- [x] Custom page transitions (fade, slide-up, slide-right)

---

### ✅ Priority 2: State Management Migration (Riverpod Providers)

**Skill:** `flutter-expert` → `references/riverpod-state.md`

Currently services are accessed via `ref.read(messageServiceProvider)` but there's no reactive state management. Move to proper Riverpod `AsyncNotifier` / `StateNotifier` patterns:

**Tasks:**
- [x] Create `ConversationsNotifier` for reactive chat list
- [x] Create `MessagesNotifier` for reactive message list per chat
- [x] Create `UserProfileNotifier` for current user state
- [x] Create `AuthFormNotifier` for login form state
- [ ] Create `OnlineUsersNotifier` for presence tracking
- [x] Replace manual `setState()` calls with Riverpod `watch()`
- [ ] Use `Consumer` widgets instead of `ConsumerStatefulWidget` where possible

---

### ✅ Priority 3: Advanced Animations

**Skill:** `flutter-animations`

Add polish animations to key interactions:

**Tasks:**
- [x] **Hero transitions** — avatar from chat list → chat screen
- [x] **Staggered list animations** — conversations slide in on load
- [x] **Message send animation** — bubble slides up from input bar
- [x] **Typing indicator** — animated dots (implicit animation)
- [x] **Page transitions** — custom slide/fade between screens
- [x] **Pulse animation** — for notification badges / status indicators
- [ ] **Pull-to-refresh** with custom indicator

---

### 🚧 Priority 4: Comprehensive Test Suite

**Skill:** `flutter-testing`

Expanded from 50 → 85 tests with provider, router, and screen coverage:

**Tasks:**
- [x] **Provider unit tests** — ConversationsNotifier, MessagesNotifier, AuthFormNotifier
- [x] **State class tests** — ConversationsState, MessagesState, AuthFormState copyWith
- [x] **Router tests** — AppRoutes constants, route configuration verification
- [x] **Screen widget tests** — SplashScreen (rendering + navigation)
- [ ] **Mock Supabase client** for service-level tests (LoginScreen, SettingsScreen blocked by Supabase.instance)
- [ ] **Integration tests** with `IntegrationTestWidgetsFlutterBinding`
- [ ] **Mock platform channels** for Rust/Go FFI bridge tests
- [ ] **Performance tests** — message list scrolling, conversation list scrolling
- [ ] **CI integration** — GitHub Actions workflow for `flutter test --coverage`
- [ ] **Golden tests** — screenshot comparisons for visual regression

---

### 🟡 Priority 5: Database Performance Optimization

**Skill:** `supabase-postgres-best-practices`

Optimize queries and schema for production scale:

**Tasks:**
- [ ] **Analyze slow queries** with `pg_stat_statements`
- [ ] **Composite indexes** for common query patterns (sender_id + sent_at)
- [ ] **Connection pooling** — Configure PgBouncer settings
- [ ] **Vacuum/analyze schedules** for tables with high churn
- [ ] **Pagination** — Implement cursor-based pagination for messages
- [ ] **Database functions** — Move complex queries to stored procedures
- [ ] **Read replicas** — Evaluate for read-heavy workloads

---

### 🟢 Priority 6: Push Notifications (FCM/APNs)

**Tasks:**
- [ ] Add `firebase_messaging` dependency
- [ ] Configure FCM for Android
- [ ] Configure APNs for iOS
- [ ] Create Supabase edge function for sending notifications
- [ ] Handle notification tap → navigate to specific chat
- [ ] Background message handling

---

### 🟢 Priority 7: Production Deployment

**Tasks:**
- [ ] Android signing configuration (keystore)
- [ ] iOS provisioning profile & certificates
- [ ] App icons and splash screen assets
- [ ] Play Store listing preparation
- [ ] App Store listing preparation
- [ ] Privacy policy and terms of service
- [ ] GitHub Actions CI/CD pipeline

---

### 🟢 Priority 8: Advanced Features

**Tasks:**
- [ ] **Group chat** — Leverage existing `groups` + `group_members` schema
- [ ] **Media messages** — Photo/video with Supabase Storage
- [ ] **Voice messages** — Record and send audio
- [ ] **Contact sync** — Phone number hash matching
- [ ] **Disappearing messages** — Auto-delete timer
- [ ] **Message reactions** — Emoji reactions on messages
- [ ] **Message search** — Full-text search across conversations

---

## Recommended Immediate Actions

Based on the skills analysis, the **optimal order** for the next session is:

1. **GoRouter navigation** (reduces tech debt, enables deep linking properly)
2. **Riverpod state migration** (reduces `setState` overhead, improves reactivity)
3. **Hero + stagger animations** (quick visual wins with `flutter-animations` skill)
4. **Integration tests** (using `flutter-testing` skill's mock strategies for Supabase)

This order ensures each step builds on the previous one — proper routing enables proper testing, and reactive state enables proper animations.

---

## Architecture After Next Phase

```
flutter_app/
├── lib/
│   ├── config/
│   │   ├── app_theme.dart
│   │   ├── router.dart              ← NEW (GoRouter config)
│   │   └── supabase_config.dart
│   ├── core/
│   │   ├── bridge/
│   │   ├── di/
│   │   │   └── providers.dart       ← ENHANCED (Riverpod notifiers)
│   │   └── widgets/
│   │       ├── chat_shimmer.dart
│   │       ├── connectivity_banner.dart
│   │       └── error_state.dart
│   ├── features/
│   │   ├── auth/
│   │   │   ├── providers/           ← NEW (auth notifier)
│   │   │   └── screens/
│   │   ├── chat/
│   │   │   ├── providers/           ← NEW (messages, conversations)
│   │   │   └── screens/
│   │   ├── contacts/
│   │   └── settings/
│   └── services/                    ← UNCHANGED (data layer)
├── test/
│   ├── config/
│   ├── mocks/                       ← NEW (mock services)
│   ├── models/
│   ├── providers/                   ← NEW (notifier tests)
│   └── widgets/
└── integration_test/                ← NEW (E2E tests)
```
