// ============================================================================
// AUTH SERVICE — manages login state, JWT storage, user data
// ============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'ws_service.dart';

// ---------------------------------------------------------------------------
// Auth State
// ---------------------------------------------------------------------------

class AuthState {
  final bool isLoading;
  final bool isLoggedIn;
  final String? userId;
  final String? name;
  final String? email;
  final String? phone;
  final String? token;
  final String subStatus; // 'active', 'none', 'expired'
  final String? subExpiresAt;

  const AuthState({
    this.isLoading = true,
    this.isLoggedIn = false,
    this.userId,
    this.name,
    this.email,
    this.phone,
    this.token,
    this.subStatus = 'none',
    this.subExpiresAt,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isLoggedIn,
    String? userId,
    String? name,
    String? email,
    String? phone,
    String? token,
    String? subStatus,
    String? subExpiresAt,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      token: token ?? this.token,
      subStatus: subStatus ?? this.subStatus,
      subExpiresAt: subExpiresAt ?? this.subExpiresAt,
    );
  }

  bool get hasActiveSubscription => subStatus == 'active';
}

// ---------------------------------------------------------------------------
// Auth Notifier
// ---------------------------------------------------------------------------

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  final _storage = const FlutterSecureStorage();
  final _ws = WsService();
  StreamSubscription? _eventSub;

  Future<void> init() async {
    // Try to restore session from secure storage
    final token = await _storage.read(key: 'token');
    if (token != null) {
      _ws.setToken(token);
      _ws.connect();
      try {
        final res = await _ws.send('login', {'token': token}, timeout: const Duration(seconds: 15));
        _handleLoginResponse(res, res['token'] as String? ?? token);
        return;
      } catch (e) {
        debugPrint('[AUTH] Token restore failed: $e');
        await _storage.delete(key: 'token');
      }
    }
    state = const AuthState(isLoading: false);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    String phone = '',
  }) async {
    _ws.connect();
    final res = await _ws.send('register', {
      'name': name,
      'email': email,
      'password': password,
      'phone': phone,
    });
    _handleLoginResponse(res, res['token'] as String);
  }

  Future<void> login({required String email, required String password}) async {
    _ws.connect();
    final res = await _ws.send('login', {
      'email': email,
      'password': password,
    });
    _handleLoginResponse(res, res['token'] as String);
  }

  void _handleLoginResponse(Map<String, dynamic> res, String token) {
    final user = res['user'] as Map<String, dynamic>? ?? {};
    final sub = res['subscription'] as Map<String, dynamic>? ?? {};

    _ws.setToken(token);
    _storage.write(key: 'token', value: token);

    // Listen for server push events
    _eventSub?.cancel();
    _eventSub = _ws.events.listen((event) {
      if (event['event'] == 'subscriptionActivated' || event['event'] == 'subscriptionExpired') {
        refreshSubscription();
      }
    });

    state = AuthState(
      isLoading: false,
      isLoggedIn: true,
      userId: user['id'] as String?,
      name: user['name'] as String?,
      email: user['email'] as String?,
      phone: user['phone'] as String?,
      token: token,
      subStatus: sub['status'] as String? ?? 'none',
      subExpiresAt: sub['expiresAt'] as String?,
    );
  }

  Future<void> refreshSubscription() async {
    try {
      final res = await _ws.send('checkSubscription', {});
      state = state.copyWith(
        subStatus: res['status'] as String? ?? 'none',
        subExpiresAt: res['expiresAt'] as String?,
      );
    } catch (e) {
      debugPrint('[AUTH] Refresh sub failed: $e');
    }
  }

  Future<void> updateProfile({String? name, String? phone}) async {
    final res = await _ws.send('updateProfile', {
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
    });
    final user = res['user'] as Map<String, dynamic>? ?? {};
    state = state.copyWith(
      name: user['name'] as String?,
      phone: user['phone'] as String?,
    );
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    await _ws.send('changePassword', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  Future<void> logout() async {
    await _storage.delete(key: 'token');
    _ws.setToken(null);
    _eventSub?.cancel();
    state = const AuthState(isLoading: false);
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
