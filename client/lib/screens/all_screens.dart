// ============================================================================
// ALL SCREENS — single file for simplicity
//
// Screens: Splash, Login, Register, Home, PdfList, PdfViewer,
//          SubscribeWall, Profile, Search
// ============================================================================

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/ws_service.dart';
import '../services/auth_service.dart';
import '../services/pdf_service.dart';

// ===================== CHANGE THIS =====================
const String _serverDomain = 'https://yourdomain.com';
// =======================================================

final _ws = WsService();
final _pdf = PdfService();

// ============================================================================
// SPLASH SCREEN
// ============================================================================

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🎓', style: TextStyle(fontSize: 64)),
            SizedBox(height: 16),
            Text('Aravind', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Color(0xFF10B981)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// LOGIN SCREEN
// ============================================================================

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

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
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              const Center(child: Text('🎓', style: TextStyle(fontSize: 56))),
              const SizedBox(height: 12),
              const Center(child: Text('Aravind', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF10B981)))),
              const Center(child: Text('Study Materials', style: TextStyle(color: Colors.grey))),
              const SizedBox(height: 48),
              TextField(
                controller: _emailC,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passC,
                obscureText: _obscure,
                decoration: InputDecoration(
                  hintText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Login'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                child: const Text("Don't have an account? Register", style: TextStyle(color: Color(0xFF10B981))),
              ),
            ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _nameC, decoration: const InputDecoration(hintText: 'Full Name *', prefixIcon: Icon(Icons.person_outline))),
            const SizedBox(height: 12),
            TextField(controller: _emailC, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'Email *', prefixIcon: Icon(Icons.email_outlined))),
            const SizedBox(height: 12),
            TextField(controller: _phoneC, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: 'Phone (optional)', prefixIcon: Icon(Icons.phone_outlined))),
            const SizedBox(height: 12),
            TextField(controller: _passC, obscureText: true, decoration: const InputDecoration(hintText: 'Password * (min 6 chars)', prefixIcon: Icon(Icons.lock_outline))),
            const SizedBox(height: 12),
            TextField(controller: _confirmC, obscureText: true, decoration: const InputDecoration(hintText: 'Confirm Password *', prefixIcon: Icon(Icons.lock_outline))),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _register,
              child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Register'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// HOME SCREEN — Two tabs: By Class, By Subject
// ============================================================================

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;
  List<dynamic> _subjects = [];
  List<dynamic> _classes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
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
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🎓 Aravind', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
        actions: [
          // Subscription badge
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: auth.hasActiveSubscription ? const Color(0xFF059669) : Colors.red.shade900,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              auth.hasActiveSubscription ? '✅ PRO' : '🔒 FREE',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(icon: const Icon(Icons.search), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()))),
          IconButton(icon: const Icon(Icons.person_outline), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()))),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : RefreshIndicator(
              onRefresh: () async {
                await _load();
                ref.read(authProvider.notifier).refreshSubscription();
              },
              child: Column(
                children: [
                  // Tab bar
                  Row(
                    children: [
                      _tabButton('By Class', 0),
                      _tabButton('By Subject', 1),
                    ],
                  ),
                  Expanded(
                    child: _tab == 0 ? _buildClassView() : _buildSubjectView(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _tabButton(String label, int index) {
    final selected = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: selected ? const Color(0xFF10B981) : Colors.transparent, width: 2)),
          ),
          child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600, color: selected ? const Color(0xFF10B981) : Colors.grey)),
        ),
      ),
    );
  }

  Widget _buildClassView() {
    if (_classes.isEmpty) return const Center(child: Text('No classes available', style: TextStyle(color: Colors.grey)));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 12,
      itemBuilder: (context, i) {
        final classLevel = i + 1;
        final classData = _classes.firstWhere((c) => c['class_level'] == classLevel, orElse: () => null);
        final count = classData?['pdf_count'] ?? 0;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF059669),
              child: Text('$classLevel', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            title: Text('Class $classLevel', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('$count PDFs available', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: count > 0 ? () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => PdfListScreen(classLevel: classLevel, subjects: _subjects),
            )) : null,
          ),
        );
      },
    );
  }

  Widget _buildSubjectView() {
    if (_subjects.isEmpty) return const Center(child: Text('No subjects available', style: TextStyle(color: Colors.grey)));
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.4, crossAxisSpacing: 10, mainAxisSpacing: 10),
      itemCount: _subjects.length,
      itemBuilder: (context, i) {
        final s = _subjects[i];
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => PdfListScreen(subjectId: s['id'], subjectName: s['name']),
            )),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_getSubjectIcon(s['icon_name'] ?? ''), size: 32, color: const Color(0xFF10B981)),
                  const SizedBox(height: 8),
                  Text(s['name'] ?? '', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ],
              ),
            ),
          ),
        );
      },
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
  final List<dynamic>? subjects; // passed when coming from class view

  const PdfListScreen({super.key, this.classLevel, this.subjectId, this.subjectName, this.subjects});

  @override
  ConsumerState<PdfListScreen> createState() => _PdfListScreenState();
}

