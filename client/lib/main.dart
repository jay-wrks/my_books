// ============================================================================
// MAIN.DART — App entry, Riverpod providers, theme
// Premium dark theme — matching Aravind web design system
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/auth_service.dart';
import 'services/server_config.dart';
import 'screens/all_screens.dart';

/// Global navigator key so AuthNotifier can pop all routes when account is blocked.
final navigatorKey = GlobalKey<NavigatorState>();

// ─── Design Tokens ──────────────────────────────────────────────────────────
class Tok {
  Tok._();
  // Surfaces (layered depth)
  static const bgRoot     = Color(0xFF09090B);
  static const bgPrimary  = Color(0xFF0C0C0E);
  static const bgSurface  = Color(0xFF141416);
  static const bgElevated = Color(0xFF1A1A1E);
  static const bgHover    = Color(0xFF1F1F24);
  static const bgActive   = Color(0xFF27272E);

  // Borders
  static const borderSubtle  = Color(0xFF1E1E24);
  static const borderDefault = Color(0xFF27272E);
  static const borderStrong  = Color(0xFF3F3F48);

  // Text
  static const textPrimary   = Color(0xFFFAFAFA);
  static const textSecondary = Color(0xFFA1A1AA);
  static const textTertiary  = Color(0xFF71717A);
  static const textMuted     = Color(0xFF52525B);

  // Accent (emerald)
  static const accent       = Color(0xFF10B981);
  static const accentHover  = Color(0xFF059669);
  static const accentSubtle = Color(0x1F10B981); // 12% opacity
  static const accentText   = Color(0xFF34D399);

  // Semantic
  static const danger       = Color(0xFFEF4444);
  static const dangerSubtle = Color(0x1FEF4444);
  static const warning      = Color(0xFFF59E0B);

  // Radius
  static const double rSm  = 6;
  static const double rMd  = 8;
  static const double rLg  = 12;
  static const double rXl  = 16;

  // Durations
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 300);
  static const curve = Curves.easeOutCubic;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Tok.bgRoot,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  await ServerConfig().load();
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
    ref.read(authProvider.notifier).init();
  }

  @override
  Widget build(BuildContext context) {
    final inter = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Aravind',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        textTheme: inter.apply(
          bodyColor: Tok.textPrimary,
          displayColor: Tok.textPrimary,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Tok.accent,
          onPrimary: Colors.white,
          secondary: Tok.accentHover,
          surface: Tok.bgSurface,
          onSurface: Tok.textPrimary,
          error: Tok.danger,
          outline: Tok.borderDefault,
        ),
        scaffoldBackgroundColor: Tok.bgRoot,
        appBarTheme: AppBarTheme(
          backgroundColor: Tok.bgRoot,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Tok.textPrimary,
            letterSpacing: -0.3,
          ),
          iconTheme: const IconThemeData(color: Tok.textSecondary, size: 22),
        ),
        cardTheme: CardThemeData(
          color: Tok.bgSurface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Tok.rLg),
            side: const BorderSide(color: Tok.borderSubtle, width: 1),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: Tok.borderSubtle,
          thickness: 1,
          space: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Tok.accent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Tok.bgActive,
            disabledForegroundColor: Tok.textMuted,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tok.rMd)),
            textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Tok.textPrimary,
            side: const BorderSide(color: Tok.borderDefault),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tok.rMd)),
            textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Tok.accentText,
            textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Tok.bgPrimary,
          hintStyle: GoogleFonts.inter(fontSize: 14, color: Tok.textMuted),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Tok.rMd),
            borderSide: const BorderSide(color: Tok.borderDefault),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Tok.rMd),
            borderSide: const BorderSide(color: Tok.borderDefault),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Tok.rMd),
            borderSide: const BorderSide(color: Tok.accent, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Tok.rMd),
            borderSide: const BorderSide(color: Tok.danger),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: Tok.bgElevated,
          contentTextStyle: GoogleFonts.inter(fontSize: 13, color: Tok.textPrimary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tok.rMd)),
          behavior: SnackBarBehavior.floating,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Tok.bgSurface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Tok.rXl),
            side: const BorderSide(color: Tok.borderSubtle),
          ),
          titleTextStyle: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Tok.textPrimary,
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Tok.bgSurface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Tok.accent,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      builder: (context, child) => ConnectionOverlay(child: child!),
      home: const _AuthGate(),
    );
  }
}

/// Smooth cross-fade between Splash → Login / Home screens.
/// This is a ConsumerWidget so MaterialApp's `home:` never changes,
/// keeping the Navigator stable and preventing rebuilds/flickers.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    final Widget child;
    final Key childKey;

    if (authState.isLoading) {
      child = const SplashScreen();
      childKey = const ValueKey('splash');
    } else if (authState.isBlocked) {
      child = const _BlockedScreen();
      childKey = const ValueKey('blocked');
    } else if (authState.isLoggedIn) {
      child = const HomeScreen();
      childKey = const ValueKey('home');
    } else {
      child = const LoginScreen();
      childKey = const ValueKey('login');
    }

    return AnimatedSwitcher(
      duration: Tok.slow,
      switchInCurve: Tok.curve,
      switchOutCurve: Tok.curve,
      child: KeyedSubtree(key: childKey, child: child),
    );
  }
}

/// Full-screen blocked account notice
class _BlockedScreen extends ConsumerWidget {
  const _BlockedScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: Tok.dangerSubtle,
                  borderRadius: BorderRadius.circular(Tok.rXl),
                  border: Border.all(color: Tok.danger.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.block_rounded, size: 36, color: Tok.danger),
              ),
              const SizedBox(height: 24),
              Text('Account Blocked',
                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: Tok.textPrimary)),
              const SizedBox(height: 10),
              Text(
                'Your account has been blocked by the administrator. Please contact support for assistance.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: Tok.textTertiary, height: 1.5),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton(
                  onPressed: () => ref.read(authProvider.notifier).clearBlocked(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Tok.borderSubtle),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tok.rMd)),
                  ),
                  child: Text('Back to Login', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Tok.textSecondary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
