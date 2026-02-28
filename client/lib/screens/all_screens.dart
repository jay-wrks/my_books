// ============================================================================
// ALL SCREENS — Production-level UI
//
// Screens: Splash, Login, Register, Home, PdfList, PdfViewer,
//          SubscribeWall, Profile, Search
//
// Design: Matches Aravind web design system — Linear/Vercel-inspired dark theme
// Features: Stagger animations, shimmer loading, smooth transitions,
//           layered surfaces, subtle borders, micro-interactions
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:shimmer/shimmer.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
// ignore: implementation_imports
import 'package:syncfusion_flutter_pdfviewer/src/annotation/text_markup.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart'; // Tok design tokens
import '../services/ws_service.dart';
import '../services/auth_service.dart';
import '../services/pdf_service.dart';

// ===================== CHANGE THIS =====================
const String _serverDomain = 'http://192.168.29.81:3000';
// =======================================================

final _ws = WsService();
final _pdf = PdfService();

// ─── Shared Widgets ─────────────────────────────────────────────────────────

/// Shimmer skeleton placeholder for loading states
class _Skeleton extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  const _Skeleton({this.width = double.infinity, this.height = 16, this.radius = 6});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Tok.bgElevated,
      highlightColor: Tok.bgHover,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Tok.bgElevated,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Staggered fade+slide animation for list items
class _StaggerItem extends StatelessWidget {
  final int index;
  final Animation<double> animation;
  final Widget child;
  const _StaggerItem({required this.index, required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: const Interval(0.0, 1.0, curve: Curves.easeOut)),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }
}

/// Surface card with subtle border — matching web .card
class _SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  const _SurfaceCard({required this.child, this.padding, this.margin, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Tok.bgSurface,
        borderRadius: BorderRadius.circular(Tok.rLg),
        border: Border.all(color: Tok.borderSubtle, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(Tok.rLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(Tok.rLg),
          onTap: onTap,
          splashColor: Tok.accentSubtle,
          highlightColor: Tok.bgHover.withValues(alpha: 0.5),
          child: padding != null ? Padding(padding: padding!, child: child) : child,
        ),
      ),
    );
  }
}

/// Empty state placeholder
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const _EmptyState({required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: Tok.bgElevated,
                borderRadius: BorderRadius.circular(Tok.rXl),
                border: Border.all(color: Tok.borderSubtle),
              ),
              child: Icon(icon, size: 28, color: Tok.textMuted),
            ),
            const SizedBox(height: 20),
            Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: Tok.textSecondary)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, style: GoogleFonts.inter(fontSize: 13, color: Tok.textTertiary), textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Connection Overlay ─────────────────────────────────────────────────────
// Covers the entire app when disconnected.
// • No internet  → "No Internet Connection" screen
// • Internet ok but WS down → "Server Under Maintenance" screen
// Applied via MaterialApp.builder so it blocks all routes.

enum _ConnStatus { connected, noInternet, maintenance }

class ConnectionOverlay extends StatefulWidget {
  final Widget child;
  const ConnectionOverlay({super.key, required this.child});
  @override
  State<ConnectionOverlay> createState() => _ConnectionOverlayState();
}

class _ConnectionOverlayState extends State<ConnectionOverlay> with SingleTickerProviderStateMixin {
  _ConnStatus _status = _ConnStatus.connected;
  _ConnStatus _displayStatus = _ConnStatus.connected; // what's actually rendered
  late final StreamSubscription _wsSub;
  late final StreamSubscription<List<ConnectivityResult>> _netSub;
  bool _hasInternet = true;
  bool _wsConnected = true;
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: Tok.slow);
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Tok.curve);

    _wsConnected = _ws.isConnected;
    _wsSub = _ws.connectionState.listen((c) {
      _wsConnected = c;
      _evaluate();
    });

    // Initial connectivity check
    Connectivity().checkConnectivity().then((results) {
      _hasInternet = !results.contains(ConnectivityResult.none);
      _evaluate();
    });

    _netSub = Connectivity().onConnectivityChanged.listen((results) {
      _hasInternet = !results.contains(ConnectivityResult.none);
      _evaluate();
      // When internet comes back, nudge WS to reconnect faster
      if (_hasInternet && !_wsConnected) {
        _ws.connect();
      }
    });
  }

  void _evaluate() {
    // Don't show any overlay until WS has connected at least once.
    // During startup (splash/login), the app handles errors via its own UI.
    // The overlay only makes sense once the user is in the app and connection drops.
    if (!_ws.hasEverConnected) return;

    if (_wsConnected) {
      _status = _ConnStatus.connected;
    } else if (!_hasInternet) {
      _status = _ConnStatus.noInternet;
    } else {
      _status = _ConnStatus.maintenance;
    }

    // Debounce: Only apply the change after it's stable for a moment.
    // This prevents flicker from rapid connected↔disconnected toggling.
    _debounceTimer?.cancel();

    if (_status == _ConnStatus.connected && _displayStatus != _ConnStatus.connected) {
      // Becoming connected → wait 800ms to confirm it's real
      _debounceTimer = Timer(const Duration(milliseconds: 800), () {
        if (_status == _ConnStatus.connected && mounted) {
          _displayStatus = _ConnStatus.connected;
          setState(() {});
          _animCtrl.reverse();
        }
      });
    } else if (_status != _ConnStatus.connected && _displayStatus == _ConnStatus.connected) {
      // Becoming disconnected → show immediately (no delay)
      _displayStatus = _status;
      if (mounted) {
        setState(() {});
        _animCtrl.forward();
      }
    } else if (_status != _displayStatus) {
      // Switching between noInternet ↔ maintenance
      if (mounted) {
        _displayStatus = _status;
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _wsSub.cancel();
    _netSub.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_displayStatus != _ConnStatus.connected)
          FadeTransition(
            opacity: _fadeAnim,
            child: _displayStatus == _ConnStatus.noInternet
                ? const _NoInternetScreen()
                : const _MaintenanceScreen(),
          ),
      ],
    );
  }
}

