import 'package:flutter_test/flutter_test.dart';
import 'package:merabriar/features/auth/providers/auth_providers.dart';

void main() {
  // ══════════════════════════════════════════════════════════════
  // AuthFormState tests
  // ══════════════════════════════════════════════════════════════

  group('AuthFormState', () {
    test('default state has loading false, otpSent false', () {
      const state = AuthFormState();
      expect(state.loading, isFalse);
      expect(state.otpSent, isFalse);
      expect(state.error, isNull);
    });

    test('copyWith sets loading', () {
      const state = AuthFormState();
      final updated = state.copyWith(loading: true);
      expect(updated.loading, isTrue);
      expect(updated.otpSent, isFalse);
    });

    test('copyWith sets otpSent', () {
      const state = AuthFormState();
      final updated = state.copyWith(otpSent: true);
      expect(updated.otpSent, isTrue);
      expect(updated.loading, isFalse);
    });

    test('copyWith sets error', () {
      const state = AuthFormState();
      final updated = state.copyWith(error: 'Invalid email');
      expect(updated.error, 'Invalid email');
    });

    test('copyWith clears error when not specified', () {
      final state = const AuthFormState().copyWith(error: 'Error');
      expect(state.error, 'Error');

      final cleared = state.copyWith(loading: true);
      // error is nullable and defaults to null in copyWith
      expect(cleared.error, isNull);
    });

    test('copyWith preserves existing values when only changing one', () {
      final state = const AuthFormState().copyWith(
        loading: true,
        otpSent: true,
        error: 'some error',
      );

      final updated = state.copyWith(loading: false);
      expect(updated.loading, isFalse);
      expect(updated.otpSent, isTrue);
      // error is reset to null by copyWith design
    });
  });

  // ══════════════════════════════════════════════════════════════
  // AuthFormNotifier — validation tests (no Supabase needed)
  // ══════════════════════════════════════════════════════════════

  group('AuthFormNotifier', () {
    test('sendMagicLink with empty email sets error', () async {
      final notifier = AuthFormNotifier();

      await notifier.sendMagicLink('');

      expect(notifier.state.error, 'Please enter a valid email');
      expect(notifier.state.loading, isFalse);
      expect(notifier.state.otpSent, isFalse);
    });

    test('sendMagicLink with invalid email (no @) sets error', () async {
      final notifier = AuthFormNotifier();

      await notifier.sendMagicLink('notanemail');

      expect(notifier.state.error, 'Please enter a valid email');
      expect(notifier.state.loading, isFalse);
    });

    test('resetForm clears otpSent and error', () {
      final notifier = AuthFormNotifier();

      // Simulate a state with otpSent and error
      notifier.state = const AuthFormState(
        otpSent: true,
        error: 'Some error',
      );

      notifier.resetForm();

      expect(notifier.state.otpSent, isFalse);
      expect(notifier.state.error, isNull);
    });

    test('resetForm preserves loading state', () {
      final notifier = AuthFormNotifier();
      notifier.state = const AuthFormState(
        loading: true,
        otpSent: true,
      );

      notifier.resetForm();

      // loading is not reset by resetForm — it only clears otpSent/error
      // (loading is preserved via copyWith)
      expect(notifier.state.loading, isTrue);
      expect(notifier.state.otpSent, isFalse);
    });
  });
}
