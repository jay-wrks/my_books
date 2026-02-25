// ============================================================================
// WEBSOCKET SERVICE — Single persistent connection for all app communication
//
// Protocol:
//   Send: { rid, action, token, data }
//   Recv: { rid, status, data, error } or { rid:null, event, data }
//
// Features:
//   - Auto-reconnect with exponential backoff
//   - Request/response matching via rid + Completer
//   - Server-push events via StreamController
//   - Ping/pong keepalive
//   - Request timeout (10s)
//   - Thread-safe message queue during disconnect
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// ===================== CHANGE THIS TO YOUR SERVER DOMAIN =====================
const String _wsUrl = 'wss://yourdomain.com/ws';
// For local dev: 'ws://10.0.2.2:3001' (Android emulator) or 'ws://localhost:3001'
// =============================================================================

class WsService {
  static final WsService _instance = WsService._();
  factory WsService() => _instance;
  WsService._();

  WebSocketChannel? _channel;
  bool _connected = false;
  bool _disposed = false;
  int _retryDelay = 1;
  String? _authToken;
  final _uuid = const Uuid();

  // Pending requests: rid → Completer
  final Map<String, Completer<Map<String, dynamic>>> _pending = {};
  // Queue messages while disconnected
  final List<String> _queue = [];
  // Server-push events
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _eventController.stream;

  // Connection state
  final _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionState => _connectionController.stream;
  bool get isConnected => _connected;

  Timer? _pingTimer;
  Timer? _reconnectTimer;

  void setToken(String? token) => _authToken = token;

  // ---------------------------------------------------------------------------
  // Connect
  // ---------------------------------------------------------------------------
  void connect() {
    if (_disposed) return;
    _doConnect();
  }

  void _doConnect() {
    try {
      _channel?.sink.close();
    } catch (_) {}

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      _channel!.stream.listen(
        _onMessage,
        onDone: _onDisconnect,
        onError: (_) => _onDisconnect(),
      );
      _connected = true;
      _retryDelay = 1;
      _connectionController.add(true);
      _startPing();
      _flushQueue();
      debugPrint('[WS] Connected');
    } catch (e) {
      debugPrint('[WS] Connect failed: $e');
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final rid = msg['rid'] as String?;

      if (rid != null && _pending.containsKey(rid)) {
        // Response to a request
        final completer = _pending.remove(rid)!;
        if (msg['status'] == 'ok') {
          completer.complete(msg['data'] as Map<String, dynamic>? ?? {});
        } else {
          completer.completeError(WsError(msg['error'] as String? ?? 'Unknown error'));
        }
      } else if (msg.containsKey('event')) {
        // Server push event
        _eventController.add(msg);
      }
    } catch (e) {
      debugPrint('[WS] Parse error: $e');
    }
  }

  void _onDisconnect() {
    _connected = false;
    _connectionController.add(false);
    _pingTimer?.cancel();
    debugPrint('[WS] Disconnected');

    // Fail all pending requests
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(WsError('Disconnected'));
    }
    _pending.clear();

    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _retryDelay), () {
      _retryDelay = (_retryDelay * 2).clamp(1, 30);
      _doConnect();
    });
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_connected) {
        send('ping', {}).catchError((_) {}); // ignore ping errors
      }
    });
  }

  void _flushQueue() {
    while (_queue.isNotEmpty && _connected) {
      final msg = _queue.removeAt(0);
      try {
        _channel!.sink.add(msg);
      } catch (_) {
        _queue.insert(0, msg);
        break;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Send request — returns Future<Map> that resolves when server responds
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> send(String action, Map<String, dynamic> data, {Duration timeout = const Duration(seconds: 10)}) {
    final rid = _uuid.v4();
    final completer = Completer<Map<String, dynamic>>();
    _pending[rid] = completer;

    final msg = jsonEncode({
      'rid': rid,
      'action': action,
      'token': _authToken,
      'data': data,
    });

    if (_connected) {
      try {
        _channel!.sink.add(msg);
      } catch (e) {
        _pending.remove(rid);
        completer.completeError(WsError('Send failed: $e'));
        return completer.future;
      }
    } else {
      _queue.add(msg);
    }

    // Timeout
    Timer(timeout, () {
      if (_pending.containsKey(rid)) {
        _pending.remove(rid);
        if (!completer.isCompleted) {
          completer.completeError(WsError('Request timed out'));
        }
      }
    });

    return completer.future;
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------
  void dispose() {
    _disposed = true;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _eventController.close();
    _connectionController.close();
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(WsError('Disposed'));
    }
    _pending.clear();
  }
}

class WsError implements Exception {
  final String message;
  WsError(this.message);
  @override
  String toString() => message;
}
