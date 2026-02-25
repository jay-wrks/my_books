// ============================================================================
// MAIN.DART — App entry, Riverpod providers, GoRouter, theme
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/ws_service.dart';
import 'services/auth_service.dart';
import 'screens/all_screens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock portrait
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ProviderScope(child: AravindApp()));
}

class AravindApp extends ConsumerStatefulWidget {
  const AravindApp({super.key});
  @override
  ConsumerState<AravindApp> createState() => _AravindAppState();
}

class _AravindAppState extends ConsumerState<AravindApp> {
  @override
  void initState() {
    super.initState();
    // Initialize services
    ref.read(authProvider.notifier).init();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'Aravind',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF10B981),
          secondary: const Color(0xFF059669),
          surface: const Color(0xFF111111),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF111111),
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF111111),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF059669),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1F1F1F),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      home: authState.isLoading
          ? const SplashScreen()
          : authState.isLoggedIn
              ? const HomeScreen()
              : const LoginScreen(),
    );
  }
}
