import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_theme.dart';
import 'config/router.dart';
import 'config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase with deep link handling
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: MeraBriarApp()));
}

class MeraBriarApp extends StatefulWidget {
  const MeraBriarApp({super.key});

  @override
  State<MeraBriarApp> createState() => _MeraBriarAppState();
}

class _MeraBriarAppState extends State<MeraBriarApp> {
  late AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Handle links when app is already running
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });

    // Check initial link (app was opened via link)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Error getting initial link: $e');
    }
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('Deep link received: $uri');
    // Supabase handles the auth callback automatically.
    // For chat deep links: merabriar://chat/<recipientId>
    if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'chat') {
      final recipientId =
          uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;
      if (recipientId != null) {
        appRouter.go('/chats/$recipientId');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MeraBriar',
      debugShowCheckedModeBanner: false,

      // ── Premium Theme ──
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,

      // ── GoRouter ──
      routerConfig: appRouter,
    );
  }
}
