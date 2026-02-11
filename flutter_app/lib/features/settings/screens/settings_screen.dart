import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/app_theme.dart';
import '../../../core/di/providers.dart';
import '../../../services/user_service.dart';
import '../../auth/screens/login_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  UserProfile? _profile;
  bool _loading = true;
  final _nameController = TextEditingController();
  bool _editingName = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await userService.getCurrentProfile();
    if (mounted) {
      setState(() {
        _profile = profile;
        _nameController.text = profile?.displayName ?? '';
        _loading = false;
      });
    }
  }

  Future<void> _updateDisplayName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    setState(() => _editingName = false);
    await userService.createOrUpdateProfile(displayName: newName);
    await _loadProfile();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Display name updated'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out? Your messages will remain encrypted on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await userService.setOnlineStatus(false);
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Hero Header ──
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppGradients.primaryGradient,
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      // Avatar
                      Hero(
                        tag: 'profile-avatar',
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.2),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.5), width: 2),
                          ),
                          child: Center(
                            child: Text(
                              _profile?.displayName?.isNotEmpty == true
                                  ? _profile!.displayName![0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _profile?.displayName ?? 'Loading...',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              title: const Text('Settings'),
              centerTitle: true,
            ),
          ),

          // ── Body ──
          SliverToBoxAdapter(
            child: _loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Account Section ──
                        _SectionHeader(title: 'Account', icon: Icons.person),
                        const SizedBox(height: 8),
                        _SettingsCard(
                          children: [
                            _SettingsTile(
                              icon: Icons.badge_outlined,
                              title: 'Display Name',
                              subtitle: _profile?.displayName ?? 'Not set',
                              trailing: IconButton(
                                icon: Icon(
                                  _editingName ? Icons.check : Icons.edit,
                                  color: AppTheme.brandGreen,
                                  size: 20,
                                ),
                                onPressed: () {
                                  if (_editingName) {
                                    _updateDisplayName();
                                  } else {
                                    setState(() => _editingName = true);
                                  }
                                },
                              ),
                              custom: _editingName
                                  ? Padding(
                                      padding: const EdgeInsets.only(
                                          left: 56, right: 16, bottom: 12),
                                      child: TextField(
                                        controller: _nameController,
                                        autofocus: true,
                                        decoration: const InputDecoration(
                                          hintText: 'Enter display name',
                                          isDense: true,
                                        ),
                                        onSubmitted: (_) =>
                                            _updateDisplayName(),
                                      ),
                                    )
                                  : null,
                            ),
                            const Divider(indent: 56),
                            _SettingsTile(
                              icon: Icons.fingerprint,
                              title: 'User ID',
                              subtitle: _truncateId(
                                  userService.currentUserId ?? 'Unknown'),
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'ID: ${userService.currentUserId}'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // ── Security Section ──
                        _SectionHeader(title: 'Security', icon: Icons.shield),
                        const SizedBox(height: 8),
                        _SettingsCard(
                          children: [
                            _SettingsTile(
                              icon: Icons.lock_outline,
                              title: 'Encryption',
                              subtitle: 'AES-256-GCM end-to-end',
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.success.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Active',
                                  style: TextStyle(
                                    color: AppTheme.success,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const Divider(indent: 56),
                            _SettingsTile(
                              icon: Icons.vpn_key_outlined,
                              title: 'Key Management',
                              subtitle: 'View identity keys',
                              onTap: () => _showKeyInfo(context),
                            ),
                            const Divider(indent: 56),
                            _SettingsTile(
                              icon: Icons.verified_user_outlined,
                              title: 'Protocol',
                              subtitle: 'Signal-like Double Ratchet',
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // ── Core Engine Section ──
                        _SectionHeader(
                            title: 'Core Engine', icon: Icons.memory),
                        const SizedBox(height: 8),
                        _SettingsCard(
                          children: [
                            _SettingsTile(
                              icon: activeCore == CoreType.rust
                                  ? Icons.settings_suggest
                                  : Icons.code,
                              title: 'Active Core',
                              subtitle: activeCoreLog,
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (activeCore == CoreType.rust
                                          ? const Color(0xFFDEA584)
                                          : const Color(0xFF00ADD8))
                                      .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  activeCore == CoreType.rust ? 'Rust' : 'Go',
                                  style: TextStyle(
                                    color: activeCore == CoreType.rust
                                        ? const Color(0xFFDEA584)
                                        : const Color(0xFF00ADD8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const Divider(indent: 56),
                            _SettingsTile(
                              icon: Icons.storage_outlined,
                              title: 'Local Storage',
                              subtitle: 'SQLCipher encrypted database',
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // ── App Section ──
                        _SectionHeader(title: 'App', icon: Icons.info_outline),
                        const SizedBox(height: 8),
                        _SettingsCard(
                          children: [
                            _SettingsTile(
                              icon: Icons.palette_outlined,
                              title: 'Theme',
                              subtitle: 'System default',
                            ),
                            const Divider(indent: 56),
                            _SettingsTile(
                              icon: Icons.info_outline,
                              title: 'Version',
                              subtitle: '1.0.0 (Build 1)',
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // ── Sign Out ──
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _logout,
                            icon: const Icon(Icons.logout,
                                color: AppTheme.danger),
                            label: const Text(
                              'Sign Out',
                              style: TextStyle(color: AppTheme.danger),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.danger),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _truncateId(String id) {
    if (id.length <= 12) return id;
    return '${id.substring(0, 8)}...${id.substring(id.length - 4)}';
  }

  void _showKeyInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Identity Keys',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _KeyInfoRow(
              label: 'Identity Key',
              value: 'Ed25519 (256-bit)',
              icon: Icons.key,
            ),
            const SizedBox(height: 12),
            _KeyInfoRow(
              label: 'Signed Pre-Key',
              value: 'X25519 (256-bit)',
              icon: Icons.vpn_key,
            ),
            const SizedBox(height: 12),
            _KeyInfoRow(
              label: 'Session Keys',
              value: 'HKDF-derived AES-256',
              icon: Icons.enhanced_encryption,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.info, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Keys are generated locally and never leave your device.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Reusable Settings Components ──

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.brandGreen),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppTheme.brandGreen.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Widget? custom;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.custom,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading:
              Icon(icon, color: AppTheme.brandGreen.withOpacity(0.8), size: 22),
          title: Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          trailing: trailing ??
              (onTap != null
                  ? Icon(Icons.chevron_right,
                      color: Colors.grey.withOpacity(0.5))
                  : null),
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          dense: true,
        ),
        if (custom != null) custom!,
      ],
    );
  }
}

class _KeyInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _KeyInfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.brandGreen),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text(value,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        ),
      ],
    );
  }
}
