import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthState {
  final bool isAuthenticated;
  final String? username;
  final String? tenantSlug;

  AuthState({this.isAuthenticated = false, this.username, this.tenantSlug});
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    return AuthState();
  }

  Future<bool> login(String username, String password, String tenantSlug) async {
    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 800));
    
    // Accept demo credentials
    if (username.isNotEmpty && password.isNotEmpty) {
      state = AuthState(isAuthenticated: true, username: username, tenantSlug: tenantSlug);
      return true;
    }
    return false;
  }

  void logout() {
    state = AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
