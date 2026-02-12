import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/app_theme.dart';
import '../../../core/di/providers.dart' show DevMode;
import '../providers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _displayNameController = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    // Listen for auth state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      if (data.event == AuthChangeEvent.signedIn) {
        await ref.read(authFormProvider.notifier).handleSignIn(
              data.session,
              _displayNameController.text.trim(),
            );

        if (mounted) {
          context.go('/chats');
        }
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _displayNameController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _sendMagicLink() async {
    final email = _emailController.text.trim();
    await ref.read(authFormProvider.notifier).sendMagicLink(email);

    final authState = ref.read(authFormProvider);
    if (authState.otpSent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Check your email for the login link!'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authFormProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    AppTheme.darkCard,
                    AppTheme.darkSurface,
                  ]
                : [
                    AppTheme.brandGreen.withOpacity(0.06),
                    theme.colorScheme.surface,
                  ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ── Logo ──
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          gradient: AppGradients.accentGradient,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.brandGreen.withOpacity(0.3),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.eco,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Title ──
                      Text(
                        'Welcome Back',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        authState.otpSent
                            ? 'Check your email for the login link'
                            : 'Sign in to your secure messenger',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),

                      const SizedBox(height: 36),

                      // ── Email Field ──
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !authState.otpSent,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ── Display Name ──
                      TextField(
                        controller: _displayNameController,
                        enabled: !authState.otpSent,
                        decoration: const InputDecoration(
                          labelText: 'Display Name (optional)',
                          prefixIcon: Icon(Icons.person_outline),
                          helperText: 'Used for first-time sign in',
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Error ──
                      if (authState.error != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppTheme.danger.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: AppTheme.danger, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  authState.error!,
                                  style: const TextStyle(
                                      color: AppTheme.danger, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ── OTP Success ──
                      if (authState.otpSent) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppTheme.success.withOpacity(0.2)),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: AppTheme.success.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.mark_email_read,
                                    color: AppTheme.success, size: 30),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Magic link sent!',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Click the link in your email to sign in.\nThis page will update automatically.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            ref.read(authFormProvider.notifier).resetForm();
                          },
                          child: const Text('Use a different email'),
                        ),
                      ],

                      // ── Send Button ──
                      if (!authState.otpSent) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed:
                                authState.loading ? null : _sendMagicLink,
                            child: authState.loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Send Magic Link',
                                    style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      // ── Dev Mode Panel ──
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppTheme.warning.withOpacity(0.2)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.developer_mode,
                                    size: 16, color: Colors.orange.shade700),
                                const SizedBox(width: 6),
                                Text(
                                  'Development Mode',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _DevUserButton(
                                    name: 'Nilesh',
                                    color: AppTheme.info,
                                    icon: Icons.person,
                                    onTap: () {
                                      DevMode.useNilesh();
                                      context.go('/chats');
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _DevUserButton(
                                    name: 'Vaishali',
                                    color: const Color(0xFFE64980),
                                    icon: Icons.person,
                                    onTap: () {
                                      DevMode.useVaishali();
                                      context.go('/chats');
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Security Note ──
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.brandGreen.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              color: AppTheme.brandGreen.withOpacity(0.7),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Your messages are end-to-end encrypted. Only you and your contacts can read them.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DevUserButton extends StatelessWidget {
  final String name;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _DevUserButton({
    required this.name,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
