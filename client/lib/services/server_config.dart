// ============================================================================
// SERVER CONFIG — Fetches WS URL and server domain from Firebase RTDB
//
// On startup, reads /config.json from Firebase Realtime Database (REST API).
// The WS server publishes its IP/ports there on every boot.
// This lets the Flutter client auto-discover the server without hardcoding.
// ============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;

class ServerConfig {
  static final ServerConfig _instance = ServerConfig._();
  factory ServerConfig() => _instance;
  ServerConfig._();

  // Firebase RTDB REST endpoint (public read)
  static const String _firebaseDbUrl =
      'https://python-hosting-server-default-rtdb.firebaseio.com';

  String _wsUrl = 'ws://192.168.29.81:3001'; // fallback
  String _serverDomain = 'http://192.168.29.81:3000'; // fallback
  bool _loaded = false;

  String get wsUrl => _wsUrl;
  String get serverDomain => _serverDomain;
  bool get loaded => _loaded;

  /// Fetch config from Firebase. Call once at app startup.
  Future<void> load() async {
    if (_loaded) return;
    try {
      final res = await http
          .get(Uri.parse('$_firebaseDbUrl/config.json'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map) {
          _wsUrl = data['wsUrl'] ?? _wsUrl;
          _serverDomain = data['serverDomain'] ?? _serverDomain;
        }
      }
    } catch (_) {
      // Use fallback values — server might be unreachable
    }
    _loaded = true;
  }
}