// ─── No Internet Screen ─────────────────────────────────────────────────────
class _NoInternetScreen extends StatelessWidget {
  const _NoInternetScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tok.bgRoot,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  color: Tok.dangerSubtle,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Tok.danger.withValues(alpha: 0.2)),
                ),
                child: const Icon(Icons.wifi_off_rounded, size: 40, color: Tok.danger),
              ),
              const SizedBox(height: 28),
              Text(
                'No Internet Connection',
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: Tok.textPrimary, letterSpacing: -0.3),
              ),
              const SizedBox(height: 10),
              Text(
                'Please check your Wi-Fi or mobile data and try again.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: Tok.textTertiary, height: 1.5),
              ),
              const SizedBox(height: 32),
              _PulsingDot(color: Tok.danger),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Server Under Maintenance Screen ────────────────────────────────────────
class _MaintenanceScreen extends StatelessWidget {
  const _MaintenanceScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tok.bgRoot,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  color: Color(0x1FF59E0B), // warning subtle
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Tok.warning.withValues(alpha: 0.2)),
                ),
                child: const Icon(Icons.construction_rounded, size: 40, color: Tok.warning),
              ),
              const SizedBox(height: 28),
              Text(
                'Server Under Maintenance',
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: Tok.textPrimary, letterSpacing: -0.3),
              ),
              const SizedBox(height: 10),
              Text(
                'We\'re performing scheduled maintenance.\nPlease check back shortly.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: Tok.textTertiary, height: 1.5),
              ),
              const SizedBox(height: 32),
              _PulsingDot(color: Tok.warning),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small pulsing dot indicator for status screens
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 8, height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

// ============================================================================
// SPLASH SCREEN — Animated brand reveal
// ============================================================================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scale = Tween(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Opacity(
            opacity: _fade.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Brand mark — matching web .brand-mark
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: Tok.accentSubtle,
                      borderRadius: BorderRadius.circular(Tok.rXl),
                    ),
                    child: const Icon(Icons.auto_stories_rounded, size: 36, color: Tok.accent),
                  ),
                  const SizedBox(height: 24),
                  Text('Aravind', style: GoogleFonts.inter(
                    fontSize: 28, fontWeight: FontWeight.w700, color: Tok.textPrimary, letterSpacing: -0.5,
                  )),
                  const SizedBox(height: 6),
                  Text('Study Materials', style: GoogleFonts.inter(fontSize: 14, color: Tok.textTertiary)),
                  const SizedBox(height: 40),
                  const SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Tok.accent),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// LOGIN SCREEN — Clean, centered form matching web login page
