import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/user_service.dart';

// ══════════════════════════════════════════════════════════════
// Auth Form State — manages login flow
// ══════════════════════════════════════════════════════════════

class AuthFormState {
  final bool loading;
  final bool otpSent;
  final String? error;

  const AuthFormState({
    this.loading = false,
    this.otpSent = false,
    this.error,
  });

  AuthFormState copyWith({
    bool? loading,
    bool? otpSent,
    String? error,
  }) {
    return AuthFormState(
      loading: loading ?? this.loading,
      otpSent: otpSent ?? this.otpSent,
      error: error,
    );
  }
}

class AuthFormNotifier extends StateNotifier<AuthFormState> {
  AuthFormNotifier() : super(const AuthFormState());

  /// Send magic link OTP to the given email
  Future<void> sendMagicLink(String email) async {
    if (email.isEmpty || !email.contains('@')) {
      state = state.copyWith(error: 'Please enter a valid email');
      return;
    }

    state = state.copyWith(loading: true, error: null);

    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        emailRedirectTo: 'merabriar://login-callback',
      );
      state = state.copyWith(otpSent: true, loading: false);
    } on AuthException catch (e) {
      state = state.copyWith(error: e.message, loading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), loading: false);
    }
  }

  /// Reset to allow using a different email
  void resetForm() {
    state = state.copyWith(otpSent: false, error: null);
  }

  /// Handle successful auth — create profile if needed, go online
  Future<void> handleSignIn(Session? session, String displayName) async {
    final user = session?.user;
    if (user != null) {
      final hasProfile = await userService.hasProfile();
      if (!hasProfile) {
        final name = displayName.isNotEmpty
            ? displayName
            : user.email?.split('@').first ?? 'User';
        await userService.createOrUpdateProfile(displayName: name);
      }
      await userService.setOnlineStatus(true);
    }
  }
}

final authFormProvider = StateNotifierProvider<AuthFormNotifier, AuthFormState>(
  (ref) => AuthFormNotifier(),
);
