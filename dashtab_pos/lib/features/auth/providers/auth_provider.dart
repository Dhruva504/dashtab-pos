import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/services/supabase_services.dart';
import '../../../data/services/supabase_store.dart';
import '../../../core/security/app_lock.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/theme/demo_data.dart';

class AuthState {
  final bool isAuthenticated;
  final String? userId;
  final String? fullName;
  final String? email;
  final String? tenantName;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.isAuthenticated = false,
    this.userId,
    this.fullName,
    this.email,
    this.tenantName,
    this.isLoading = false,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    String? userId,
    String? fullName,
    String? email,
    String? tenantName,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      tenantName: tenantName ?? this.tenantName,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _restoreSession();
    return const AuthState();
  }

  /// Restores a persisted session and loads the workspace.
  Future<void> _restoreSession() async {
    final authService = ref.read(supabaseAuthServiceProvider);
    final session = await authService.restoreSession();
    if (session != null) {
      // A restored session means the app was reopened — ask for the POS PIN
      // before showing the workspace (when one is configured).
      await _finalizeLogin(fromRestore: true);
    } else {
      state = const AuthState();
    }
  }

  /// Runs after a successful sign-in: ensures the user belongs to a
  /// workspace (bootstrap on first run), refreshes the JWT so the
  /// tenant claim reaches the token, and loads the store.
  Future<String?> _finalizeLogin({
    String restaurantName = '',
    String fullName = '',
    bool fromRestore = false,
  }) async {
    try {
      final authService = ref.read(supabaseAuthServiceProvider);
      final user = authService.currentUser;
      if (user == null) return 'Authentication failed';

      final store = SupabaseStore(Supabase.instance.client);

      // First login on a fresh deployment: create the workspace via RPC.
      if (store.tenantId == null) {
        await store.client.rpc(
          'bootstrap_tenant',
          params: {
            'p_restaurant_name': restaurantName.trim().isEmpty
                ? null
                : restaurantName.trim(),
            'p_full_name': fullName.trim().isEmpty ? null : fullName.trim(),
          },
        );
        // The JWT must be refreshed to pick up the new tenant claim.
        await authService.refreshSession();
      }

      // Load all collections (products, orders, tables, staff, ...).
      await demo.init();

      // A restored session with a POS PIN configured starts locked — this is
      // what makes the PIN a real quick-login instead of a stored string.
      // An explicit email+password login does not lock (they just proved
      // their credentials), only reopening the app does.
      if (fromRestore) {
        ref.read(appLockProvider.notifier).lockIfPinSet();
      } else {
        ref.read(appLockProvider.notifier).unlock();
      }

      final t = demo.settings['name'];
      state = AuthState(
        isAuthenticated: true,
        userId: user.id,
        email: user.email,
        fullName: user.userMetadata?['full_name'] as String? ?? fullName,
        tenantName: t,
      );
      return null;
    } catch (e) {
      demo.reset();
      state = const AuthState().copyWith(
        isLoading: false,
        errorMessage: 'Could not connect to your workspace: $e',
      );
      return 'Could not connect to your workspace: $e';
    }
  }

  /// Email + password login against Supabase Auth.
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final authService = ref.read(supabaseAuthServiceProvider);
      await authService.signInWithPassword(email: email, password: password);
      return await _finalizeLogin();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _readableAuthError(e),
      );
      return _readableAuthError(e);
    }
  }

  /// Creates a new account (used when a workspace is first set up).
  Future<String?> register({
    required String name,
    required String email,
    required String password,
    String restaurantName = '',
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final authService = ref.read(supabaseAuthServiceProvider);
      await authService.signUp(
        email: email,
        password: password,
        fullName: name,
      );
      if (authService.currentUser == null) {
        // Email confirmation is enabled on this project.
        const msg = 'Please confirm your email address, then log in.';
        state = state.copyWith(isLoading: false, errorMessage: msg);
        return msg;
      }
      return await _finalizeLogin(
        restaurantName: restaurantName,
        fullName: name,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _readableAuthError(e),
      );
      return _readableAuthError(e);
    }
  }

  /// Updates the signed-in user's display name (auth metadata) and
  /// refreshes the in-memory state so the whole UI reflects it.
  Future<String?> updateDisplayName(String fullName) async {
    final name = fullName.trim();
    if (name.isEmpty) return null;
    try {
      final authService = ref.read(supabaseAuthServiceProvider);
      final user = await authService.updateUserMetadata({'full_name': name});
      state = state.copyWith(fullName: name);
      if (user == null) return 'Could not update your name.';
      return null;
    } catch (e) {
      return 'Could not update your name: $e';
    }
  }

  /// Clears any displayed error message.
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  Future<void> logout() async {
    final authService = ref.read(supabaseAuthServiceProvider);
    try {
      await authService.signOut();
    } catch (_) {}
    await SecureStorage.clearAll();
    demo.reset();
    ref.read(appLockProvider.notifier).unlock();
    ref.read(posUnlockedProvider.notifier).lock();
    state = const AuthState();
  }

  String _readableAuthError(Object e) {
    final raw = e.toString();
    if (raw.contains('Invalid login credentials')) {
      return 'Invalid email or password. Check your credentials and try again.';
    }
    if (raw.contains('Email not confirmed')) {
      return 'Please confirm your email address before logging in.';
    }
    if (raw.contains('already registered') || raw.contains('already been registered')) {
      return 'An account with this email already exists. Log in instead.';
    }
    if (raw.contains('ClientException') || raw.contains('SocketException')) {
      return 'Cannot reach the server. Check your connection and try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