class _PdfListScreenState extends ConsumerState<PdfListScreen> {
  List<dynamic> _pdfs = [];
  bool _loading = true;
  String? _selectedSubjectId;
  int _page = 1;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _selectedSubjectId = widget.subjectId;
    _loadPdfs();
  }

  Future<void> _loadPdfs() async {
    setState(() => _loading = true);
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
    if (mounted) setState(() => _loading = false);
  }

  String get _title {
    if (widget.classLevel != null && widget.subjectName != null) return 'Class ${widget.classLevel} - ${widget.subjectName}';
    if (widget.classLevel != null) return 'Class ${widget.classLevel}';
    if (widget.subjectName != null) return widget.subjectName!;
    return 'PDFs';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: Column(
        children: [
          // Subject filter chips (when viewing by class)
          if (widget.classLevel != null && widget.subjects != null && widget.subjects!.isNotEmpty)
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  _chipButton('All', null),
                  ...widget.subjects!.map((s) => _chipButton(s['name'], s['id'])),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
                : _pdfs.isEmpty
                    ? const Center(child: Text('No PDFs found', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _pdfs.length,
                        itemBuilder: (context, i) => _pdfCard(_pdfs[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _chipButton(String label, String? subjectId) {
    final selected = _selectedSubjectId == subjectId;
    return GestureDetector(
      onTap: () {
        _selectedSubjectId = subjectId;
        _page = 1;
        _loadPdfs();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF059669) : const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, color: selected ? Colors.white : Colors.grey, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }

  Widget _pdfCard(dynamic pdf) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44, height: 56,
          decoration: BoxDecoration(color: const Color(0xFF1F1F1F), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.picture_as_pdf, color: Color(0xFF10B981)),
        ),
        title: Text(pdf['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Text('Class ${pdf['class_level']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 8),
              Text(pdf['subject_name'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF10B981))),
              if (pdf['page_count'] != null && pdf['page_count'] > 0) ...[
                const SizedBox(width: 8),
                Text('${pdf['page_count']} pages', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () => _openPdf(context, pdf),
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

  @override
  void initState() {
    super.initState();
    _enableSecurity();
    _loadPdf();
  }

  Future<void> _enableSecurity() async {
    try {
      await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
    } catch (_) {} // Fails on iOS, handled separately
  }

  Future<void> _disableSecurity() async {
    try {
      await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
    } catch (_) {}
  }

  Future<void> _loadPdf() async {
    try {
      // First check cache
      final cached = await _pdf.loadFromCache(widget.pdfId);
      if (cached != null) {
        setState(() { _pdfBytes = cached; _loading = false; });
        return;
      }

      // Get signed URL from server
      final res = await _ws.send('getPdfUrl', {'pdfId': widget.pdfId});
      final url = res['url'] as String;

      // Download, encrypt, cache, return decrypted bytes
      final bytes = await _pdf.downloadAndCache(widget.pdfId, url);
      if (mounted) setState(() { _pdfBytes = bytes; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  void dispose() {
    _disableSecurity();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(authProvider);
    final email = auth.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 16)),
        // NO share/download/print buttons
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF10B981)),
                  SizedBox(height: 16),
                  Text('Loading PDF...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: () { setState(() { _loading = true; _error = null; }); _loadPdf(); }, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    // PDF Viewer
                    SfPdfViewer.memory(
                      _pdfBytes!,
                      canShowScrollHead: true,
                      canShowScrollStatus: true,
                      enableDoubleTapZooming: true,
                      pageSpacing: 4,
                    ),
                    // Watermark overlay — user email diagonal across screen
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

// Watermark painter — draws email diagonally across every visible area
class _WatermarkPainter extends CustomPainter {
  final String text;
  _WatermarkPainter(this.text);

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.grey.withOpacity(0.12),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    canvas.save();
    canvas.rotate(-0.5); // ~30 degrees

    final w = textPainter.width + 80;
    final h = textPainter.height + 60;

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
// SUBSCRIBE WALL SCREEN — shown when non-subscribed user taps a PDF
// ============================================================================

class SubscribeWallScreen extends ConsumerWidget {
  const SubscribeWallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Subscribe')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.lock_outline, size: 64, color: Color(0xFF10B981)),
            const SizedBox(height: 16),
            const Text('Unlock All Study Materials',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Subscribe to access all PDFs from Class 1-12 across all subjects.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            // Price card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF059669), width: 2),
              ),
              child: Column(
                children: [
                  const Text('Monthly Plan', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('₹', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                      Text('199', style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                      Text('/mo', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...[
                    '✅ All PDFs (Class 1-12)',
                    '✅ All subjects included',
                    '✅ New materials weekly',
                    '✅ Cancel anytime',
                  ].map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(f, style: const TextStyle(fontSize: 14)),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
              onPressed: () async {
                // Open subscribe page in browser
                final url = '$_serverDomain/subscribe?userId=${auth.userId}';
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('Subscribe Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                ref.read(authProvider.notifier).refreshSubscription();
                Navigator.pop(context);
              },
              child: const Text('Already subscribed? Refresh status', style: TextStyle(color: Color(0xFF10B981))),
            ),
          ],
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

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchC = TextEditingController();
  List<dynamic> _results = [];
  bool _loading = false;
  bool _searched = false;
  Timer? _debounce;

  void _search(String query) {
    _debounce?.cancel();
    if (query.length < 2) {
      setState(() { _results = []; _searched = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _loading = true);
      try {
        final res = await _ws.send('searchPdfs', {'query': query});
        _results = res['pdfs'] as List? ?? [];
        _searched = true;
      } catch (_) {}
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchC,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search PDFs...',
            border: InputBorder.none,
            filled: false,
          ),
          onChanged: _search,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : !_searched
              ? const Center(child: Text('Type at least 2 characters to search', style: TextStyle(color: Colors.grey)))
              : _results.isEmpty
                  ? const Center(child: Text('No results found', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _results.length,
                      itemBuilder: (context, i) {
                        final pdf = _results[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.picture_as_pdf, color: Color(0xFF10B981)),
                            title: Text(pdf['title'] ?? ''),
                            subtitle: Text('Class ${pdf['class_level']} • ${pdf['subject_name'] ?? ''}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            onTap: () {
                              final auth = ref.read(authProvider);
                              if (!auth.hasActiveSubscription) {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscribeWallScreen()));
                              } else {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => PdfViewerScreen(pdfId: pdf['id'], title: pdf['title'] ?? 'PDF')));
                              }
                            },
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

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Avatar
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xFF059669),
                child: Text(
                  (auth.name ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(child: Text(auth.name ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            Center(child: Text(auth.email ?? '', style: const TextStyle(color: Colors.grey))),
            const SizedBox(height: 24),

            // Subscription status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: auth.hasActiveSubscription ? const Color(0xFF059669) : Colors.red.shade900),
              ),
              child: Row(
                children: [
                  Icon(auth.hasActiveSubscription ? Icons.check_circle : Icons.lock, color: auth.hasActiveSubscription ? const Color(0xFF10B981) : Colors.redAccent, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(auth.hasActiveSubscription ? 'Active Subscription' : 'No Active Subscription',
                          style: TextStyle(fontWeight: FontWeight.w600, color: auth.hasActiveSubscription ? const Color(0xFF10B981) : Colors.redAccent)),
                        if (auth.subExpiresAt != null)
                          Text('Expires: ${auth.subExpiresAt!.substring(0, 10)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  if (!auth.hasActiveSubscription)
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscribeWallScreen())),
                      child: const Text('Subscribe'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Actions
            _profileTile(Icons.refresh, 'Refresh Subscription', () async {
              await ref.read(authProvider.notifier).refreshSubscription();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subscription status refreshed')));
            }),
            _profileTile(Icons.delete_outline, 'Clear PDF Cache', () async {
              await _pdf.clearCache();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache cleared')));
            }),
            _profileTile(Icons.lock_outline, 'Change Password', () => _showChangePassword(context)),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () async {
                await ref.read(authProvider.notifier).logout();
                if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
              },
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              label: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.all(14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileTile(IconData icon, String label, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF10B981)),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  void _showChangePassword(BuildContext context) {
    final currentC = TextEditingController();
    final newC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: currentC, obscureText: true, decoration: const InputDecoration(hintText: 'Current Password')),
            const SizedBox(height: 12),
            TextField(controller: newC, obscureText: true, decoration: const InputDecoration(hintText: 'New Password (min 6 chars)')),
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
                if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
              }
            },
            child: const Text('Change'),
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
    case 'calculate': return Icons.calculate;
    case 'science': return Icons.science;
    case 'translate': return Icons.translate;
    case 'public': return Icons.public;
    case 'language': return Icons.language;
    case 'bolt': return Icons.bolt;
    case 'biotech': return Icons.biotech;
    case 'eco': return Icons.eco;
    case 'computer': return Icons.computer;
    default: return Icons.book;
  }
}
