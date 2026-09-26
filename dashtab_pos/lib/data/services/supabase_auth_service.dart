import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles all authentication operations via Supabase Auth.
class SupabaseAuthService {
  final SupabaseClient _client;

  SupabaseAuthService(this._client);

  /// Signs in with email + password.
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Creates a new account with email + password.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: fullName == null ? null : {'full_name': fullName},
    );
  }

  /// Updates the signed-in user's metadata (e.g. full_name).
  Future<User?> updateUserMetadata(Map<String, dynamic> data) async {
    final res = await _client.auth.updateUser(UserAttributes(data: data));
    return res.user;
  }

  /// Signs out the current session.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Returns the current session, or null if not authenticated.
  Session? get currentSession => _client.auth.currentSession;

  /// Returns the current user, or null if not authenticated.
  User? get currentUser => _client.auth.currentUser;

  /// Restores the session from persisted storage (auto on app start).
  Future<Session?> restoreSession() async {
    // The Supabase SDK automatically persists and restores the session
    // on initialization. We just return the current session if present.
    return _client.auth.currentSession;
  }

  /// Stream of auth state changes (login, logout, token refresh).
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  /// Refreshes the session if it's about to expire.
  Future<Session?> refreshSession() async {
    final session = _client.auth.currentSession;
    if (session == null) return null;
    try {
      final refreshed = await _client.auth.refreshSession();
      return refreshed.session;
    } catch (_) {
      return null;
    }
  }
}