// ============================================================================

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() { _animCtrl.dispose(); _emailC.dispose(); _passC.dispose(); super.dispose(); }

  Future<void> _login() async {
    if (_emailC.text.isEmpty || _passC.text.isEmpty) {
      setState(() => _error = 'Please fill all fields');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authProvider.notifier).login(
        email: _emailC.text.trim(),
        password: _passC.text,
      );
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('ACCOUNT_BLOCKED')) {
        // AuthGate will show the blocked screen
        ref.read(authProvider.notifier).clearBlocked();
        setState(() => _error = 'Your account has been blocked. Contact support.');
      } else {
        setState(() => _error = msg.replaceAll('WsError: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Brand mark
                    Center(
                      child: Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          color: Tok.accentSubtle,
                          borderRadius: BorderRadius.circular(Tok.rLg),
                        ),
                        child: const Icon(Icons.auto_stories_rounded, size: 28, color: Tok.accent),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Aravind', textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                    const SizedBox(height: 4),
                    Text('Sign in to your account', textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 14, color: Tok.textTertiary)),
                    const SizedBox(height: 36),

                    // Email label + input
                    Text('Email address', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Tok.textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _emailC,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      style: GoogleFonts.inter(fontSize: 14),
                      decoration: const InputDecoration(hintText: 'you@example.com'),
                    ),
                    const SizedBox(height: 16),

                    // Password label + input
                    Text('Password', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Tok.textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passC,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _login(),
                      style: GoogleFonts.inter(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Enter your password',
                        suffixIcon: GestureDetector(
                          onTap: () => setState(() => _obscure = !_obscure),
                          child: Icon(
                            _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 20, color: Tok.textMuted,
                          ),
                        ),
                      ),
                    ),

                    // Error message
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Tok.dangerSubtle,
                          borderRadius: BorderRadius.circular(Tok.rMd),
                          border: Border.all(color: Tok.danger.withValues(alpha: 0.3)),
                        ),
                        child: Text(_error!, style: GoogleFonts.inter(fontSize: 13, color: Tok.danger), textAlign: TextAlign.center),
                      ),
                    ],

                    const SizedBox(height: 24),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        child: _loading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text('Sign in', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Don't have an account? ", style: GoogleFonts.inter(fontSize: 13, color: Tok.textTertiary)),
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                          child: Text('Register', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Tok.accentText)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// REGISTER SCREEN
// ============================================================================

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameC = TextEditingController();
  final _emailC = TextEditingController();
  final _phoneC = TextEditingController();
  final _passC = TextEditingController();
  final _confirmC = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _register() async {
    if (_nameC.text.isEmpty || _emailC.text.isEmpty || _passC.text.isEmpty) {
      setState(() => _error = 'Please fill all required fields');
      return;
    }
    if (_passC.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    if (_passC.text != _confirmC.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authProvider.notifier).register(
        name: _nameC.text.trim(),
        email: _emailC.text.trim(),
        password: _passC.text,
        phone: _phoneC.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _field(String label, TextEditingController ctrl, {TextInputType? keyboard, bool obscure = false, String? hint, bool required_ = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label${required_ ? ' *' : ''}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Tok.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboard,
          obscureText: obscure,
          style: GoogleFonts.inter(fontSize: 14),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field('Full Name', _nameC, hint: 'John Doe', required_: true),
            const SizedBox(height: 16),
            _field('Email', _emailC, hint: 'you@example.com', keyboard: TextInputType.emailAddress, required_: true),
            const SizedBox(height: 16),
            _field('Phone', _phoneC, hint: '+91 xxxxx xxxxx', keyboard: TextInputType.phone),
            const SizedBox(height: 16),
            _field('Password', _passC, hint: 'Min 6 characters', obscure: true, required_: true),
            const SizedBox(height: 16),
            _field('Confirm Password', _confirmC, hint: 'Re-enter password', obscure: true, required_: true),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Tok.dangerSubtle,
                  borderRadius: BorderRadius.circular(Tok.rMd),
                  border: Border.all(color: Tok.danger.withValues(alpha: 0.3)),
                ),
                child: Text(_error!, style: GoogleFonts.inter(fontSize: 13, color: Tok.danger), textAlign: TextAlign.center),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Create Account', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() { _nameC.dispose(); _emailC.dispose(); _phoneC.dispose(); _passC.dispose(); _confirmC.dispose(); super.dispose(); }
}

// ============================================================================
// HOME SCREEN — Two tabs: By Class, By Subject
// ============================================================================

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with TickerProviderStateMixin {
  List<dynamic> _subjects = [];
  List<dynamic> _classes = [];
  bool _initialLoading = true; // only true until first successful load

  // Stagger animation controllers
  late AnimationController _listAnimCtrl;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        _playStagger();
      }
    });
    _listAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _load();
  }

  @override
  void dispose() {
    _listAnimCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  void _playStagger() {
    _listAnimCtrl.reset();
    _listAnimCtrl.forward();
  }

  Future<void> _load() async {
    // Don't set loading on refresh — keep existing data visible
    try {
      final results = await Future.wait([
        _ws.send('getSubjects', {}),
        _ws.send('getClasses', {}),
      ]);
      _subjects = results[0]['subjects'] as List? ?? [];
      _classes = results[1]['classes'] as List? ?? [];
    } catch (e) {
      debugPrint('[HOME] Load failed: $e');
    }
    if (mounted) {
      setState(() => _initialLoading = false);
      _playStagger();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Column(
        children: [
          // ─── Custom App Bar ──────────────────────────────────
          Container(
            padding: EdgeInsets.only(top: topPad + 12, left: 20, right: 12, bottom: 0),
            color: Tok.bgRoot,
            child: Column(
              children: [
                Row(
                  children: [
                    // Brand
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Tok.accentSubtle,
                        borderRadius: BorderRadius.circular(Tok.rMd),
                      ),
                      child: const Icon(Icons.auto_stories_rounded, size: 18, color: Tok.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Aravind', style: GoogleFonts.inter(
                            fontSize: 18, fontWeight: FontWeight.w700, color: Tok.textPrimary, letterSpacing: -0.3,
                          )),
                        ],
                      ),
                    ),

                    // Subscription badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: auth.hasActiveSubscription ? Tok.accentSubtle : Tok.dangerSubtle,
                        borderRadius: BorderRadius.circular(Tok.rSm),
                        border: Border.all(
                          color: auth.hasActiveSubscription ? Tok.accent.withValues(alpha: 0.3) : Tok.danger.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        auth.hasActiveSubscription ? 'PRO' : 'FREE',
                        style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5,
                          color: auth.hasActiveSubscription ? Tok.accent : Tok.danger,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Search
                    _AppBarAction(
                      icon: Icons.search_rounded,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
                    ),

                    // Profile
                    _AppBarAction(
                      icon: Icons.person_outline_rounded,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ─── Tab Bar ─────────────────────────────────────
                Container(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Tok.borderSubtle, width: 1)),
                  ),
                  child: TabBar(
                    controller: _tabCtrl,
                    indicatorColor: Tok.accent,
                    indicatorWeight: 2,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Tok.textPrimary,
                    unselectedLabelColor: Tok.textMuted,
                    labelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                    unselectedLabelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                    dividerHeight: 0,
                    splashFactory: InkSparkle.splashFactory,
                    tabs: const [
                      Tab(text: 'By Class'),
                      Tab(text: 'By Subject'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── Content ─────────────────────────────────────────
          Expanded(
            child: _initialLoading
                ? _buildShimmerList()
                : RefreshIndicator(
                    color: Tok.accent,
                    backgroundColor: Tok.bgSurface,
                    onRefresh: () async {
                      await _load();
                      ref.read(authProvider.notifier).refreshSubscription();
                    },
                    child: TabBarView(
                      controller: _tabCtrl,
                      children: [
                        _buildClassView(),
                        _buildSubjectView(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 8,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Tok.bgSurface,
            borderRadius: BorderRadius.circular(Tok.rLg),
            border: Border.all(color: Tok.borderSubtle),
          ),
          child: const Row(
            children: [
              _Skeleton(width: 44, height: 44, radius: 10),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Skeleton(width: 120, height: 14),
                    SizedBox(height: 8),
                    _Skeleton(width: 80, height: 11),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassView() {
    if (_classes.isEmpty) return const _EmptyState(icon: Icons.school_outlined, title: 'No classes available', subtitle: 'Pull down to refresh');
    final classLevels = _classes.map<int>((c) => c['class_level'] as int).toList()..sort();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: classLevels.length,
      itemBuilder: (context, i) {
        final classLevel = classLevels[i];
        final classData = _classes.firstWhere((c) => c['class_level'] == classLevel, orElse: () => null);
        final count = classData?['pdf_count'] ?? 0;
        final delay = (i * 0.08).clamp(0.0, 0.6);
        return _StaggerItem(
          index: i,
          animation: CurvedAnimation(
            parent: _listAnimCtrl,
            curve: Interval(delay, (delay + 0.4).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
          ),
          child: _SurfaceCard(
            margin: const EdgeInsets.only(bottom: 10),
            onTap: count > 0 ? () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => PdfListScreen(classLevel: classLevel, subjects: _subjects),
            )) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Class number badge
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: Tok.accentSubtle,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text('$classLevel', style: GoogleFonts.inter(
                        fontSize: 18, fontWeight: FontWeight.w700, color: Tok.accent,
                      )),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Class $classLevel', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: Tok.textPrimary)),
                        const SizedBox(height: 3),
                        Text('$count PDFs available', style: GoogleFonts.inter(fontSize: 13, color: Tok.textTertiary)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: count > 0 ? Tok.textMuted : Tok.borderDefault, size: 22),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubjectView() {
    if (_subjects.isEmpty) return const _EmptyState(icon: Icons.book_outlined, title: 'No subjects available', subtitle: 'Pull down to refresh');
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 1.3, crossAxisSpacing: 10, mainAxisSpacing: 10,
      ),
      itemCount: _subjects.length,
      itemBuilder: (context, i) {
        final s = _subjects[i];
        final delay = (i * 0.06).clamp(0.0, 0.6);
        return _StaggerItem(
          index: i,
          animation: CurvedAnimation(
            parent: _listAnimCtrl,
            curve: Interval(delay, (delay + 0.4).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
          ),
          child: _SurfaceCard(
            margin: EdgeInsets.zero,
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => PdfListScreen(subjectId: s['id'], subjectName: s['name']),
            )),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: Tok.accentSubtle,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_getSubjectIcon(s['icon_name'] ?? ''), size: 22, color: Tok.accent),
                ),
                const SizedBox(height: 12),
                Text(
                  s['name'] ?? '',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: Tok.textPrimary),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// App bar icon button
class _AppBarAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _AppBarAction({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(Tok.rMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(Tok.rMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 22, color: Tok.textSecondary),
        ),
      ),
    );
  }
}

// ============================================================================
// PDF LIST SCREEN — shows PDFs filtered by class and/or subject
// ============================================================================

class PdfListScreen extends ConsumerStatefulWidget {
  final int? classLevel;
  final String? subjectId;
  final String? subjectName;
  final List<dynamic>? subjects;

  const PdfListScreen({super.key, this.classLevel, this.subjectId, this.subjectName, this.subjects});

  @override
  ConsumerState<PdfListScreen> createState() => _PdfListScreenState();
}

class _PdfListScreenState extends ConsumerState<PdfListScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _pdfs = [];
  bool _initialLoading = true; // only true until first load completes
  String? _selectedSubjectId;
  int _page = 1;
  int _total = 0;
  late AnimationController _staggerCtrl;

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _selectedSubjectId = widget.subjectId;
    _loadPdfs();
  }

  @override
  void dispose() { _staggerCtrl.dispose(); super.dispose(); }

  Future<void> _loadPdfs({bool isFilterChange = false}) async {
    // Show shimmer only on very first load, or when filter/page changed and we have no data
    if (_initialLoading || isFilterChange) {
      setState(() => _initialLoading = true);
    }
    try {
      final res = await _ws.send('getPdfs', {
        if (widget.classLevel != null) 'classLevel': widget.classLevel,
        if (_selectedSubjectId != null) 'subjectId': _selectedSubjectId,
        'page': _page,
        'limit': 30,
      });
      _pdfs = res['pdfs'] as List? ?? [];
      _total = res['total'] as int? ?? 0;
    } catch (e) {
      debugPrint('[PDF_LIST] Load failed: $e');
    }
    if (mounted) {
      setState(() => _initialLoading = false);
      _staggerCtrl.reset();
      _staggerCtrl.forward();
    }
  }

  String get _title {
    if (widget.classLevel != null && widget.subjectName != null) return 'Class ${widget.classLevel} — ${widget.subjectName}';
    if (widget.classLevel != null) return 'Class ${widget.classLevel}';
    if (widget.subjectName != null) return widget.subjectName!;
    return 'PDFs';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        bottom: (widget.classLevel != null && widget.subjects != null && widget.subjects!.isNotEmpty)
            ? PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    children: [
                      _chipButton('All', null),
                      ...widget.subjects!.map((s) => _chipButton(s['name'], s['id'])),
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: _initialLoading
          ? _buildShimmer()
          : _pdfs.isEmpty
              ? const _EmptyState(icon: Icons.description_outlined, title: 'No PDFs found', subtitle: 'Try a different filter')
              : RefreshIndicator(
                  color: Tok.accent,
                  backgroundColor: Tok.bgSurface,
                  onRefresh: () async => _loadPdfs(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pdfs.length + 1,
                    itemBuilder: (context, i) {
                      if (i < _pdfs.length) {
                        final delay = (i * 0.06).clamp(0.0, 0.6);
                        return _StaggerItem(
                          index: i,
                          animation: CurvedAnimation(
                            parent: _staggerCtrl,
                            curve: Interval(delay, (delay + 0.4).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
                          ),
                          child: _pdfCard(_pdfs[i]),
                        );
                      }
                      final totalPages = (_total / 30).ceil();
                      if (totalPages <= 1) return const SizedBox.shrink();
                      return _paginationFooter(totalPages);
                    },
                  ),
                ),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 10,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Tok.bgSurface,
            borderRadius: BorderRadius.circular(Tok.rLg),
            border: Border.all(color: Tok.borderSubtle),
          ),
          child: const Row(
            children: [
              _Skeleton(width: 44, height: 54, radius: 8),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Skeleton(width: 160, height: 14),
                    SizedBox(height: 10),
                    _Skeleton(width: 100, height: 11),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipButton(String label, String? subjectId) {
    final selected = _selectedSubjectId == subjectId;
    return GestureDetector(
      onTap: () {
        _selectedSubjectId = subjectId;
        _page = 1;
        _loadPdfs(isFilterChange: true);
      },
      child: AnimatedContainer(
        duration: Tok.fast,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Tok.accent : Tok.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Tok.accent : Tok.borderDefault),
        ),
        child: Text(label, style: GoogleFonts.inter(
          fontSize: 13,
          color: selected ? Colors.white : Tok.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        )),
      ),
    );
  }

  Widget _pdfCard(dynamic pdf) {
    return _SurfaceCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () => _openPdf(context, pdf),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // PDF thumbnail placeholder
            Container(
              width: 44, height: 54,
              decoration: BoxDecoration(
                color: Tok.bgElevated,
                borderRadius: BorderRadius.circular(Tok.rMd),
                border: Border.all(color: Tok.borderSubtle),
              ),
              child: const Icon(Icons.description_outlined, color: Tok.accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pdf['title'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: Tok.textPrimary),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _MetaBadge(label: 'Class ${pdf['class_level']}'),
                      const SizedBox(width: 6),
                      _MetaBadge(label: pdf['subject_name'] ?? '', color: Tok.accent),
                      if (pdf['page_count'] != null && pdf['page_count'] > 0) ...[
                        const SizedBox(width: 6),
                        Text('${pdf['page_count']}p', style: GoogleFonts.inter(fontSize: 11, color: Tok.textMuted)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: Tok.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _paginationFooter(int totalPages) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PaginationButton(
            icon: Icons.chevron_left_rounded,
            enabled: _page > 1,
            onTap: () { _page--; _loadPdfs(isFilterChange: true); },
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Tok.bgSurface,
              borderRadius: BorderRadius.circular(Tok.rSm),
              border: Border.all(color: Tok.borderSubtle),
            ),
            child: Text('$_page / $totalPages', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Tok.textSecondary)),
          ),
          const SizedBox(width: 16),
          _PaginationButton(
            icon: Icons.chevron_right_rounded,
            enabled: _page < totalPages,
            onTap: () { _page++; _loadPdfs(isFilterChange: true); },
          ),
        ],
      ),
    );
  }

  void _openPdf(BuildContext context, dynamic pdf) {
    final auth = ref.read(authProvider);
    if (!auth.hasActiveSubscription) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscribeWallScreen()));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => PdfViewerScreen(
      pdfId: pdf['id'],
      title: pdf['title'] ?? 'PDF',
    )));
  }
}

/// Small metadata badge
class _MetaBadge extends StatelessWidget {
  final String label;
  final Color? color;
  const _MetaBadge({required this.label, this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: (color ?? Tok.textMuted).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: GoogleFonts.inter(
        fontSize: 11, fontWeight: FontWeight.w500, color: color ?? Tok.textTertiary,
      )),
    );
  }
}

/// Pagination button
class _PaginationButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _PaginationButton({required this.icon, required this.enabled, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? Tok.bgSurface : Tok.bgPrimary,
      borderRadius: BorderRadius.circular(Tok.rMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(Tok.rMd),
        onTap: enabled ? onTap : null,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Tok.rMd),
            border: Border.all(color: enabled ? Tok.borderDefault : Tok.borderSubtle),
          ),
          child: Icon(icon, size: 20, color: enabled ? Tok.textSecondary : Tok.textMuted),
        ),
      ),
    );
  }
}

// ============================================================================
// PDF VIEWER SCREEN — secure viewer with watermark + screenshot block
// ============================================================================

class PdfViewerScreen extends ConsumerStatefulWidget {
  final String pdfId;
  final String title;

  const PdfViewerScreen({super.key, required this.pdfId, required this.title});

  @override
  ConsumerState<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends ConsumerState<PdfViewerScreen> {
  Uint8List? _pdfBytes;
  bool _loading = true;
  String? _error;
  double _progress = 0.0; // 0.0 to 1.0
  int _initialPage = 1;
  final PdfViewerController _controller = PdfViewerController();
  Timer? _pageDebounce;
  Timer? _annotationDebounce;
  bool _annotationsChanged = false;
  String? _pendingAnnotationsJson;

  @override
  void initState() {
    super.initState();
    _enableSecurity();
    _loadPdf();
  }

  Future<void> _enableSecurity() async {
    try {
      await ScreenProtector.protectDataLeakageOn();
    } catch (_) {}
  }

  Future<void> _disableSecurity() async {
    try {
      await ScreenProtector.protectDataLeakageOff();
    } catch (_) {}
  }

  Future<void> _loadPdf() async {
    try {
      // Fetch reading progress + annotations JSON in parallel with PDF
      final progressFuture = _ws.send('getProgress', {'pdfId': widget.pdfId})
          .catchError((_) => <String, dynamic>{'lastPage': 1});

      // Try local cache first, otherwise download original PDF
      Uint8List? bytes = await _pdf.loadFromCache(widget.pdfId);
      if (bytes == null) {
        final res = await _ws.send('getPdfUrl', {'pdfId': widget.pdfId});
        final url = res['url'] as String;
        bytes = await _pdf.downloadAndCache(widget.pdfId, url, onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        });
      }

      // Restore last page + annotations JSON
      final progressRes = await progressFuture;
      final lastPage = (progressRes['lastPage'] as int?) ?? 1;
      final annotJson = progressRes['annotationsJson'] as String?;

      if (mounted) {
        setState(() {
          _pdfBytes = bytes;
          _initialPage = lastPage;
          _pendingAnnotationsJson = annotJson;
          _loading = false;
        });
      }
    } catch (e) {
      final msg = e.toString();
      if (mounted) {
        setState(() {
          _error = msg.contains('SUBSCRIPTION_REQUIRED')
              ? 'A subscription is required to view this PDF.'
              : msg;
          _loading = false;
        });
      }
    }
  }

  void _onDocumentLoaded(PdfDocumentLoadedDetails details) {
    if (_pendingAnnotationsJson != null) {
      _restoreAnnotations(_pendingAnnotationsJson!);
      _pendingAnnotationsJson = null;
    }
  }

  void _restoreAnnotations(String jsonStr) {
    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      for (final a in list) {
        final int pageNumber = a['pageNumber'];
        final List<dynamic> rects = a['rects'];
        final textLines = rects.map((r) => PdfTextLine(
          Rect.fromLTRB(
            (r['l'] as num).toDouble(),
            (r['t'] as num).toDouble(),
            (r['r'] as num).toDouble(),
            (r['b'] as num).toDouble(),
          ),
          '',
          pageNumber,
        )).toList();

        if (textLines.isEmpty) continue;

        Annotation annotation;
        switch (a['type']) {
          case 'highlight':
            annotation = HighlightAnnotation(textBoundsCollection: textLines);
          case 'strikethrough':
            annotation = StrikethroughAnnotation(textBoundsCollection: textLines);
          case 'underline':
            annotation = UnderlineAnnotation(textBoundsCollection: textLines);
          case 'squiggly':
            annotation = SquigglyAnnotation(textBoundsCollection: textLines);
          default:
            continue;
        }

        // ignore: deprecated_member_use
        annotation.color = Color(a['color'] as int);
        annotation.opacity = (a['opacity'] as num).toDouble();
        _controller.addAnnotation(annotation);
      }
      debugPrint('[PDF] Restored ${list.length} annotations from server');
    } catch (e) {
      debugPrint('[PDF] Restore annotations failed: $e');
    }
  }

  String _serializeAnnotations() {
    final annotations = _controller.getAnnotations();
    final list = <Map<String, dynamic>>[];

    for (final a in annotations) {
      String? type;
      List<Rect> rects = [];

      if (a is HighlightAnnotation) {
        type = 'highlight';
        rects = a.textMarkupRects;
      } else if (a is StrikethroughAnnotation) {
        type = 'strikethrough';
        rects = a.textMarkupRects;
      } else if (a is UnderlineAnnotation) {
        type = 'underline';
        rects = a.textMarkupRects;
      } else if (a is SquigglyAnnotation) {
        type = 'squiggly';
        rects = a.textMarkupRects;
      }

      if (type == null) continue;

      list.add({
        'type': type,
        'pageNumber': a.pageNumber,
        // ignore: deprecated_member_use
        'color': a.color.value,
        'opacity': a.opacity,
        'rects': rects.map((r) => {
          'l': r.left, 't': r.top, 'r': r.right, 'b': r.bottom,
        }).toList(),
      });
    }

    return jsonEncode(list);
  }

  void _onPageChanged(PdfPageChangedDetails details) {
    // Debounce — save after 2 seconds of no page change
    _pageDebounce?.cancel();
    _pageDebounce = Timer(const Duration(seconds: 2), () {
      _ws.send('saveProgress', {
        'pdfId': widget.pdfId,
        'lastPage': details.newPageNumber,
        'totalPages': _controller.pageCount,
      }).catchError((_) {});
    });
  }

  void _onAnnotationChanged() {
    _annotationsChanged = true;
    _annotationDebounce?.cancel();
    _annotationDebounce = Timer(const Duration(seconds: 3), () {
      _saveAnnotationsToServer();
    });
  }

  Future<void> _saveAnnotationsToServer() async {
    if (!_annotationsChanged) return;
    try {
      final json = _serializeAnnotations();
      await _ws.send('saveAnnotations', {
        'pdfId': widget.pdfId,
        'annotationsJson': json,
      });
      _annotationsChanged = false;
      debugPrint('[PDF] Annotations saved to DB');
    } catch (e) {
      debugPrint('[PDF] Save annotations failed: $e');
    }
  }

  @override
  void dispose() {
    _pageDebounce?.cancel();
    _annotationDebounce?.cancel();
    if (_controller.pageCount > 0) {
      _ws.send('saveProgress', {
        'pdfId': widget.pdfId,
        'lastPage': _controller.pageNumber,
        'totalPages': _controller.pageCount,
      }).catchError((_) {});
    }
    if (_annotationsChanged) {
      _saveAnnotationsToServer();
    }
    _controller.dispose();
    _disableSecurity();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(authProvider);
    final email = auth.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 72, height: 72,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 72, height: 72,
                          child: CircularProgressIndicator(
                            value: _progress > 0 ? _progress : null,
                            strokeWidth: 3,
                            color: Tok.accent,
                            backgroundColor: Tok.bgElevated,
                          ),
                        ),
                        if (_progress > 0)
                          Text(
                            '${(_progress * 100).toInt()}%',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Tok.accent),
                          )
                        else
                          const Icon(Icons.picture_as_pdf_rounded, size: 24, color: Tok.accent),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _progress > 0 ? 'Downloading PDF...' : 'Loading PDF...',
                    style: GoogleFonts.inter(fontSize: 14, color: Tok.textTertiary),
                  ),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(
                            color: Tok.dangerSubtle,
                            borderRadius: BorderRadius.circular(Tok.rXl),
                          ),
                          child: const Icon(Icons.error_outline_rounded, size: 28, color: Tok.danger),
                        ),
                        const SizedBox(height: 20),
                        Text(_error!, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: Tok.textSecondary)),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 42,
                          child: ElevatedButton.icon(
                            onPressed: () { setState(() { _loading = true; _error = null; }); _loadPdf(); },
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Retry'),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    SfPdfViewer.memory(
                      _pdfBytes!,
                      controller: _controller,
                      initialPageNumber: _initialPage,
                      canShowScrollHead: true,
                      canShowScrollStatus: true,
                      enableDoubleTapZooming: true,
                      pageSpacing: 4,
                      onDocumentLoaded: _onDocumentLoaded,
                      onPageChanged: _onPageChanged,
                      onAnnotationAdded: (_) => _onAnnotationChanged(),
                      onAnnotationEdited: (_) => _onAnnotationChanged(),
                      onAnnotationRemoved: (_) => _onAnnotationChanged(),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _WatermarkPainter(email),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _WatermarkPainter extends CustomPainter {
  final String text;
  _WatermarkPainter(this.text);

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.grey.withValues(alpha: 0.10),
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    canvas.save();
    canvas.rotate(-0.5);
    final w = textPainter.width + 100;
    final h = textPainter.height + 70;
    for (double y = -size.height; y < size.height * 2; y += h) {
      for (double x = -size.width; x < size.width * 2; x += w) {
        textPainter.paint(canvas, Offset(x, y));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// SUBSCRIBE WALL SCREEN
// ============================================================================

class SubscribeWallScreen extends ConsumerStatefulWidget {
  const SubscribeWallScreen({super.key});
  @override
  ConsumerState<SubscribeWallScreen> createState() => _SubscribeWallScreenState();
}

class _SubscribeWallScreenState extends ConsumerState<SubscribeWallScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
  }
  @override
  void dispose() { _animCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Subscribe')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
                .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                // Lock icon
                Center(
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: Tok.accentSubtle,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.lock_open_rounded, size: 36, color: Tok.accent),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Unlock All Study Materials',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                const SizedBox(height: 8),
                Text('Subscribe to access all PDFs from Class 1-12\nacross all subjects.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 14, color: Tok.textTertiary, height: 1.5)),
                const SizedBox(height: 32),

                // Price card
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Tok.bgSurface,
                    borderRadius: BorderRadius.circular(Tok.rXl),
                    border: Border.all(color: Tok.accent.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Tok.accentSubtle,
                          borderRadius: BorderRadius.circular(Tok.rSm),
                        ),
                        child: Text('MONTHLY', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Tok.accent, letterSpacing: 0.8)),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text('₹', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: Tok.accent)),
                          ),
                          Text('199', style: GoogleFonts.inter(fontSize: 48, fontWeight: FontWeight.w800, color: Tok.textPrimary, letterSpacing: -2, height: 1)),
                          Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: Text('/mo', style: GoogleFonts.inter(fontSize: 14, color: Tok.textMuted)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Features
                      ...[
                        ('All PDFs (Class 1-12)', Icons.check_circle_rounded),
                        ('All subjects included', Icons.check_circle_rounded),
                        ('New materials weekly', Icons.check_circle_rounded),
                        ('Cancel anytime', Icons.check_circle_rounded),
                      ].map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Icon(f.$2, size: 18, color: Tok.accent),
                            const SizedBox(width: 10),
                            Text(f.$1, style: GoogleFonts.inter(fontSize: 14, color: Tok.textSecondary)),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      final url = '$_serverDomain/subscribe?userId=${auth.userId}';
                      if (await canLaunchUrl(Uri.parse(url))) {
                        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tok.rMd)),
                    ),
                    child: Text('Subscribe Now', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    ref.read(authProvider.notifier).refreshSubscription();
                    Navigator.pop(context);
                  },
                  child: Text('Already subscribed? Refresh status',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Tok.accentText)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SEARCH SCREEN
// ============================================================================

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> with SingleTickerProviderStateMixin {
  final _searchC = TextEditingController();
  List<dynamic> _results = [];
  bool _searching = false; // subtle inline indicator, not a full-screen swap
  bool _searched = false;
  bool _loadingMore = false;
  int _page = 1;
  int _total = 0;
  String _lastQuery = '';
  Timer? _debounce;
  late AnimationController _staggerCtrl;

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  }

  void _search(String query) {
    _debounce?.cancel();
    if (query.length < 2) {
      setState(() { _results = []; _searched = false; _page = 1; _total = 0; _searching = false; });
      return;
    }
    // Show inline indicator only if we have no results yet
    if (_results.isEmpty) setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      _lastQuery = query;
      _page = 1;
      try {
        final res = await _ws.send('searchPdfs', {'query': query, 'page': 1, 'limit': 30});
        _results = res['pdfs'] as List? ?? [];
        _total = res['total'] as int? ?? 0;
        _searched = true;
      } catch (_) {}
      if (mounted) {
        setState(() => _searching = false);
        _staggerCtrl.reset();
        _staggerCtrl.forward();
      }
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    _page++;
    try {
      final res = await _ws.send('searchPdfs', {'query': _lastQuery, 'page': _page, 'limit': 30});
      final more = res['pdfs'] as List? ?? [];
      _results = [..._results, ...more];
    } catch (_) {
      _page--;
    }
    if (mounted) setState(() => _loadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _searchC,
          autofocus: true,
          style: GoogleFonts.inter(fontSize: 15, color: Tok.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search PDFs...',
            hintStyle: GoogleFonts.inter(color: Tok.textMuted),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onChanged: _search,
        ),
        actions: [
          if (_searchC.text.isNotEmpty)
            _AppBarAction(
              icon: Icons.close_rounded,
              onTap: () {
                _searchC.clear();
                _search('');
              },
            ),
        ],
      ),
      body: _searching && _results.isEmpty
          ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Tok.accent)))
          : !_searched && _results.isEmpty
              ? _EmptyState(icon: Icons.search_rounded, title: 'Search PDFs', subtitle: 'Type at least 2 characters')
              : _results.isEmpty
                  ? const _EmptyState(icon: Icons.search_off_rounded, title: 'No results found', subtitle: 'Try different keywords')
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _results.length + (_results.length < _total ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i >= _results.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: _loadingMore
                                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Tok.accent))
                                  : TextButton(
                                      onPressed: _loadMore,
                                      child: Text('Load more results', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                                    ),
                            ),
                          );
                        }
                        final pdf = _results[i];
                        final delay = (i * 0.05).clamp(0.0, 0.5);
                        return _StaggerItem(
                          index: i,
                          animation: CurvedAnimation(
                            parent: _staggerCtrl,
                            curve: Interval(delay, (delay + 0.4).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
                          ),
                          child: _SurfaceCard(
                            margin: const EdgeInsets.only(bottom: 10),
                            onTap: () {
                              final auth = ref.read(authProvider);
                              if (!auth.hasActiveSubscription) {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscribeWallScreen()));
                              } else {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => PdfViewerScreen(pdfId: pdf['id'], title: pdf['title'] ?? 'PDF')));
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40, height: 40,
                                    decoration: BoxDecoration(
                                      color: Tok.accentSubtle,
                                      borderRadius: BorderRadius.circular(Tok.rMd),
                                    ),
                                    child: const Icon(Icons.description_outlined, size: 20, color: Tok.accent),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(pdf['title'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: Tok.textPrimary),
                                          maxLines: 1, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        Text('Class ${pdf['class_level']} · ${pdf['subject_name'] ?? ''}',
                                          style: GoogleFonts.inter(fontSize: 12, color: Tok.textTertiary)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded, size: 20, color: Tok.textMuted),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchC.dispose();
    _staggerCtrl.dispose();
    super.dispose();
  }
}

// ============================================================================
// PROFILE SCREEN
// ============================================================================

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..forward();
  }
  @override
  void dispose() { _animCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Avatar + Info ────────────────────────────────
              Center(
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: Tok.accentSubtle,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Tok.accent.withValues(alpha: 0.3)),
                  ),
                  child: Center(
                    child: Text(
                      (auth.name ?? 'U')[0].toUpperCase(),
                      style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w700, color: Tok.accent),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(child: Text(auth.name ?? '', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3))),
              const SizedBox(height: 4),
              Center(child: Text(auth.email ?? '', style: GoogleFonts.inter(fontSize: 14, color: Tok.textTertiary))),
              const SizedBox(height: 28),

              // ─── Subscription Status Card ────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Tok.bgSurface,
                  borderRadius: BorderRadius.circular(Tok.rLg),
                  border: Border.all(color: auth.hasActiveSubscription ? Tok.accent.withValues(alpha: 0.3) : Tok.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: auth.hasActiveSubscription ? Tok.accentSubtle : Tok.dangerSubtle,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        auth.hasActiveSubscription ? Icons.verified_rounded : Icons.lock_rounded,
                        color: auth.hasActiveSubscription ? Tok.accent : Tok.danger, size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.hasActiveSubscription ? 'Active Subscription' : 'No Subscription',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14,
                              color: auth.hasActiveSubscription ? Tok.accent : Tok.danger),
                          ),
                          if (auth.subExpiresAt != null) ...[
                            const SizedBox(height: 2),
                            Text('Expires: ${auth.subExpiresAt!.substring(0, 10)}',
                              style: GoogleFonts.inter(fontSize: 12, color: Tok.textMuted)),
                          ],
                        ],
                      ),
                    ),
                    if (!auth.hasActiveSubscription)
                      SizedBox(
                        height: 34,
                        child: ElevatedButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscribeWallScreen())),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          child: const Text('Upgrade'),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ─── Section label ────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 10, left: 4),
                child: Text('SETTINGS', style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w600, color: Tok.textMuted, letterSpacing: 0.8,
                )),
              ),

              // Actions
              _profileTile(Icons.edit_outlined, 'Edit Profile', 'Update name and phone', () => _showEditProfile(context)),
              _profileTile(Icons.sync_rounded, 'Refresh Subscription', 'Check subscription status', () async {
                await ref.read(authProvider.notifier).refreshSubscription();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subscription status refreshed')));
              }),
              _profileTile(Icons.delete_sweep_outlined, 'Clear PDF Cache', 'Free up storage space', () async {
                await _pdf.clearCache();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache cleared')));
              }),
              _profileTile(Icons.lock_outline_rounded, 'Change Password', 'Update your password', () => _showChangePassword(context)),

              const SizedBox(height: 28),

              // Logout
              SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.logout_rounded, size: 18, color: Tok.danger),
                  label: Text('Log out', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Tok.danger)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Tok.danger.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tok.rMd)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileTile(IconData icon, String label, String subtitle, VoidCallback onTap) {
    return _SurfaceCard(
      margin: const EdgeInsets.only(bottom: 8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: Tok.bgElevated,
                borderRadius: BorderRadius.circular(Tok.rMd),
                border: Border.all(color: Tok.borderSubtle),
              ),
              child: Icon(icon, size: 18, color: Tok.textSecondary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Tok.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: Tok.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: Tok.textMuted),
          ],
        ),
      ),
    );
  }

  void _showEditProfile(BuildContext context) {
    final auth = ref.read(authProvider);
    final nameC = TextEditingController(text: auth.name ?? '');
    final phoneC = TextEditingController(text: auth.phone ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Full Name', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Tok.textSecondary)),
            const SizedBox(height: 6),
            TextField(controller: nameC, style: GoogleFonts.inter(fontSize: 14)),
            const SizedBox(height: 16),
            Text('Phone', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Tok.textSecondary)),
            const SizedBox(height: 6),
            TextField(controller: phoneC, keyboardType: TextInputType.phone, style: GoogleFonts.inter(fontSize: 14)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(authProvider.notifier).updateProfile(
                  name: nameC.text.trim(),
                  phone: phoneC.text.trim(),
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));
                }
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Tok.danger));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showChangePassword(BuildContext context) {
    final currentC = TextEditingController();
    final newC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Password', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Tok.textSecondary)),
            const SizedBox(height: 6),
            TextField(controller: currentC, obscureText: true, style: GoogleFonts.inter(fontSize: 14)),
            const SizedBox(height: 16),
            Text('New Password', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Tok.textSecondary)),
            const SizedBox(height: 6),
            TextField(controller: newC, obscureText: true, style: GoogleFonts.inter(fontSize: 14),
              decoration: const InputDecoration(hintText: 'Min 6 characters')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(authProvider.notifier).changePassword(
                  currentPassword: currentC.text,
                  newPassword: newC.text,
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed!')));
                }
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Tok.danger));
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// HELPER — Map subject icon names to Material icons
// ============================================================================

IconData _getSubjectIcon(String name) {
  switch (name) {
    case 'calculate': return Icons.calculate_rounded;
    case 'science': return Icons.science_rounded;
    case 'translate': return Icons.translate_rounded;
    case 'public': return Icons.public_rounded;
    case 'language': return Icons.language_rounded;
    case 'bolt': return Icons.bolt_rounded;
    case 'biotech': return Icons.biotech_rounded;
    case 'eco': return Icons.eco_rounded;
    case 'computer': return Icons.computer_rounded;
    default: return Icons.menu_book_rounded;
  }
}
